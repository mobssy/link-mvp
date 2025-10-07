//
//  ChatRoomRepository.swift
//  TalkMVP
//
//  Repository pattern for ChatRoom data access
//

import Foundation
import SwiftData

/// Protocol defining chat room data operations
protocol ChatRoomRepositoryProtocol {
    /// Fetch all chat rooms
    func fetchChatRooms() async throws -> [ChatRoom]

    /// Fetch a specific chat room by ID
    func fetchChatRoom(by id: UUID) async throws -> ChatRoom?

    /// Save a new chat room
    func saveChatRoom(_ chatRoom: ChatRoom) async throws

    /// Update chat room's last message and timestamp
    func updateChatRoom(_ chatRoom: ChatRoom, lastMessage: String, timestamp: Date) async throws

    /// Update unread count for a chat room
    func updateUnreadCount(for chatRoomId: UUID, count: Int) async throws

    /// Delete a chat room
    func deleteChatRoom(_ chatRoom: ChatRoom) async throws
}

/// SwiftData implementation of ChatRoomRepository
@MainActor
class LocalChatRoomRepository: ChatRoomRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchChatRooms() async throws -> [ChatRoom] {
        let descriptor = FetchDescriptor<ChatRoom>(
            sortBy: [SortDescriptor(\ChatRoom.timestamp, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ [ChatRoomRepository] Failed to fetch chat rooms: \(error)")
            throw RepositoryError.fetchFailed(error)
        }
    }

    func fetchChatRoom(by id: UUID) async throws -> ChatRoom? {
        let descriptor = FetchDescriptor<ChatRoom>(
            predicate: #Predicate { $0.id == id }
        )

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("❌ [ChatRoomRepository] Failed to fetch chat room: \(error)")
            throw RepositoryError.fetchFailed(error)
        }
    }

    func saveChatRoom(_ chatRoom: ChatRoom) async throws {
        do {
            modelContext.insert(chatRoom)
            try modelContext.save()
        } catch {
            print("❌ [ChatRoomRepository] Failed to save chat room: \(error)")
            throw RepositoryError.saveFailed(error)
        }
    }

    func updateChatRoom(_ chatRoom: ChatRoom, lastMessage: String, timestamp: Date) async throws {
        do {
            chatRoom.lastMessage = lastMessage
            chatRoom.timestamp = timestamp
            try modelContext.save()
        } catch {
            print("❌ [ChatRoomRepository] Failed to update chat room: \(error)")
            throw RepositoryError.updateFailed(error)
        }
    }

    func updateUnreadCount(for chatRoomId: UUID, count: Int) async throws {
        guard let chatRoom = try await fetchChatRoom(by: chatRoomId) else {
            throw RepositoryError.updateFailed(NSError(domain: "ChatRoom not found", code: 404))
        }

        do {
            chatRoom.unreadCount = count
            try modelContext.save()
        } catch {
            print("❌ [ChatRoomRepository] Failed to update unread count: \(error)")
            throw RepositoryError.updateFailed(error)
        }
    }

    func deleteChatRoom(_ chatRoom: ChatRoom) async throws {
        do {
            modelContext.delete(chatRoom)
            try modelContext.save()
        } catch {
            print("❌ [ChatRoomRepository] Failed to delete chat room: \(error)")
            throw RepositoryError.deleteFailed(error)
        }
    }
}
