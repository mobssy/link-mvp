//  AIService.swift
//  TalkMVP
//
//  Lightweight mock AI service for summarization and translation.

import Foundation

actor AIService {
    static let shared = AIService()

    // Very lightweight mock summarization: join last N messages and trim
    func summarize(messages: [Message], limit: Int = 30) async -> String {
        let last = Array(messages.suffix(limit))
        let lines = last.map { msg in
            let sender = msg.isFromCurrentUser ? "나" : (msg.sender)
            switch msg.messageType {
            case .text:
                return "- [\(sender)] \(msg.text)"
            case .image:
                return "- [\(sender)] 이미지 전송"
            case .file:
                return "- [\(sender)] 파일: \(msg.text)"
            case .audio:
                return "- [\(sender)] 음성 메시지"
            }
        }
        let header = "최근 대화 요약 (\(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))):\n\n"
        return header + lines.joined(separator: "\n")
    }

    // Very lightweight mock translation: prepend a label and simulate delay
    func translate(_ text: String, autoDetect: Bool, target: String) async -> String {
        // Simulate network/processing latency
        try? await Task.sleep(nanoseconds: 250_000_000)
        let targetName: String
        switch target.lowercased() {
        case "auto": targetName = "자동"
        case "en": targetName = "영어"
        case "ja": targetName = "일본어"
        case "ko": targetName = "한국어"
        case "zh-hans": targetName = "중국어(간체)"
        case "zh-hant": targetName = "중국어(번체)"
        case "es": targetName = "스페인어"
        case "fr": targetName = "프랑스어"
        case "de": targetName = "독일어"
        default: targetName = target.uppercased()
        }
        let detected = autoDetect ? "(감지됨) " : ""
        return "[\(detected)→ \(targetName)] \(text)"
    }
}
