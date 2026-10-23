//
//  ChatViewContainer.swift
//  TalkMVP
//

import SwiftUI
import SwiftData

/// Opens the one-to-one conversation with a friend: the same saved room every time, so it
/// shows up in the chat list and keeps its history.
struct ChatViewContainer: View {
    let friendship: Friendship
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(LanguageManager.self) private var languageManager
    @State private var room: ChatRoom?
    @State private var failedToOpen = false

    var body: some View {
        NavigationStack {
            if let room {
                ChatScreen(room: room)
            } else if failedToOpen {
                ContentUnavailableView(
                    languageManager.localize(ko: "채팅을 열 수 없습니다", en: "Couldn't open the chat", ja: "チャットを開けません", zh: "无法打开聊天", es: "No se pudo abrir el chat"),
                    systemImage: "exclamationmark.bubble"
                )
            } else {
                ProgressView()
            }
        }
        .task { await openRoom() }
    }

    private func openRoom() async {
        guard room == nil, let currentUserId = authManager.currentUser?.id.uuidString else {
            failedToOpen = room == nil
            return
        }
        let repository: ChatRoomRepositoryProtocol = LocalChatRoomRepository(modelContext: modelContext)
        do {
            room = try await repository.directChatRoom(
                withUserId: friendship.otherUserId(currentUserId: currentUserId),
                name: friendship.friendName,
                email: friendship.friendEmail
            )
        } catch {
            failedToOpen = true
        }
    }
}
