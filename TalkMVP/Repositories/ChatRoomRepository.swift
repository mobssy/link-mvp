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

    /// The one-to-one room with `userId`, created and saved the first time it is asked for,
    /// so every way of starting a chat with someone lands in the same conversation.
    func directChatRoom(withUserId userId: String, name: String, email: String?) async throws -> ChatRoom

    /// Delete a chat room together with every message in it
    func deleteChatRoom(_ chatRoom: ChatRoom) async throws
}

/// SwiftData implementation of ChatRoomRepository
@MainActor
class LocalChatRoomRepository: ChatRoomRepositoryProtocol {
    private let modelContext: ModelContext
    private let attachmentFiles: AttachmentFileStoring

    init(modelContext: ModelContext, attachmentFiles: AttachmentFileStoring = DiskAttachmentFileStore()) {
        self.modelContext = modelContext
        self.attachmentFiles = attachmentFiles
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

    func directChatRoom(withUserId userId: String, name: String, email: String?) async throws -> ChatRoom {
        let otherUserId: String? = userId
        var descriptor = FetchDescriptor<ChatRoom>(
            predicate: #Predicate { $0.otherUserId == otherUserId && !$0.isOrganizationRoom }
        )
        descriptor.fetchLimit = 1
        do {
            if let existing = try modelContext.fetch(descriptor).first {
                return existing
            }
        } catch {
            print("❌ [ChatRoomRepository] Failed to look up direct chat room: \(error)")
            throw RepositoryError.fetchFailed(error)
        }

        let room = ChatRoom(name: name, profileImage: "person.circle.fill")
        room.otherUserId = userId
        room.otherUserEmail = email
        try await saveChatRoom(room)
        return room
    }

    func deleteChatRoom(_ chatRoom: ChatRoom) async throws {
        // Messages belong to a room through `chatRoomId`, not a SwiftData relationship,
        // so they have to be deleted explicitly or they outlive the room.
        let roomId = chatRoom.id.uuidString
        let filePaths: [String]
        do {
            let withFiles = FetchDescriptor<Message>(
                predicate: #Predicate { $0.chatRoomId == roomId && $0.fileURL != nil }
            )
            filePaths = try modelContext.fetch(withFiles).compactMap(\.fileURL)
            try modelContext.delete(model: Message.self, where: #Predicate { $0.chatRoomId == roomId })
            modelContext.delete(chatRoom)
            try modelContext.save()
        } catch {
            print("❌ [ChatRoomRepository] Failed to delete chat room: \(error)")
            throw RepositoryError.deleteFailed(error)
        }
        filePaths.forEach(attachmentFiles.removeFile(atStoredPath:))
    }
}
