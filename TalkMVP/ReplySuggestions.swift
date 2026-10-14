//
//  ReplySuggestions.swift
//  TalkMVP
//
//  Short replies the user can pick instead of typing
//

import Foundation
import FoundationModels
import os

nonisolated private let suggestionLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ReplySuggestions")

/// Suggests replies the user could send next.
nonisolated protocol ReplySuggesting: Sendable {
    /// - Parameter conversation: The chat so far, oldest first.
    /// - Returns: Up to three replies, or none when there is nothing to answer.
    func suggestions(for conversation: [SummaryMessage]) async -> [String]
}

/// The shape the on-device model fills in (guided generation), so the suggestions arrive as a
/// list rather than prose to be split up.
@Generable
nonisolated struct ReplySuggestionsDraft {
    @Guide(description: "Three different messages Me could send next, answering Them: for example one that says yes, one that says no or not yet, and one that asks something back. Eight words at most each.", .count(3))
    var replies: [String]
}

/// Suggestions written by the on-device model, in the chat's language, for the other side's
/// latest text message. When Apple Intelligence is unavailable there are no suggestions: stock
/// ones ("OK!") would not be worth the space above the keyboard.
nonisolated struct OnDeviceReplySuggester: ReplySuggesting {
    var historyLimit = 10
    /// The language to suggest in when the chat's can't be told, e.g. the app's language code.
    var fallbackLanguage: String = LanguageManager.currentLanguageCode

    func suggestions(for conversation: [SummaryMessage]) async -> [String] {
        let recent = conversation.filter { $0.messageType != .deleted }.suffix(historyLimit)
        // Only words get suggestions: the model can't see a photo, and guessed at one with
        // "Tell me about the photo".
        guard case .available = SystemLanguageModel.default.availability,
              let last = recent.last, !last.isFromCurrentUser, last.asText != nil else { return [] }

        let language = ConversationLanguage.name(for: conversation, fallbackCode: fallbackLanguage)
        // Small models lose track of whose side they are on ("Congrats! When do you start?" got
        // "Congrats!" suggested back), so the transcript says Me and Them. A sample answer in the
        // instructions fixed that but turned up word for word in unrelated chats, so the rule is
        // spelled out instead.
        let instructions = """
        You suggest what Me could send next in a messaging app. Lines marked "Me:" are mine and lines \
        marked "Them:" are the other person's. Every suggestion is written from my side, as my answer \
        to Them's last message; never write what Them would say, and don't repeat their words back. \
        Write in \(language).
        """
        let transcript = recent
            .map { "\($0.isFromCurrentUser ? "Me" : "Them"): \($0.transcriptText)" }
            .joined(separator: "\n")
        do {
            let session = LanguageModelSession(instructions: instructions)
            let draft = try await session.respond(
                to: "The chat so far:\n\(transcript)\n\nSuggest my next message.",
                generating: ReplySuggestionsDraft.self,
                options: GenerationOptions(temperature: 0.7)
            ).content
            return Self.cleaned(draft.replies)
        } catch {
            suggestionLogger.notice("Reply suggestions failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// At most three distinct, non-empty suggestions, short enough to fit on a chip.
    static func cleaned(_ replies: [String]) -> [String] {
        var seen = Set<String>()
        return replies
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”"))) }
            .filter { !$0.isEmpty && $0.count <= 60 && seen.insert($0.lowercased()).inserted }
            .prefix(3)
            .map { $0 }
    }
}
