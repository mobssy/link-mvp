//
//  ConversationLanguage.swift
//  TalkMVP
//
//  Which language a chat is written in
//

import Foundation
import NaturalLanguage

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

    /// The languages the chat is written in, most used first, at most `limit` of them. Messages
    /// too short to tell are left out rather than guessed at.
    static func all(in conversation: [SummaryMessage], limit: Int = 3) -> [NLLanguage] {
        var counts: [NLLanguage: Int] = [:]
        for message in conversation.compactMap(\.asText).suffix(100) {
            if let language = confidentLanguage(of: message.text) { counts[language, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value || ($0.value == $1.value && $0.key.rawValue < $1.key.rawValue) }
            .prefix(limit)
            .map(\.key)
    }

    static func confidentLanguage(of text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = candidates
        recognizer.processString(text)
        guard let best = recognizer.languageHypotheses(withMaximum: 1).max(by: { $0.value < $1.value }),
              best.value >= minimumConfidence else { return nil }
        return best.key
    }
}
