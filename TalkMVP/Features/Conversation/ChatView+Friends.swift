//
//  ChatView+Friends.swift
//  TalkMVP
//

import SwiftUI
import SwiftData
import os

private let friendsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatView.Friends")

extension ChatView {
    // Bug fix: widened predicate fetches all statuses, then classifies in memory
    // so isFriend, friendRequestSent, isBlocked, and profileFriendship are all set in one pass.
    func checkIfFriend() {
        guard let otherUserId = chatRoom.otherUserId else {
            isFriend = true
            return
        }

        let descriptor = FetchDescriptor<Friendship>(
            predicate: #Predicate { friendship in
                friendship.friendId == otherUserId
            }
        )

        do {
            let friendships = try modelContext.fetch(descriptor)
            let accepted = friendships.first(where: { $0.status == .accepted })
            let pending  = friendships.first(where: { $0.status == .pending })
            let blocked  = friendships.first(where: { $0.status == .blocked })

            isFriend = accepted != nil
            profileFriendship = accepted          // Bug fix: populate for FriendProfileView sheet
            friendRequestSent = pending != nil && accepted == nil
            isBlocked = blocked != nil && accepted == nil
        } catch {
            friendsLogger.error("Failed to check friendship: \(error.localizedDescription, privacy: .public)")
            isFriend = false
        }
    }

    func markMessagesAsRead() {
        guard let messages = viewModel?.messages else { return }

        for message in messages where !message.isFromCurrentUser && !message.isRead {
            message.isRead = true
        }

        do {
            try modelContext.save()
        } catch {
            friendsLogger.error("Failed to mark messages as read: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Bug fix: single User fetch gives both currentUserId and displayName,
    // replacing the previous double-fetch pattern.
    func addFriendToChatRoom() {
        guard let otherUserId = chatRoom.otherUserId,
              let otherUserEmail = chatRoom.otherUserEmail else {
            friendsLogger.warning("Missing user information for friend request")
            return
        }

        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        guard let currentUser = try? modelContext.fetch(userDescriptor).first else {
            friendsLogger.warning("Current user not found for friend request")
            return
        }
        let currentUserId = currentUser.id.uuidString

        let outgoing = Friendship(
            userId: currentUserId,
            friendId: otherUserId,
            friendName: chatRoom.name,
            friendEmail: otherUserEmail,
            status: .pending
        )
        outgoing.ownerUserId = currentUserId
        modelContext.insert(outgoing)

        let mirror = Friendship(
            userId: otherUserId,
            friendId: currentUserId,
            friendName: currentUser.displayName,
            friendEmail: currentUser.email,
            status: .pending
        )
        mirror.ownerUserId = otherUserId
        modelContext.insert(mirror)

        do {
            try modelContext.save()
            // Bug fix: set friendRequestSent instead of isFriend — status is still .pending
            friendRequestSent = true
            NotificationCenter.default.post(name: .friendshipPendingCreated, object: nil, userInfo: ["friendId": otherUserId])
        } catch {
            friendsLogger.error("Failed to send friend request: \(error.localizedDescription, privacy: .public)")
            box.viewModel?.errorMessage = localizedText("friend_request_failed")
        }
    }

    func getCurrentUserId() -> String? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        do {
            return try modelContext.fetch(descriptor).first?.id.uuidString
        } catch {
            friendsLogger.error("Failed to get current user: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func toggleChatNotifications() {
        chatRoom.notificationsEnabled.toggle()
        do {
            try modelContext.save()
        } catch {
            friendsLogger.error("Failed to save notification setting: \(error.localizedDescription, privacy: .public)")
        }
    }

    func blockUser() {
        guard let otherUserId = chatRoom.otherUserId,
              let currentUserId = getCurrentUserId() else {
            friendsLogger.warning("Missing user information for blocking")
            return
        }

        let descriptor = FetchDescriptor<Friendship>(
            predicate: #Predicate { friendship in
                friendship.ownerUserId == currentUserId && friendship.friendId == otherUserId
            }
        )

        do {
            let friendships = try modelContext.fetch(descriptor)
            if let friendship = friendships.first {
                friendship.status = .blocked
                try modelContext.save()
                isBlocked = true
                isFriend = false
                NotificationCenter.default.post(name: .friendshipStatusChanged, object: nil, userInfo: ["friendId": otherUserId])
            }
        } catch {
            friendsLogger.error("Failed to block user: \(error.localizedDescription, privacy: .public)")
            box.viewModel?.errorMessage = localizedText("block_failed")
        }
    }

    func unblockUser() {
        guard let otherUserId = chatRoom.otherUserId,
              let currentUserId = getCurrentUserId() else {
            friendsLogger.warning("Missing user information for unblocking")
            return
        }

        let descriptor = FetchDescriptor<Friendship>(
            predicate: #Predicate { friendship in
                friendship.ownerUserId == currentUserId && friendship.friendId == otherUserId
            }
        )

        do {
            let friendships = try modelContext.fetch(descriptor)
            if let friendship = friendships.first {
                friendship.status = .accepted
                try modelContext.save()
                isBlocked = false
                isFriend = true
                NotificationCenter.default.post(name: .friendshipStatusChanged, object: nil, userInfo: ["friendId": otherUserId])
            }
        } catch {
            friendsLogger.error("Failed to unblock user: \(error.localizedDescription, privacy: .public)")
            box.viewModel?.errorMessage = localizedText("block_failed")
        }
    }

    func openFriendProfile() {
        showingFriendProfile = true
    }
}
