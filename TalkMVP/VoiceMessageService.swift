//
//  VoiceMessageService.swift
//  TalkMVP
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class VoiceMessageService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var tempURL: URL?

    func startRecording() async -> Bool {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        guard granted else { return false }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        tempURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        guard let r = try? AVAudioRecorder(url: url, settings: settings) else { return false }
        recorder = r
        r.delegate = self
        r.record()
        isRecording = true
        recordingDuration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordingDuration += 0.1
            }
        }
        return true
    }

    func stopRecording() -> (Data, Double)? {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false

        let duration = recordingDuration
        recordingDuration = 0

        guard let url = tempURL, let data = try? Data(contentsOf: url) else { return nil }
        try? FileManager.default.removeItem(at: url)
        tempURL = nil
        return (data, duration)
    }

    func cancelRecording() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
            tempURL = nil
        }
        isRecording = false
        recordingDuration = 0
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {}
}
