//
//  User.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import SwiftData

@Model
class User {
    @Attribute(.unique) var id: UUID
    var username: String
    var displayName: String
    var email: String
    var profileImageData: Data?
    var statusMessage: String
    var isCurrentUser: Bool
    var createdAt: Date
    var lastActiveAt: Date

    // 친구 관계
    @Relationship(deleteRule: .cascade) var friendships: [Friendship] = []

    init(username: String, displayName: String, email: String, statusMessage: String = "", isCurrentUser: Bool = false) {
        self.id = UUID()
        self.username = username
        self.displayName = displayName
        self.email = email
        self.profileImageData = nil
        self.statusMessage = statusMessage
        self.isCurrentUser = isCurrentUser
        self.createdAt = Date()
        self.lastActiveAt = Date()
    }
}

// 친구 관계 모델
@Model
class Friendship {
    @Attribute(.unique) var id: UUID
    var userId: String // User ID
    var friendId: String // Friend User ID
    var friendName: String
    var friendEmail: String
    var status: FriendshipStatus
    var createdAt: Date
    var ownerUserId: String

    init(userId: String, friendId: String, friendName: String, friendEmail: String, status: FriendshipStatus = .pending) {
        self.id = UUID()
        self.userId = userId
        self.friendId = friendId
        self.friendName = friendName
        self.friendEmail = friendEmail
        self.status = status
        self.createdAt = Date()
        self.ownerUserId = userId
    }
}

enum FriendshipStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case accepted = "accepted"
    case hidden = "hidden"
    case blocked = "blocked"

    var displayName: String {
        switch self {
        case .pending: return "대기중"
        case .accepted: return "친구"
        case .hidden: return "숨김"
        case .blocked: return "차단됨"
        }
    }
}
