//
//  ChatView+Friends.swift
//  TalkMVP
//

import SwiftUI
import SwiftData
import os

private let friendsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatView.Friends")

extension ChatView {
    var friendships: FriendshipRepositoryProtocol {
        LocalFriendshipRepository(modelContext: modelContext)
    }

    // One fetch of the user's own records for the other person, classified in memory, so
    // isFriend, friendRequestSent, isBlocked and profileFriendship are all set in one pass.
    // Another account on the device may have records for the same person; those don't count.
    func checkIfFriend() {
        guard let otherUserId = chatRoom.otherUserId else {
            isFriend = true
            return
        }
        guard let currentUserId = getCurrentUserId() else {
            isFriend = false
            profileFriendship = nil
            friendRequestSent = false
            isBlocked = false
            return
        }

        do {
            let records = try friendships.friendships(ownedBy: currentUserId, friendId: otherUserId)
            let accepted = records.first(where: { $0.status == .accepted })
            let pending  = records.first(where: { $0.status == .pending })
            let blocked  = records.first(where: { $0.status == .blocked })

            isFriend = accepted != nil
            profileFriendship = accepted          // Bug fix: populate for FriendProfileView sheet
            friendRequestSent = pending != nil && accepted == nil
            isBlocked = blocked != nil && accepted == nil
        } catch {
            isFriend = false
        }
    }

    /// How the user stands with the person a one-to-one chat is with: from their records when
    /// the room knows who they are, otherwise by name, like the bubbles. Nil until looked up.
    var oneToOneStanding: FriendStanding? {
        if chatRoom.otherUserId != nil {
            return isFriend ? .friend : (friendRequestSent ? .requested : .stranger)
        }
        return senderStandings.map { $0[chatRoom.name] ?? .stranger }
    }

    var friendBanner: FriendBanner {
        FriendBanner(isGroup: chatRoom.isGroup, standing: oneToOneStanding, isBlocked: isBlocked)
    }

    /// Sends the friend request the banner offers, after its confirmation.
    func requestFriendship() {
        do {
            try sendFriendRequestToOtherSide()
        } catch {
            viewModel?.errorMessage = localizedText("friend_request_failed")
        }
    }

    /// A room that knows the other person's account sends the request to it; a sample or
    /// imported room only knows their name.
    func sendFriendRequestToOtherSide() throws {
        if chatRoom.otherUserId != nil {
            addFriendToChatRoom()
        } else {
            try sendFriendRequest(toSender: chatRoom.name)
        }
    }

    /// Works out how the user stands with every sender at once; the bubbles read the result.
    func loadSenderStandings() {
        guard let currentUserId = getCurrentUserId(),
              let statuses = try? friendships.statusesByName(ownedBy: currentUserId)
        else { return }
        senderStandings = statuses.mapValues { FriendStanding($0) }
    }

    /// Sends a friend request to the person who wrote a message, from its bubble.
    func sendFriendRequest(toSender name: String) throws {
        guard let me = currentUser() else { return }
        try friendships.sendRequest(
            from: FriendRequestParty(id: me.id.uuidString, name: me.displayName, email: me.email),
            to: FriendRequestParty(id: UUID().uuidString, name: name, email: "")
        )
        senderStandings?[name] = .requested

        // Fire a local notification to simulate receiver-side alert
        let manager = NotificationManager()
        let senderName = me.displayName
        let senderEmail = me.email
        Task { await manager.scheduleFriendRequestNotification(from: senderName, email: senderEmail) }
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
              let otherUserEmail = chatRoom.otherUserEmail else {
            friendsLogger.warning("Missing user information for friend request")
            return
        }
        guard let me = currentUser() else {
            friendsLogger.warning("Current user not found for friend request")
            return
        }

        do {
            try friendships.sendRequest(
                from: FriendRequestParty(id: me.id.uuidString, name: me.displayName, email: me.email),
                to: FriendRequestParty(id: otherUserId, name: chatRoom.name, email: otherUserEmail)
            )
            // Bug fix: set friendRequestSent instead of isFriend — status is still .pending
            friendRequestSent = true
            senderStandings?[chatRoom.name] = .requested
            NotificationCenter.default.post(name: .friendshipPendingCreated, object: nil, userInfo: ["friendId": otherUserId])
        } catch {
            viewModel?.errorMessage = localizedText("friend_request_failed")
        }
    }

    /// The signed-in user, from the one record flagged as current.
    func currentUser() -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            friendsLogger.error("Failed to get current user: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func getCurrentUserId() -> String? {
        currentUser()?.id.uuidString
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
        setOtherUserStatus(.blocked)
    }

    func unblockUser() {
        setOtherUserStatus(.accepted)
    }

    private func setOtherUserStatus(_ status: FriendshipStatus) {
        guard let otherUserId = chatRoom.otherUserId,
              let currentUserId = getCurrentUserId() else {
            friendsLogger.warning("Missing user information for blocking or unblocking")
            return
        }

        do {
            guard let friendship = try friendships.friendship(ownedBy: currentUserId, friendId: otherUserId) else { return }
            try friendships.setStatus(status, of: friendship)
            isBlocked = status == .blocked
            isFriend = status == .accepted
            NotificationCenter.default.post(name: .friendshipStatusChanged, object: nil, userInfo: ["friendId": otherUserId])
        } catch {
            viewModel?.errorMessage = localizedText("block_failed")
        }
    }

    /// Opens the profile of whoever wrote a message: in a group chat the member, otherwise the
    /// person the chat is with.
    /// The chat's title: a one-to-one chat opens the person's profile, a group its members.
    func openTitle() {
        if chatRoom.isGroup {
            showingGroupInfo = true
        } else {
            openProfile(of: chatRoom.name)
        }
    }

    func openProfile(of sender: String) {
        // A group has no profile of its own: a message carrying its name opens its members.
        if chatRoom.isGroup && !chatRoom.memberNames.contains(sender) {
            showingGroupInfo = true
            return
        }
        if chatRoom.memberNames.contains(sender) {
            profileMember = (sender, getCurrentUserId().flatMap { try? friendships.friendship(ownedBy: $0, named: sender) })
        } else {
            profileMember = nil
        }
        showingFriendProfile = true
    }
}
