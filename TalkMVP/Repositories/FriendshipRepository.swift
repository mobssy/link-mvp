//
//  FriendshipRepository.swift
//  TalkMVP
//
//  Repository pattern for Friendship data access
//

import Foundation
import SwiftData
import os

private let friendshipRepoLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "FriendshipRepository")

/// One side of a friend request: who sends it, or who it goes to.
struct FriendRequestParty: Equatable {
    let id: String
    let name: String
    let email: String
}

/// Protocol defining friendship data operations. Unlike the chat repositories these are
/// synchronous: views call them straight from buttons and swipe actions.
protocol FriendshipRepositoryProtocol {
    /// Everything that involves the user: the friendships they own (friends, requests they
    /// sent, hidden and blocked people) and the requests other people sent them.
    func friendships(involving userId: String) throws -> [Friendship]

    /// The user's status with each person, by name, from one fetch: for screens that show many
    /// people at once, such as a conversation's bubbles or the chat list's rows.
    func statusesByName(ownedBy userId: String) throws -> [String: FriendshipStatus]

    /// Every record that has `friendId` as the person on the other side.
    func friendships(withFriendId friendId: String) throws -> [Friendship]

    /// The user's own record for `friendId`, if there is one.
    func friendship(ownedBy userId: String, friendId: String) throws -> Friendship?

    /// The user's newest record for the person called `name`: a group chat knows its members
    /// only by name.
    func friendship(ownedBy userId: String, named name: String) throws -> Friendship?

    /// Saves the sender's pending request and the receiver's mirror of it together. If saving
    /// fails neither is kept, so a request never half exists.
    func sendRequest(from sender: FriendRequestParty, to receiver: FriendRequestParty) throws

    /// Adds friendships the user already has, such as sample or imported friends.
    func addFriendships(_ friendships: [Friendship]) throws

    func setStatus(_ status: FriendshipStatus, of friendship: Friendship) throws
    func setFavorite(_ isFavorite: Bool, of friendship: Friendship) throws
    func setNotificationsEnabled(_ isEnabled: Bool, of friendship: Friendship) throws
    func delete(_ friendships: [Friendship]) throws
}

/// SwiftData implementation of FriendshipRepository
@MainActor
final class LocalFriendshipRepository: FriendshipRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func friendships(involving userId: String) throws -> [Friendship] {
        try fetch(FetchDescriptor<Friendship>(predicate: #Predicate { f in
            f.ownerUserId == userId || f.friendId == userId
        }))
    }

    func statusesByName(ownedBy userId: String) throws -> [String: FriendshipStatus] {
        let owned = try fetch(FetchDescriptor<Friendship>(
            predicate: #Predicate { $0.ownerUserId == userId },
            sortBy: [SortDescriptor(\.createdAt)]
        ))
        // The newest record for a name wins, so asking again after a block is undone shows the latest.
        return Dictionary(owned.map { ($0.friendName, $0.status) }, uniquingKeysWith: { _, newer in newer })
    }

    func friendships(withFriendId friendId: String) throws -> [Friendship] {
        try fetch(FetchDescriptor<Friendship>(predicate: #Predicate { $0.friendId == friendId }))
    }

    func friendship(ownedBy userId: String, friendId: String) throws -> Friendship? {
        var descriptor = FetchDescriptor<Friendship>(predicate: #Predicate { f in
            f.ownerUserId == userId && f.friendId == friendId
        })
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }

    func friendship(ownedBy userId: String, named name: String) throws -> Friendship? {
        var descriptor = FetchDescriptor<Friendship>(
            predicate: #Predicate { $0.ownerUserId == userId && $0.friendName == name },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try fetch(descriptor).first
    }

    func sendRequest(from sender: FriendRequestParty, to receiver: FriendRequestParty) throws {
        let outgoing = Friendship(userId: sender.id, friendId: receiver.id, friendName: receiver.name, friendEmail: receiver.email)
        let mirror = Friendship(userId: receiver.id, friendId: sender.id, friendName: sender.name, friendEmail: sender.email)
        modelContext.insert(outgoing)
        modelContext.insert(mirror)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(outgoing)
            modelContext.delete(mirror)
            friendshipRepoLogger.error("Failed to save friend request: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.saveFailed(error)
        }
    }

    func addFriendships(_ friendships: [Friendship]) throws {
        friendships.forEach(modelContext.insert)
        try save("add friendships")
    }

    func setStatus(_ status: FriendshipStatus, of friendship: Friendship) throws {
        friendship.status = status
        try save("change a friendship's status")
    }

    func setFavorite(_ isFavorite: Bool, of friendship: Friendship) throws {
        friendship.isFavorite = isFavorite
        try save("change a favorite")
    }

    func setNotificationsEnabled(_ isEnabled: Bool, of friendship: Friendship) throws {
        friendship.notificationsEnabled = isEnabled
        try save("change a friend's notifications")
    }

    func delete(_ friendships: [Friendship]) throws {
        friendships.forEach(modelContext.delete)
        try save("delete friendships")
    }

    private func fetch(_ descriptor: FetchDescriptor<Friendship>) throws -> [Friendship] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            friendshipRepoLogger.error("Failed to fetch friendships: \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.fetchFailed(error)
        }
    }

    private func save(_ action: String) throws {
        do {
            try modelContext.save()
        } catch {
            friendshipRepoLogger.error("Failed to \(action, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw RepositoryError.saveFailed(error)
        }
    }
}
