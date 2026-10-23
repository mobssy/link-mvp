//
//  VoiceTranscriber.swift
//  TalkMVP
//
//  Writes down what was said in a voice message, on device
//

import AVFoundation
import Foundation
import Speech
import os

nonisolated private let transcriptionLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "VoiceTranscriber")

/// Writes down what was said in a voice message.
nonisolated protocol VoiceTranscribing: Sendable {
    /// - Parameters:
    ///   - audio: The recording as a message stores it (AAC in an .m4a container).
    ///   - languageCode: The language spoken, such as "ko" or "en".
    /// - Returns: The words, or nil when they can't be made out on this device.
    func transcribe(_ audio: Data, languageCode: String) async -> String?
}

nonisolated enum TranscriptionError: Error {
    case unreadableAudio
    case noCompatibleFormat
}

/// Transcription with the Speech framework's on-device analyzer. SpeechTranscriber is the
/// better model but needs recent hardware; DictationTranscriber, the model behind keyboard
/// dictation, covers the rest. Either downloads its language model the first time.
nonisolated struct OnDeviceVoiceTranscriber: VoiceTranscribing {
    func transcribe(_ audio: Data, languageCode: String) async -> String? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let requested = Locale(identifier: languageCode)
        do {
            try audio.write(to: url)
            let file = try AVAudioFile(forReading: url)
            let words: String
            if SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested) {
                words = try await run(SpeechTranscriber(locale: locale, preset: .transcription), on: file) { module in
                    try await module.results.reduce(into: "") { $0 += String($1.text.characters) }
                }
            } else if let locale = await DictationTranscriber.supportedLocale(equivalentTo: requested) {
                words = try await run(DictationTranscriber(locale: locale, preset: .longDictation), on: file) { module in
                    try await module.results.reduce(into: "") { $0 += String($1.text.characters) }
                }
            } else {
                return nil
            }
            let trimmed = words.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            transcriptionLogger.notice("Transcription failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Runs the whole recording through `module` and returns what `collect` reads from its
    /// results. The model and audio format are settled before collecting starts, and a failed
    /// analysis is cancelled, so the results stream always ends.
    private func run<Module: SpeechModule>(
        _ module: Module, on file: AVAudioFile,
        collect: @escaping @Sendable (Module) async throws -> String
    ) async throws -> String {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await request.downloadAndInstall()
        }
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module], considering: file.processingFormat) else {
            throw TranscriptionError.noCompatibleFormat
        }
        let audio = try AudioConversion.read(file, as: format)
        let (inputs, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        continuation.yield(AnalyzerInput(buffer: audio))
        continuation.finish()

        let analyzer = SpeechAnalyzer(modules: [module])
        async let words = collect(module)
        do {
            if let end = try await analyzer.analyzeSequence(inputs) {
                try await analyzer.finalizeAndFinish(through: end)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            throw error
        }
        return try await words
    }
}

/// Reads audio in the format a consumer wants. The analyzer rejects a recording in any other
/// format ("Audio format is not supported") rather than converting it itself.
nonisolated enum AudioConversion {
    /// The whole file as one buffer in `format`; voice messages are short enough to hold at once.
    /// The file is fed through the converter a chunk at a time, because a single read stops at
    /// a 1024-frame boundary and would drop the end of the recording.
    static func read(_ file: AVAudioFile, as format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let ratio = format.sampleRate / file.processingFormat.sampleRate
        guard let converter = AVAudioConverter(from: file.processingFormat, to: format),
              let chunk = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096),
              let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount((Double(file.length) * ratio).rounded(.up)) + 1) else {
            throw TranscriptionError.unreadableAudio
        }
        var readError: Error?
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            guard file.framePosition < file.length else {
                inputStatus.pointee = .endOfStream
                return nil
            }
            do {
                try file.read(into: chunk)
            } catch {
                readError = error
                inputStatus.pointee = .endOfStream
                return nil
            }
            inputStatus.pointee = .haveData
            return chunk
        }
        if let readError { throw readError }
        if status == .error { throw conversionError ?? TranscriptionError.unreadableAudio }
        return output
    }
}
