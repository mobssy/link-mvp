//
//  MessageRepository.swift
//  TalkMVP
//
//  Repository pattern for Message data access
//

import Foundation
import SwiftData
import os

private let repoLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "MessageRepository")

/// Protocol defining message data operations
/// This abstraction allows easy replacement with Firebase later
protocol MessageRepositoryProtocol {
    /// Fetch a page of messages for a chat room, sorted oldest-first.
    /// - Parameters:
    ///   - chatRoomId: The room to query.
    ///   - limit: Maximum number of messages to return.
    ///   - before: If non-nil, only messages older than this timestamp are returned (enables pagination).
    func fetchMessages(for chatRoomId: String, limit: Int, before: Date?) async throws -> [Message]

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

    func fetchMessages(for chatRoomId: String, limit: Int, before: Date?) async throws -> [Message] {
        // When `before` is nil we want all messages, so we use distantFuture as the upper bound.
        let cutoff = before ?? Date.distantFuture
        var descriptor = FetchDescriptor<Message>(
            predicate: #Predicate<Message> { message in
                message.chatRoomId == chatRoomId && message.timestamp < cutoff
            },
            // Fetch newest-first so fetchLimit discards the oldest, then we reverse.
            sortBy: [SortDescriptor(\Message.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            let fetched = try modelContext.fetch(descriptor)
            return fetched.reversed() // Return chronological (oldest → newest)
        } catch {
            repoLogger.error("Failed to fetch messages: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.fetchFailed(error)
        }
    }

    func saveMessage(_ message: Message) async throws {
        do {
            modelContext.insert(message)
            try modelContext.save()
        } catch {
            repoLogger.error("Failed to save message: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.saveFailed(error)
        }
    }

    func updateMessage(_ message: Message) async throws {
        do {
            try modelContext.save()
        } catch {
            repoLogger.error("Failed to update message: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.updateFailed(error)
        }
    }

    func deleteMessage(_ message: Message) async throws {
        do {
            modelContext.delete(message)
            try modelContext.save()
        } catch {
            repoLogger.error("Failed to delete message: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.deleteFailed(error)
        }
    }

    func markMessagesAsRead(in chatRoomId: String) async throws {
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate<Message> { message in
                message.chatRoomId == chatRoomId && !message.isFromCurrentUser && !message.isRead
            }
        )
        do {
            let unread = try modelContext.fetch(descriptor)
            guard !unread.isEmpty else { return }
            unread.forEach { $0.isRead = true }
            try modelContext.save()
            repoLogger.info("Marked \(unread.count) messages as read in room \(chatRoomId, privacy: .private)")
        } catch {
            repoLogger.error("Failed to mark messages as read: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.updateFailed(error)
        }
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
