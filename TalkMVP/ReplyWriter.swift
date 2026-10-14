//
//  ReplyWriter.swift
//  TalkMVP
//
//  Writes what the simulated other side of a chat says next
//

import Foundation
import FoundationModels
import NaturalLanguage
import os

nonisolated private let replyLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ReplyWriter")

/// Writes the next message from the other side of a chat.
nonisolated protocol ReplyWriting: Sendable {
    /// - Parameters:
    ///   - conversation: The chat so far, oldest first.
    ///   - partner: The name of the chat, which is who is replying.
    /// - Returns: The reply, or nil when this writer can't write one.
    func reply(to conversation: [SummaryMessage], as partner: String) async -> String?
}

extension SummaryMessage {
    /// The message as a model should read it in a transcript. Attachments carry only an emoji
    /// ("📷") as text, so they are spelled out instead.
    nonisolated var transcriptText: String {
        switch messageType {
        case .text: text
        case .image: imageDescription.map { "[sent a photo: \($0)]" } ?? "[sent a photo]"
        case .video: "[sent a video]"
        case .audio: transcript.map { "[voice message] \($0)" } ?? "[sent a voice message]"
        case .file: "[sent a file]"
        case .location: "[shared a location]"
        case .deleted: "[deleted message]"
        }
    }
}

/// The language the user is writing in. Short messages are the catch: on its own, "ok" reads
/// as Polish, and a model told to write in "the user's language" then answered in Spanish.
nonisolated enum ConversationLanguage {
    /// The languages the app speaks or translates; nothing else is considered.
    static let candidates: [NLLanguage] = [.korean, .english, .japanese, .simplifiedChinese, .traditionalChinese, .spanish, .french, .german]
    static let minimumConfidence = 0.8

    /// The language of the user's newest text message or, when that is too short to tell, of
    /// their recent messages together, and failing that of the chat as a whole: someone who
    /// hasn't written yet usually answers in the language they were written to. Nil when none
    /// of these can be told with confidence.
    static func of(_ conversation: [SummaryMessage]) -> NLLanguage? {
        let texts = conversation.compactMap(\.asText)
        let own = texts.filter(\.isFromCurrentUser).map(\.text)
        return own.last.flatMap(confidentLanguage(of:))
            ?? confidentLanguage(of: own.suffix(5).joined(separator: "\n"))
            ?? confidentLanguage(of: texts.suffix(5).map(\.text).joined(separator: "\n"))
    }

    /// The chat's language code, such as "ko", or `fallbackCode` when it can't be told.
    static func code(for conversation: [SummaryMessage], fallbackCode: String) -> String {
        of(conversation)?.rawValue ?? fallbackCode
    }

    /// The English name of the language to write in, for a model's instructions: the chat's
    /// language, or the one `fallbackCode` names when that can't be told.
    static func name(for conversation: [SummaryMessage], fallbackCode: String) -> String {
        Locale(identifier: "en").localizedString(forLanguageCode: code(for: conversation, fallbackCode: fallbackCode)) ?? "English"
    }

    private static func confidentLanguage(of text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = candidates
        recognizer.processString(text)
        guard let best = recognizer.languageHypotheses(withMaximum: 1).max(by: { $0.value < $1.value }),
              best.value >= minimumConfidence else { return nil }
        return best.key
    }
}

/// Replies written by the on-device model, in character and in the user's language, so the
/// other side answers what was actually said.
nonisolated struct OnDeviceReplyWriter: ReplyWriting {
    /// How much of the chat the model sees; enough to stay on topic and well within its context.
    var historyLimit = 12
    /// The language to answer in when the chat's can't be told, e.g. the app's language code.
    var fallbackLanguage: String = LanguageManager.currentLanguageCode

    func reply(to conversation: [SummaryMessage], as partner: String) async -> String? {
        // A message that has disappeared is only a placeholder now.
        let recent = conversation.filter { $0.messageType != .deleted }.suffix(historyLimit)
        guard case .available = SystemLanguageModel.default.availability, recent.contains(where: \.isFromCurrentUser) else { return nil }

        let language = ConversationLanguage.name(for: conversation, fallbackCode: fallbackLanguage)
        let instructions = """
        You are the other side of a chat called "\(partner)" in a messaging app: the person the user is \
        talking to, or one of the members if it is a group. Write your next message to the user in \(language): \
        one or two short, casual sentences that answer their last message directly. Write only the message.
        """
        let transcript = recent
            .map { "\($0.isFromCurrentUser ? "Friend" : "You"): \($0.transcriptText)" }
            .joined(separator: "\n")
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: "The chat so far:\n\(transcript)\n\nWrite your reply to the friend.",
                options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 120)
            )
            return Self.cleaned(response.content, partner: partner)
        } catch {
            replyLogger.notice("Reply generation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The reply without the speaker label or quotation marks the model sometimes wraps it in.
    static func cleaned(_ text: String, partner: String) -> String? {
        var reply = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for label in ["You:", "\(partner):"] where reply.hasPrefix(label) {
            reply = String(reply.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
        }
        let quotes: [(open: Character, close: Character)] = [("\"", "\""), ("“", "”"), ("「", "」")]
        if reply.count > 1, let pair = quotes.first(where: { reply.first == $0.open && reply.last == $0.close }) {
            let inner = reply.dropFirst().dropLast()
            if !inner.contains(pair.open) { reply = String(inner) }
        }
        return reply.isEmpty ? nil : reply
    }
}

/// Stock replies, for when the on-device model is unavailable. Picked in the language the user
/// is writing in, so an English chat doesn't get a Korean answer.
nonisolated struct CannedReplyWriter: ReplyWriting {
    /// Used when the chat's language can't be told, e.g. the app's language code.
    var fallbackLanguage: String = LanguageManager.currentLanguageCode

    static let replies: [String: [String]] = [
        "ko": ["네 알겠습니다! 👍", "좋은 생각이네요 😊", "그렇네요!", "재미있겠어요 😄", "네네 맞습니다",
               "정말요? 대박이네요! 🎉", "언제 시간 되실 때 연락주세요", "오늘도 좋은 하루 되세요!"],
        "en": ["Sounds good! 👍", "Good idea 😊", "Oh, nice!", "That sounds fun 😄", "Yep, exactly",
               "Really? That's great! 🎉", "Let me know when you're free", "Have a great day!"],
        "ja": ["了解です！👍", "いいですね 😊", "そうなんですね！", "楽しそう 😄", "その通りです",
               "本当に？すごい！🎉", "時間があるときに連絡ください", "良い一日を！"],
        "zh": ["好的！👍", "好主意 😊", "原来如此！", "听起来很有趣 😄", "没错",
               "真的吗？太棒了！🎉", "有空的时候联系我", "祝你今天愉快！"],
        "es": ["¡Perfecto! 👍", "Buena idea 😊", "¡Qué bien!", "Suena divertido 😄", "Sí, exacto",
               "¿En serio? ¡Genial! 🎉", "Avísame cuando tengas tiempo", "¡Que tengas un buen día!"],
    ]

    func reply(to conversation: [SummaryMessage], as partner: String) async -> String? {
        let code = ConversationLanguage.of(conversation).map { String($0.rawValue.prefix(2)) } ?? String(fallbackLanguage.prefix(2))
        return (Self.replies[code] ?? Self.replies["en"])?.randomElement()
    }
}
