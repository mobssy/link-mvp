//
//  MessageSearch.swift
//  TalkMVP
//
//  Finding messages by what they say, and by what they mean
//

import Foundation
import FoundationModels
import NaturalLanguage
import os

nonisolated private let searchLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "MessageSearch")

/// Finds messages by their words: a message's text, a voice message's transcript, a photo's
/// description, a file's name.
enum MessageSearch {
    /// What a message can be found by, or nil for one with no words.
    static func searchableText(of message: Message) -> String? {
        switch message.messageType {
        case .text, .file: message.text
        case .audio: message.transcript
        case .image: message.imageDescription
        case .video, .location, .deleted: nil
        }
    }

    /// The messages that contain the query itself or any of the related terms, ignoring case,
    /// accents and character width. A blank query finds everything.
    static func filter(_ messages: [Message], query: String, relatedTerms: [String] = []) -> [Message] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return messages }
        let terms = ([query] + relatedTerms)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return messages.filter { message in
            guard let text = searchableText(of: message) else { return false }
            return terms.contains { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil }
        }
    }
}

/// Widens a search to the other ways a chat might say the same thing.
nonisolated protocol SearchQueryExpanding: Sendable {
    /// - Parameters:
    ///   - query: What was searched for.
    ///   - conversation: The chat being searched, for the languages it is written in.
    /// - Returns: Related words and phrases, not including the query; empty when there are none.
    func relatedTerms(for query: String, in conversation: [SummaryMessage]) async -> [String]
}

/// The shape the on-device model fills in (guided generation). Translations get a list of their
/// own: asked for synonyms and translations together, the model gave synonyms in the search's
/// language only, so "저녁 약속" never reached "dinner".
@Generable
nonisolated struct SearchTermsDraft {
    @Guide(description: "Each word of the search translated into the other languages named in the instructions. One word per entry. Empty if no other language is named.", .maximumCount(6))
    var translations: [String]
    // Single words, because terms are matched as written: asked for phrases, the model built ever
    // longer ones around the search ("deadline extension", "dinner tonight cost") that no
    // message contains.
    @Guide(description: "Single words a chat message about the same thing might use instead: synonyms and closely related words. One word per entry, never a phrase.", .maximumCount(6))
    var related: [String]
}

/// Related terms from the on-device model, in the search's own language and the languages the
/// chat is written in, so "저녁 약속" can find "dinner tonight". Without Apple Intelligence
/// there are none, and search matches the words as typed.
nonisolated struct OnDeviceSearchExpander: SearchQueryExpanding {
    func relatedTerms(for query: String, in conversation: [SummaryMessage]) async -> [String] {
        guard case .available = SystemLanguageModel.default.availability else { return [] }
        let languages = Self.languageNames(for: query, in: conversation)
        let translationRule = languages.others.map { "translate each word of the search into \($0)" }
            ?? "leave the translations empty"
        let instructions = """
        You help someone search their chat history, which is written in \(languages.all). For what they \
        searched for, \(translationRule), and list single words a message about the same thing might use \
        instead. Leave out words so common they would match almost any message.
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let draft = try await session.respond(
                to: "Search: \(query)",
                generating: SearchTermsDraft.self,
                options: GenerationOptions(samplingMode: .greedy)
            ).content
            return Self.cleaned(Self.words(of: draft.translations) + draft.related, excluding: query)
        } catch {
            searchLogger.notice("Search expansion failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Every language to look for words in, the search's own first ("Korean and English"), and
    /// those other than the search's, which it needs translating into; nil when there are none.
    static func languageNames(for query: String, in conversation: [SummaryMessage]) -> (all: String, others: String?) {
        let searchLanguage = ConversationLanguage.confidentLanguage(of: query)
        let others = ConversationLanguage.all(in: conversation).filter { $0 != searchLanguage }
        let all = [searchLanguage].compactMap { $0 } + others
        return (names(of: all) ?? "the language of the search", names(of: others))
    }

    private static func names(of languages: [NLLanguage]) -> String? {
        let names = languages.compactMap { Locale(identifier: "en").localizedString(forLanguageCode: $0.rawValue) }
        switch names.count {
        case 0: return nil
        case 1: return names[0]
        default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
    }

    /// The words of each translation. Asked to translate each word, the model still translates
    /// the search whole ("dinner appointment"), which no message contains as written, while the
    /// word "dinner" alone finds "Want to grab dinner tonight?".
    static func words(of translations: [String]) -> [String] {
        translations.flatMap { $0.split(whereSeparator: \.isWhitespace).map(String.init) }
    }

    /// Distinct terms other than the query, without Latin fragments shorter than three letters
    /// ("a", "of"), which would match nearly every message.
    static func cleaned(_ terms: [String], excluding query: String) -> [String] {
        var seen: Set<String> = [query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
        return terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”"))) }
            .filter { term in
                guard !term.isEmpty, !(term.count < 3 && term.allSatisfy(\.isASCII)) else { return false }
                return seen.insert(term.lowercased()).inserted
            }
    }
}
