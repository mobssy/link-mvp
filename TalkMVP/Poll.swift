//
//  Poll.swift
//  TalkMVP
//
//  Created by David Song on 10/3/25.
//

import Foundation
import SwiftData

@Model
class Poll {
    @Attribute(.unique) var id: UUID
    var question: String
    var options: [PollOption]
    var creatorId: String
    var createdAt: Date
    var expiresAt: Date?
    var isAnonymous: Bool
    var allowMultipleChoice: Bool
    var chatRoomId: String
    
    init(
        question: String,
        options: [String],
        creatorId: String,
        chatRoomId: String,
        expiresAt: Date? = nil,
        isAnonymous: Bool = false,
        allowMultipleChoice: Bool = false
    ) {
        let pollId = UUID()
        self.id = pollId
        self.question = question
        self.options = options.enumerated().map { index, text in
            PollOption(id: UUID(), text: text, votes: [], pollId: pollId)
        }
        self.creatorId = creatorId
        self.chatRoomId = chatRoomId
        self.createdAt = Date()
        self.expiresAt = expiresAt
        self.isAnonymous = isAnonymous
        self.allowMultipleChoice = allowMultipleChoice
    }
    
    var totalVotes: Int {
        options.reduce(0) { $0 + $1.votes.count }
    }
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    func hasUserVoted(userId: String) -> Bool {
        options.contains { option in
            option.votes.contains { $0.userId == userId }
        }
    }
    
    func getUserVotes(userId: String) -> [PollOption] {
        options.filter { option in
            option.votes.contains { $0.userId == userId }
        }
    }
}

@Model
class PollOption {
    @Attribute(.unique) var id: UUID
    var text: String
    var votes: [PollVote]
    var pollId: UUID
    
    init(id: UUID = UUID(), text: String, votes: [PollVote] = [], pollId: UUID) {
        self.id = id
        self.text = text
        self.votes = votes
        self.pollId = pollId
    }
    
    var voteCount: Int {
        votes.count
    }
    
    func votePercentage(totalVotes: Int) -> Double {
        guard totalVotes > 0 else { return 0 }
        return Double(voteCount) / Double(totalVotes) * 100
    }
}

@Model
class PollVote {
    @Attribute(.unique) var id: UUID
    var userId: String
    var optionId: UUID
    var votedAt: Date
    
    init(userId: String, optionId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.optionId = optionId
        self.votedAt = Date()
    }
}