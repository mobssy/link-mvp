//
//  ChatIntents.swift
//  TalkMVP
//
//  Siri and Shortcuts: send a message to a chat, summarize a chat
//

import AppIntents
import Foundation
import SwiftData

/// A chat, as Siri and Shortcuts refer to it.
struct ChatRoomEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Chat"
    static let defaultQuery = ChatRoomQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

extension ChatRoomEntity {
    init(_ room: ChatRoom) {
        self.init(id: room.id, name: room.name)
    }
}

/// Finds chats for Siri ("send a message to Mina") and for picking one in Shortcuts. While App
/// Lock is on or nobody is signed in, it finds none, so chat names stay out of sight too.
struct ChatRoomQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ChatRoomEntity] {
        let actions = ChatIntentActions(context: container.mainContext)
        guard (try? actions.checkAccess()) != nil else { return [] }
        return try actions.rooms().filter { identifiers.contains($0.id) }.map(ChatRoomEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ChatRoomEntity] {
        let actions = ChatIntentActions(context: container.mainContext)
        guard (try? actions.checkAccess()) != nil else { return [] }
        return try actions.rooms(matching: string).map(ChatRoomEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ChatRoomEntity] {
        let actions = ChatIntentActions(context: container.mainContext)
        guard (try? actions.checkAccess()) != nil else { return [] }
        return try actions.rooms().map(ChatRoomEntity.init)
    }
}

struct SendChatMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "Send Message"
    static let description = IntentDescription("Sends a message to one of your chats.")
    /// Sending as the user needs the phone unlocked, like opening the chat would.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Chat", requestValueDialog: "Which chat?")
    var chat: ChatRoomEntity

    @Parameter(title: "Message", requestValueDialog: "What should I send?")
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$message) to \(\.$chat)")
    }

    @Dependency private var container: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ChatIntentActions(context: container.mainContext).send(message, to: chat.id)
        return .result(dialog: "Sent to \(chat.name).")
    }
}

struct SummarizeChatIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize Chat"
    static let description = IntentDescription("Summarizes a chat on device with Apple Intelligence.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Chat", requestValueDialog: "Which chat?")
    var chat: ChatRoomEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Summarize \(\.$chat)")
    }

    @Dependency private var container: ModelContainer

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let summary = try await ChatIntentActions(context: container.mainContext)
            .summary(of: chat.id, language: ChatIntentActions.summaryLanguage())
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

/// The phrases Siri knows these actions by, without any setup in Shortcuts.
struct ChatShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendChatMessageIntent(),
            phrases: [
                "Send a message with \(.applicationName)",
                "Send a message to \(\.$chat) with \(.applicationName)",
            ],
            shortTitle: "Send Message",
            systemImageName: "paperplane"
        )
        AppShortcut(
            intent: SummarizeChatIntent(),
            phrases: [
                "Summarize a chat in \(.applicationName)",
                "Summarize \(\.$chat) in \(.applicationName)",
            ],
            shortTitle: "Summarize Chat",
            systemImageName: "text.quote"
        )
    }
}
