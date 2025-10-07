//
//  MessageRepository.swift
//  TalkMVP
//
//  Repository pattern for Message data access
//

import Foundation
import SwiftData

/// Protocol defining message data operations
/// This abstraction allows easy replacement with Firebase later
protocol MessageRepositoryProtocol {
    /// Fetch messages for a specific chat room
    func fetchMessages(for chatRoomId: String) async throws -> [Message]

    /// Save a new message
    func saveMessage(_ message: Message) async throws

    /// Update an existing message
    func updateMessage(_ message: Message) async throws

    /// Delete a message
    func deleteMessage(_ message: Message) async throws

    /// Mark messages as read in a chat room
    func markMessagesAsRead(in chatRoomId: String) async throws
}

/// SwiftData implementation of MessageRepository
/// This will be replaced with FirebaseMessageRepository later
@MainActor
class LocalMessageRepository: MessageRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchMessages(for chatRoomId: String) async throws -> [Message] {
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { message in
                message.chatRoomId == chatRoomId
            },
            sortBy: [SortDescriptor(\Message.timestamp)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ [MessageRepository] Failed to fetch messages: \(error)")
            throw RepositoryError.fetchFailed(error)
        }
    }

    func saveMessage(_ message: Message) async throws {
        do {
            modelContext.insert(message)
            try modelContext.save()
        } catch {
            print("❌ [MessageRepository] Failed to save message: \(error)")
            throw RepositoryError.saveFailed(error)
        }
    }

    func updateMessage(_ message: Message) async throws {
        do {
            try modelContext.save()
        } catch {
            print("❌ [MessageRepository] Failed to update message: \(error)")
            throw RepositoryError.updateFailed(error)
        }
    }

    func deleteMessage(_ message: Message) async throws {
        do {
            modelContext.delete(message)
            try modelContext.save()
        } catch {
            print("❌ [MessageRepository] Failed to delete message: \(error)")
            throw RepositoryError.deleteFailed(error)
        }
    }

    func markMessagesAsRead(in chatRoomId: String) async throws {
        // Implementation would mark all unread messages as read
        // For now, this is handled by ChatRoom.unreadCount
    }
}

/// Repository-specific errors
enum RepositoryError: LocalizedError {
    case fetchFailed(Error)
    case saveFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update data: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        }
    }
}
