//
//  ChatView+Friends.swift
//  TalkMVP
//

import SwiftUI
import SwiftData

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
            print("❌ [ChatView] Failed to check friendship: \(error)")
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
            print("❌ [ChatView] Failed to mark messages as read: \(error)")
        }
    }

    func addFriendToChatRoom() {
        guard let otherUserId = chatRoom.otherUserId,
              let otherUserEmail = chatRoom.otherUserEmail,
              let currentUserId = getCurrentUserId() else {
            print("❌ [ChatView] Missing user information for friend request")
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
            print("❌ [ChatView] Failed to send friend request: \(error)")
        }
    }

    func getCurrentUserId() -> String? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        do {
            return try modelContext.fetch(descriptor).first?.id.uuidString
        } catch {
            print("❌ [ChatView] Failed to get current user: \(error)")
            return nil
        }
    }

    func toggleChatNotifications() {
        chatRoom.notificationsEnabled.toggle()
        try? modelContext.save()
    }

    func blockUser() {
        guard let otherUserId = chatRoom.otherUserId,
              let currentUserId = getCurrentUserId() else {
            print("❌ [ChatView] Missing user information for blocking")
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
            print("❌ [ChatView] Failed to block user: \(error)")
        }
    }

    func openFriendProfile() {
        showingFriendProfile = true
    }
}
