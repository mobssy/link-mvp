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

    func summarize(messages: [Message], limit: Int = 30, targetLanguage: String = "en") async -> String {
        let last = Array(messages.suffix(limit))
        let labels = summaryLabels(for: targetLanguage)
        guard !last.isEmpty else { return labels.noMessages }

        let textMessages = last.filter { $0.messageType == .text }
        let participants = Set(last.map { $0.isFromCurrentUser ? labels.me : $0.sender })
        let participantList = participants.sorted().joined(separator: ", ")
        let fromMe = last.filter { $0.isFromCurrentUser }.count
        let fromOther = last.count - fromMe
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        let transcriptLines = textMessages.map { "\($0.isFromCurrentUser ? labels.me : $0.sender): \($0.text)" }
        let transcript = transcriptLines.joined(separator: "\n")

        #if canImport(FoundationModels)
        if #available(iOS 18.0, *) {
            if let aiResult = await generateAISummary(
                transcript: transcript, labels: labels, language: targetLanguage,
                participants: participantList, messageCount: last.count, dateStr: dateStr
            ) { return aiResult }
        }
        #endif

        return generateFallbackSummary(
            messages: last, textMessages: textMessages, labels: labels,
            participantList: participantList, fromMe: fromMe, fromOther: fromOther, dateStr: dateStr
        )
    }

    #if canImport(FoundationModels)
    @available(iOS 18.0, *)
    private func generateAISummary(
        transcript: String, labels: SummaryLabels, language: String,
        participants: String, messageCount: Int, dateStr: String
    ) async -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, !transcript.isEmpty else { return nil }

        let langName = languageName(for: language)
        let instructions = """
        You are an expert conversation analyst. Summarize chat conversations clearly and insightfully.
        Always respond in \(langName).
        Structure your response exactly like this (use the exact section headers provided):

        [Write 2–3 sentences summarizing the overall conversation]

        **\(labels.keyTopics)**
        • [key topic 1]
        • [key topic 2]
        • [key topic 3]

        **\(labels.decisions)**
        • [any decisions or action items — omit this section entirely if none]
        """

        let prompt = "Summarize this chat (\(messageCount) messages, participants: \(participants)):\n\n\(transcript)"

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return nil }
            return "✨ **\(labels.header)**\n\(dateStr)\n\n\(content)"
        } catch {
            print("⚠️ [AIService] Summary generation failed: \(error)")
            return nil
        }
    }
    #endif

    private func generateFallbackSummary(
        messages: [Message], textMessages: [Message], labels: SummaryLabels,
        participantList: String, fromMe: Int, fromOther: Int, dateStr: String
    ) -> String {
        var parts: [String] = []

        parts.append("📊 **\(labels.header)**")
        parts.append(dateStr)
        parts.append("")

        parts.append("**\(labels.statsHeader)**")
        parts.append("• \(labels.participants): \(participantList)")
        parts.append("• \(labels.totalMessages): \(messages.count) (\(labels.me): \(fromMe), \(labels.other): \(fromOther))")

        let imageCount = messages.filter { $0.messageType == .image }.count
        let fileCount  = messages.filter { $0.messageType == .file }.count
        let audioCount = messages.filter { $0.messageType == .audio }.count
        if imageCount > 0 { parts.append("• 🖼️ \(labels.image): \(imageCount)") }
        if fileCount  > 0 { parts.append("• 📄 \(labels.file): \(fileCount)") }
        if audioCount > 0 { parts.append("• 🎤 \(labels.audio): \(audioCount)") }

        let keywords = extractKeywords(from: textMessages.map { $0.text }.joined(separator: " "), limit: 6)
        if !keywords.isEmpty {
            parts.append("")
            parts.append("**\(labels.keywordsHeader)**")
            parts.append(keywords.map { "• \($0)" }.joined(separator: "\n"))
        }

        let recent = textMessages.suffix(3)
        if !recent.isEmpty {
            parts.append("")
            parts.append("**\(labels.recentHeader)**")
            for msg in recent {
                let sender = msg.isFromCurrentUser ? labels.me : msg.sender
                let preview = msg.text.count > 60 ? String(msg.text.prefix(60)) + "…" : msg.text
                parts.append("• [\(sender)] \(preview)")
            }
        }

        return parts.joined(separator: "\n")
    }

    private func extractKeywords(from text: String, limit: Int) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var wordFreq: [String: Int] = [:]
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            guard let tag, tag == .noun || tag == .verb || tag == .adjective else { return true }
            let word = String(text[range])
            if word.count > 1 { wordFreq[word, default: 0] += 1 }
            return true
        }

        return wordFreq.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    private struct SummaryLabels {
        let me, image, file, audio, deleted, video, header: String
        let noMessages, statsHeader, participants, totalMessages: String
        let other, keywordsHeader, recentHeader, keyTopics, decisions: String
    }

    private func summaryLabels(for language: String) -> SummaryLabels {
        switch language.lowercased() {
        case "ko":
            return SummaryLabels(
                me: "나", image: "이미지", file: "파일", audio: "음성 메시지", deleted: "삭제된 메시지", video: "동영상",
                header: "대화 요약", noMessages: "요약할 메시지가 없습니다.",
                statsHeader: "대화 통계", participants: "참여자", totalMessages: "총 메시지",
                other: "상대방", keywordsHeader: "주요 키워드", recentHeader: "최근 대화",
                keyTopics: "주요 내용", decisions: "결정 사항"
            )
        case "ja":
            return SummaryLabels(
                me: "自分", image: "画像", file: "ファイル", audio: "音声メッセージ", deleted: "削除済み", video: "動画",
                header: "会話まとめ", noMessages: "要約するメッセージがありません。",
                statsHeader: "会話統計", participants: "参加者", totalMessages: "合計メッセージ",
                other: "相手", keywordsHeader: "キーワード", recentHeader: "最近の会話",
                keyTopics: "主なトピック", decisions: "決定事項"
            )
        case "zh-hans":
            return SummaryLabels(
                me: "我", image: "图片", file: "文件", audio: "语音消息", deleted: "已删除", video: "视频",
                header: "对话摘要", noMessages: "没有可摘要的消息。",
                statsHeader: "对话统计", participants: "参与者", totalMessages: "消息总数",
                other: "对方", keywordsHeader: "关键词", recentHeader: "最近对话",
                keyTopics: "主要话题", decisions: "决定事项"
            )
        case "es":
            return SummaryLabels(
                me: "Yo", image: "Imagen", file: "Archivo", audio: "Mensaje de voz", deleted: "Eliminado", video: "Video",
                header: "Resumen de conversación", noMessages: "No hay mensajes para resumir.",
                statsHeader: "Estadísticas", participants: "Participantes", totalMessages: "Total de mensajes",
                other: "Otro", keywordsHeader: "Palabras clave", recentHeader: "Mensajes recientes",
                keyTopics: "Temas principales", decisions: "Decisiones"
            )
        default:
            return SummaryLabels(
                me: "Me", image: "Image", file: "File", audio: "Voice message", deleted: "Deleted", video: "Video",
                header: "Conversation Summary", noMessages: "No messages to summarize.",
                statsHeader: "Statistics", participants: "Participants", totalMessages: "Total messages",
                other: "Other", keywordsHeader: "Keywords", recentHeader: "Recent messages",
                keyTopics: "Key Topics", decisions: "Decisions"
            )
        }
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
        case "auto":
            // "auto" should be resolved to the app language before reaching here;
            // fall back to English only as a last resort
            if let lang = UserDefaults.standard.string(forKey: "selectedLanguage") {
                return normalizeLanguageCode(lang)
            }
            return "en"
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
