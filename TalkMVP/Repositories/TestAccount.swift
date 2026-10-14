//
//  TestAccount.swift
//  TalkMVP
//
//  The one local account test mode signs into
//

import Foundation
import SwiftData

/// Test mode signs into a single local "tester" account. Earlier builds created a new tester,
/// with its own copy of the sample friends, every time test mode was entered and never removed
/// the previous ones, so a store can hold dozens of them that nothing can reach any more.
@MainActor
enum TestAccount {
    static let username = "tester"
    static let email = "test@example.com"

    /// Stored test accounts, the one worth keeping first: the signed-in one, otherwise the
    /// most recently active. Matched on both username and email, so a real account that
    /// happens to use one of them is never mistaken for it.
    static func all(in context: ModelContext) throws -> [User] {
        let username = Self.username
        let email = Self.email
        let accounts = try context.fetch(FetchDescriptor<User>(
            predicate: #Predicate { $0.username == username && $0.email == email },
            sortBy: [SortDescriptor(\.lastActiveAt, order: .reverse)]
        ))
        return accounts.filter(\.isCurrentUser) + accounts.filter { !$0.isCurrentUser }
    }

    /// Deletes every test account except `keep`, together with the friendships that belong to
    /// them. Does not save.
    /// - Returns: How many accounts were deleted.
    @discardableResult
    static func removeAll(except keep: User?, in context: ModelContext) throws -> Int {
        let extras = try all(in: context).filter { $0.id != keep?.id }
        guard !extras.isEmpty else { return 0 }
        let ids = Set(extras.map(\.id.uuidString))
        for friendship in try context.fetch(FetchDescriptor<Friendship>())
        where ids.contains(friendship.ownerUserId) || ids.contains(friendship.userId) || ids.contains(friendship.friendId) {
            context.delete(friendship)
        }
        extras.forEach(context.delete)
        return extras.count
    }
}
