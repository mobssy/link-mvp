//  AIService.swift
//  TalkMVP
//
//  Lightweight mock AI service for summarization and translation.

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

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
            case .deleted:
                return "- [\(sender)] 메시지가 삭제되었습니다"
            }
        }
        let header = "최근 대화 요약 (\(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))):\n\n"
        return header + lines.joined(separator: "\n")
    }

    // Very lightweight mock translation: prepend a label and simulate delay
    func translate(_ text: String, autoDetect: Bool, target: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let targetCode = target.lowercased()
        let targetName = languageName(for: targetCode)

        // Prefer on-device Apple Intelligence when available (iOS 18+ and supported devices)
        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                do {
                    let instructions = """
                    You are a professional translation engine.
                    - Translate any input to \(targetName).
                    - Return only the translated text with no quotes or extra commentary.
                    - Preserve emojis and basic punctuation.
                    - Keep the tone natural and concise.
                    """
                    let session = LanguageModelSession(instructions: instructions)
                    let prompt: String
                    if autoDetect {
                        prompt = """
                        Translate the following text to \(targetName). Detect the source language automatically. Return only the translation.\n\n\(trimmed)
                        """
                    } else {
                        prompt = """
                        Translate to \(targetName). Return only the translation.\n\n\(trimmed)
                        """
                    }

                    let response = try await session.respond(to: prompt)
                    let output = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !output.isEmpty { return output }
                } catch {
                    // Fall through to fallback
                }
            default:
                break
            }
        }
        #endif

        // Fallback: lightweight label with original text (ensures UI still shows something)
        return "[→ \(targetName)] \(text)"
    }

    private func languageName(for code: String) -> String {
        switch code {
        case "en": return "English"
        case "ko": return "Korean"
        case "ja": return "Japanese"
        case "zh-hans", "zh_cn", "zh": return "Chinese (Simplified)"
        case "zh-hant", "zh_tw": return "Chinese (Traditional)"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "auto": return "English" // default target if auto
        default: return code.uppercased()
        }
    }
}
