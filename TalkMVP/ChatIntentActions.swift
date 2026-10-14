//
//  ChatIntentActions.swift
//  TalkMVP
//
//  What the Siri and Shortcuts actions do, apart from the App Intents plumbing
//

import Foundation
import SwiftData

/// Why a Siri or Shortcuts action couldn't run.
enum ChatIntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case signedOut
    case appLocked
    case chatNotFound
    case emptyMessage

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .signedOut: "Sign in to the app first."
        case .appLocked: "App Lock is on. Open the app to unlock it first."
        case .chatNotFound: "That chat isn't in the app anymore."
        case .emptyMessage: "There's nothing to send."
        }
    }
}

/// The work behind each action, on the app's own store, kept apart from the App Intents types so
/// it can be tested without Siri.
@MainActor
struct ChatIntentActions {
    let context: ModelContext
    /// Whether App Lock is on; read from the setting AppLockManager stores.
    var isAppLocked: () -> Bool = { UserDefaults.standard.bool(forKey: "appLockEnabled") }
    var summarize: (_ messages: [SummaryMessage], _ language: String) async -> String = { messages, language in
        await AIService.shared.summarize(messages: messages, targetLanguage: language)
    }

    /// Siri can reach the app without opening it, so an action checks what the app's own screens
    /// would: that someone is signed in, and that App Lock isn't keeping the chats out of sight.
    func checkAccess() throws {
        guard !isAppLocked() else { throw ChatIntentError.appLocked }
        let signedIn = try context.fetchCount(FetchDescriptor<User>(predicate: #Predicate { $0.isCurrentUser == true })) > 0
        guard signedIn else { throw ChatIntentError.signedOut }
    }

    /// Chats, most recent first; with a name, only those whose name contains it.
    func rooms(matching name: String? = nil) throws -> [ChatRoom] {
        let rooms = try context.fetch(FetchDescriptor<ChatRoom>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)]))
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return rooms }
        return rooms.filter { $0.name.localizedStandardContains(name) }
    }

    func room(id: UUID) throws -> ChatRoom {
        guard let room = try context.fetch(FetchDescriptor<ChatRoom>(predicate: #Predicate { $0.id == id })).first else {
            throw ChatIntentError.chatNotFound
        }
        return room
    }

    /// Sends `text` to the chat as the signed-in user, with the chat's options, the way the chat
    /// screen does, and puts it in the chat list preview.
    @discardableResult
    func send(_ text: String, to roomID: UUID) async throws -> Message {
        try checkAccess()
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ChatIntentError.emptyMessage }
        let room = try room(id: roomID)
        let message = Message(text: text, isFromCurrentUser: true, chatRoomId: room.id.uuidString)
        if room.disappearingDuration > 0 {
            message.isDisappearing = true
            message.disappearAfterSeconds = room.disappearingDuration
        }
        try await LocalMessageRepository(modelContext: context).saveMessage(message)
        try await LocalChatRoomRepository(modelContext: context).updateChatRoom(room, lastMessage: text, timestamp: Date())
        return message
    }

    /// The chat summarized in `language`, as plain text for Siri to say or show.
    func summary(of roomID: UUID, language: String) async throws -> String {
        try checkAccess()
        let room = try room(id: roomID)
        let messages = try await LocalMessageRepository(modelContext: context)
            .fetchMessages(for: room.id.uuidString, limit: AIService.summaryMessageLimit, before: nil)
        return Self.plainText(await summarize(messages.map(SummaryMessage.init), language))
    }

    /// The summary without the app's heading paragraph (title and date) and the Markdown markers,
    /// which Siri would otherwise show as they are.
    static func plainText(_ summary: String) -> String {
        var paragraphs = summary.components(separatedBy: "\n\n")
        if paragraphs.count > 1 { paragraphs.removeFirst() }
        return paragraphs.joined(separator: "\n\n")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The language Siri is speaking, among those summaries are written in.
    static func summaryLanguage(for preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        let preferred = preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh-Hant") { return "zh-Hant" }
        if preferred.hasPrefix("zh") { return "zh-Hans" }
        return ["ko", "ja", "es"].first { preferred.hasPrefix($0) } ?? "en"
    }
}
