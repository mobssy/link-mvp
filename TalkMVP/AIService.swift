//  AIService.swift
//  TalkMVP
//
//  Lightweight mock AI service for summarization and translation.

import Foundation
import NaturalLanguage
import Translation

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
            case .video:
                return "- [\(sender)] 동영상을 보냈습니다"
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

        // Fallback: Use Apple's Translation framework (iOS 15+)
        if #available(iOS 15.0, *) {
            if let translated = await translateWithNLTranslation(trimmed, targetCode: targetCode) {
                return translated
            }
        }

        // Last resort fallback: lightweight label with original text
        return "[→ \(targetName)] \(trimmed)"
    }
    
    @available(iOS 15.0, *)
    private func translateWithNLTranslation(_ text: String, targetCode: String) async -> String? {
        // Detect source language
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        guard let dominantLanguage = recognizer.dominantLanguage else {
            return nil
        }
        
        let sourceCode = normalizeLanguageCode(dominantLanguage.rawValue)
        let normalizedTarget = normalizeLanguageCode(targetCode)
        
        // If source and target are the same, no translation needed
        if sourceCode == normalizedTarget {
            return text
        }
        
        // Try Apple's Translation framework (iOS 17.4+)
        if #available(iOS 17.4, *) {
            if let appleTranslation = await translateWithAppleFramework(text, from: sourceCode, to: normalizedTarget) {
                return appleTranslation
            }
        }
        
        // Fallback to mock translation
        return performMockTranslation(text, from: sourceCode, to: normalizedTarget)
    }
    
    @available(iOS 17.4, *)
    private func translateWithAppleFramework(_ text: String, from sourceCode: String, to targetCode: String) async -> String? {
        // Convert language codes to Locale.Language
        guard let sourceLanguage = languageCodeToLocaleLanguage(sourceCode),
              let targetLanguage = languageCodeToLocaleLanguage(targetCode) else {
            return nil
        }
        
        do {
            // Create a translation session
            let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
            
            // Translate the text
            let response = try await session.translate(text)
            return response.targetText
        } catch {
            print("⚠️ [AIService] Apple Translation failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    @available(iOS 17.4, *)
    private func languageCodeToLocaleLanguage(_ code: String) -> Locale.Language? {
        switch code {
        case "ko": return Locale.Language(identifier: "ko")
        case "en": return Locale.Language(identifier: "en")
        case "ja": return Locale.Language(identifier: "ja")
        case "zh-hans": return Locale.Language(identifier: "zh-Hans")
        case "zh-hant": return Locale.Language(identifier: "zh-Hant")
        case "es": return Locale.Language(identifier: "es")
        case "fr": return Locale.Language(identifier: "fr")
        case "de": return Locale.Language(identifier: "de")
        default: return nil
        }
    }
    
    private func normalizeLanguageCode(_ code: String) -> String {
        let lowercased = code.lowercased()
        switch lowercased {
        case "zh-hans", "zh_cn", "zh", "cmn": return "zh-hans"
        case "zh-hant", "zh_tw": return "zh-hant"
        case "en", "eng": return "en"
        case "ko", "kor": return "ko"
        case "ja", "jpn": return "ja"
        case "es", "spa": return "es"
        case "fr", "fra": return "fr"
        case "de", "deu": return "de"
        case "auto": return "en" // default
        default: return lowercased
        }
    }
    
    private func performMockTranslation(_ text: String, from source: String, to target: String) -> String {
        // Basic mock translations for common phrases (for demonstration)
        // In a real app, integrate with Google Translate API, DeepL, or similar service
        
        let commonPhrases: [String: [String: String]] = [
            // 한국어 -> 영어
            "안녕하세요!": ["en": "Hello!", "ja": "こんにちは!", "zh-hans": "你好!"],
            "안녕하세요": ["en": "Hello", "ja": "こんにちは", "zh-hans": "你好"],
            "안녕하세요! 어떻게 지내세요?": ["en": "Hello! How are you?", "ja": "こんにちは！お元気ですか？", "zh-hans": "你好！你好吗？"],
            "감사합니다": ["en": "Thank you", "ja": "ありがとうございます", "zh-hans": "谢谢"],
            "좋은 아침입니다": ["en": "Good morning", "ja": "おはようございます", "zh-hans": "早上好"],
            "요즘 바쁘시죠?": ["en": "Are you busy these days?", "ja": "最近忙しいですか？", "zh-hans": "最近忙吗？"],
            "연락 드려요!": ["en": "I'll contact you!", "ja": "連絡します！", "zh-hans": "我会联系你！"],
            "연락 드려요! 😊": ["en": "I'll contact you! 😊", "ja": "連絡します！😊", "zh-hans": "我会联系你！😊"],
            "주말에 뭐 하세요?": ["en": "What are you doing this weekend?", "ja": "週末は何をしますか？", "zh-hans": "周末做什么？"],
            
            // 영어 -> 한국어
            "Hello!": ["ko": "안녕하세요!", "ja": "こんにちは!", "zh-hans": "你好!"],
            "Hello": ["ko": "안녕하세요", "ja": "こんにちは", "zh-hans": "你好"],
            "Hello! How are you?": ["ko": "안녕하세요! 어떻게 지내세요?", "ja": "こんにちは！お元気ですか？", "zh-hans": "你好！你好吗？"],
            "Thank you": ["ko": "감사합니다", "ja": "ありがとうございます", "zh-hans": "谢谢"],
            "Good morning": ["ko": "좋은 아침입니다", "ja": "おはようございます", "zh-hans": "早上好"],
            "Are you busy these days?": ["ko": "요즘 바쁘시죠?", "ja": "最近忙しいですか？", "zh-hans": "最近忙吗？"],
            "I'll contact you!": ["ko": "연락 드려요!", "ja": "連絡します！", "zh-hans": "我会联系你！"],
            "I'll contact you! 😊": ["ko": "연락 드려요! 😊", "ja": "連絡します！😊", "zh-hans": "我会联系你！😊"],
            "What are you doing this weekend?": ["ko": "주말에 뭐 하세요?", "ja": "週末は何をしますか？", "zh-hans": "周末做什么？"],
            
            // 일본어
            "こんにちは": ["en": "Hello", "ko": "안녕하세요", "zh-hans": "你好"],
            "こんにちは！お元気ですか？": ["en": "Hello! How are you?", "ko": "안녕하세요! 어떻게 지내세요?", "zh-hans": "你好！你好吗？"],
            "ありがとうございます": ["en": "Thank you", "ko": "감사합니다", "zh-hans": "谢谢"],
            "連絡します！😊": ["en": "I'll contact you! 😊", "ko": "연락 드려요! 😊", "zh-hans": "我会联系你！😊"],
            
            // 중국어
            "你好": ["en": "Hello", "ko": "안녕하세요", "ja": "こんにちは"],
            "你好！你好吗？": ["en": "Hello! How are you?", "ko": "안녕하세요! 어떻게 지내세요?", "ja": "こんにちは！お元気ですか？"],
            "谢谢": ["en": "Thank you", "ko": "감사합니다", "ja": "ありがとうございます"]
        ]
        
        // Check if we have a direct translation for this phrase
        if let translations = commonPhrases[text], let translated = translations[target] {
            return translated
        }
        
        // Try to find a partial match (for text with minor variations)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for (key, translations) in commonPhrases {
            if trimmedText.contains(key) || key.contains(trimmedText) {
                if let translated = translations[target] {
                    return translated
                }
            }
        }
        
        // For Korean to English: provide basic word-by-word translation hints
        if source == "ko" && target == "en" {
            return translateKoreanToEnglish(text)
        }
        
        // For English to Korean
        if source == "en" && target == "ko" {
            return translateEnglishToKorean(text)
        }
        
        // For other language pairs, provide a translation indicator
        let targetName = languageName(for: target)
        return "[\(targetName)] \(text)"
    }
    
    private func translateKoreanToEnglish(_ text: String) -> String {
        // Basic Korean-to-English word dictionary for common words
        let wordMap: [String: String] = [
            "안녕": "hello",
            "감사": "thank",
            "요즘": "these days",
            "바쁘": "busy",
            "연락": "contact",
            "드려": "give",
            "주말": "weekend",
            "뭐": "what",
            "하세요": "do",
            "어떻게": "how",
            "지내세요": "are you",
            "좋은": "good",
            "아침": "morning"
        ]
        
        var result = text
        for (korean, english) in wordMap {
            if text.contains(korean) {
                result = result.replacingOccurrences(of: korean, with: english)
            }
        }
        
        // If translation was performed, return it; otherwise use generic translation
        if result != text {
            return "[Translation] \(result)"
        }
        
        return "[English] \(text)"
    }
    
    private func translateEnglishToKorean(_ text: String) -> String {
        // Basic English-to-Korean word dictionary
        let wordMap: [String: String] = [
            "hello": "안녕",
            "thank": "감사",
            "you": "당신",
            "busy": "바쁨",
            "contact": "연락",
            "weekend": "주말",
            "what": "무엇",
            "how": "어떻게",
            "good": "좋은",
            "morning": "아침"
        ]
        
        var result = text.lowercased()
        for (english, korean) in wordMap {
            if result.contains(english) {
                result = result.replacingOccurrences(of: english, with: korean)
            }
        }
        
        // If translation was performed, return it; otherwise use generic translation
        if result != text.lowercased() {
            return "[번역] \(result)"
        }
        
        return "[한국어] \(text)"
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
