//
//  VoiceMessageService.swift
//  TalkMVP
//

import AVFoundation
import Combine
import Foundation
import os

nonisolated private let voiceLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "VoiceMessage")

/// What the shared audio session is switched on for.
nonisolated enum AudioSessionUse: Sendable {
    case recording, playback
}

/// Switches the app's audio session on and off.
nonisolated protocol AudioSessionSwitching: Sendable {
    func activate(for use: AudioSessionUse) async throws
    func deactivate() async
}

/// The shared AVAudioSession, switched away from the main thread. Activating it can block for a
/// long time, and Xcode flags doing it on the main thread: when a recording started, the chat
/// froze until it returned (for over a minute in the simulator).
nonisolated struct SharedAudioSession: AudioSessionSwitching {
    @concurrent
    func activate(for use: AudioSessionUse) async throws {
        let session = AVAudioSession.sharedInstance()
        switch use {
        case .recording:
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        case .playback:
            try session.setCategory(.playback, mode: .default)
        }
        try session.setActive(true)
    }

    /// Lets other apps' audio, paused for a recording, play again.
    @concurrent
    func deactivate() async {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor
@Observable
final class VoiceMessageService: NSObject, AVAudioRecorderDelegate {
    var isRecording = false
    var recordingDuration: TimeInterval = 0

    private let audioSession: any AudioSessionSwitching
    private let requestPermission: @Sendable () async -> Bool
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var tempURL: URL?
    /// A start still waiting for permission or the audio session, and whether it was called off.
    private var isStarting = false
    private var startCancelled = false

    init(
        audioSession: any AudioSessionSwitching = SharedAudioSession(),
        requestPermission: @escaping @Sendable () async -> Bool = { await AVAudioApplication.requestRecordPermission() }
    ) {
        self.audioSession = audioSession
        self.requestPermission = requestPermission
        super.init()
    }

    /// Records once the microphone is allowed and the audio session is on. The session is
    /// switched on away from the main thread, so the chat keeps responding meanwhile; a second
    /// call while one is starting does nothing, and a stop or cancel before the recorder runs
    /// calls the start off.
    func startRecording() async -> Bool {
        guard !isRecording, !isStarting else { return false }
        isStarting = true
        startCancelled = false
        defer { isStarting = false }

        guard await requestPermission(), !startCancelled else { return false }
        do {
            try await audioSession.activate(for: .recording)
        } catch {
            voiceLogger.error("Couldn't switch the audio session on for recording: \(error.localizedDescription, privacy: .public)")
            return false
        }
        guard !startCancelled else {
            await audioSession.deactivate()
            return false
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        guard let r = await Self.startedRecorder(writingTo: url) else {
            await audioSession.deactivate()
            return false
        }
        guard !startCancelled else {
            r.stop()
            try? FileManager.default.removeItem(at: url)
            await audioSession.deactivate()
            return false
        }
        tempURL = url
        recorder = r
        r.delegate = self
        isRecording = true
        recordingDuration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordingDuration += 0.1
            }
        }
        return true
    }

    /// A recorder already recording into `url`. Creating and starting it touch the audio session
    /// too, so they also happen away from the main thread.
    @concurrent
    private nonisolated static func startedRecorder(writingTo url: URL) async -> sending AVAudioRecorder? {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings), recorder.record() else {
            voiceLogger.error("Couldn't start the recorder")
            return nil
        }
        return recorder
    }

    func stopRecording() -> (Data, Double)? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        switchSessionOff()

        let duration = recordingDuration
        recordingDuration = 0

        guard let url = tempURL, let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        tempURL = nil
        return (data, duration)
    }

    /// Throws the recording away, or calls off one that is still starting.
    func cancelRecording() {
        if isStarting { startCancelled = true }
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
            tempURL = nil
        }
        isRecording = false
        recordingDuration = 0
        switchSessionOff()
    }

    private func switchSessionOff() {
        let session = audioSession
        Task { await session.deactivate() }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {}
}
