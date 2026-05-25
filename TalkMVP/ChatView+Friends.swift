//
//  ChatView+Friends.swift
//  TalkMVP
//

import SwiftUI
import SwiftData
import os

private let friendsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatView.Friends")

extension ChatView {
    func checkIfFriend() {
        guard let otherUserId = chatRoom.otherUserId else {
            isFriend = true
            return
        }

        let descriptor = FetchDescriptor<Friendship>(
            predicate: #Predicate { friendship in
                friendship.friendId == otherUserId && friendship.status.rawValue == "accepted"
            }
        )

        do {
            let friendships = try modelContext.fetch(descriptor)
            isFriend = !friendships.isEmpty
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

    func addFriendToChatRoom() {
        guard let otherUserId = chatRoom.otherUserId,
              let otherUserEmail = chatRoom.otherUserEmail,
              let currentUserId = getCurrentUserId() else {
            friendsLogger.warning("Missing user information for friend request")
            return
        }

        let outgoing = Friendship(
            userId: currentUserId,
            friendId: otherUserId,
            friendName: chatRoom.name,
            friendEmail: otherUserEmail,
            status: .pending
        )
        outgoing.ownerUserId = currentUserId
        modelContext.insert(outgoing)

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        if let currentUser = try? modelContext.fetch(descriptor).first {
            let mirror = Friendship(
                userId: otherUserId,
                friendId: currentUserId,
                friendName: currentUser.displayName,
                friendEmail: currentUser.email,
                status: .pending
            )
            mirror.ownerUserId = otherUserId
            modelContext.insert(mirror)
        }

        do {
            try modelContext.save()
            isFriend = true
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
                NotificationCenter.default.post(name: .friendshipStatusChanged, object: nil, userInfo: ["friendId": otherUserId])
            }
        } catch {
            friendsLogger.error("Failed to block user: \(error.localizedDescription, privacy: .public)")
            box.viewModel?.errorMessage = localizedText("block_failed")
        }
    }

    func openFriendProfile() {
        showingFriendProfile = true
    }
}
