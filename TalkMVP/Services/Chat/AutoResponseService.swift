//
//  AutoResponseService.swift
//  TalkMVP
//

import Foundation

/// Produces the simulated reply from the other side of a conversation.
@MainActor
protocol AutoResponding {
    func generateResponse(
        for chatRoom: ChatRoom,
        onTypingChange: @escaping (Bool) -> Void,
        onMessage: @escaping (Message) -> Void
    ) async throws
}

@MainActor
final class AutoResponseService: AutoResponding {
    /// How long the other side takes, in seconds.
    nonisolated struct Pacing: Sendable {
        /// Before they start typing, as if reading the message.
        var reading: ClosedRange<Double>
        /// The least time "typing…" shows, even when the reply is ready sooner.
        var minimumTyping: ClosedRange<Double>

        static let natural = Pacing(reading: 1.0...2.5, minimumTyping: 1.0...2.0)
        static let immediate = Pacing(reading: 0...0, minimumTyping: 0...0)
    }

    private let messageRepository: MessageRepositoryProtocol
    private let chatRoomRepository: ChatRoomRepositoryProtocol
    /// Tried in order; the first reply written is sent.
    private let writers: [any ReplyWriting]
    private let pacing: Pacing
    /// Picks which member of a group chat answers.
    private let pickMember: ([String]) -> String?
    /// The language a member writes in, when it isn't the chat's.
    private let memberLanguage: (String) -> String?
    /// How many recent messages the writers see.
    private let historyLimit = 12

    init(
        messageRepository: MessageRepositoryProtocol,
        chatRoomRepository: ChatRoomRepositoryProtocol,
        writers: [any ReplyWriting] = [OnDeviceReplyWriter(), CannedReplyWriter()],
        pacing: Pacing = .natural,
        pickMember: @escaping ([String]) -> String? = { $0.randomElement() },
        memberLanguage: @escaping (String) -> String? = { _ in nil }
    ) {
        self.messageRepository = messageRepository
        self.chatRoomRepository = chatRoomRepository
        self.writers = writers
        self.pacing = pacing
        self.pickMember = pickMember
        self.memberLanguage = memberLanguage
    }

    func generateResponse(
        for chatRoom: ChatRoom,
        onTypingChange: @escaping (Bool) -> Void,
        onMessage: @escaping (Message) -> Void
    ) async throws {
        try await Task.sleep(for: .seconds(Double.random(in: pacing.reading)))
        let conversation = try await messageRepository
            .fetchMessages(for: chatRoom.id.uuidString, limit: historyLimit, before: nil)
            .map(SummaryMessage.init)

        // "Typing…" covers the time the reply actually takes to write.
        onTypingChange(true)
        let typingStarted = ContinuousClock.now
        let sender = chatRoom.otherSideSender(pickingFrom: pickMember)
        let text = await reply(to: conversation, as: sender, language: memberLanguage(sender))
        let typingLeft = Duration.seconds(Double.random(in: pacing.minimumTyping)) - (ContinuousClock.now - typingStarted)
        do {
            if typingLeft > .zero { try await Task.sleep(for: typingLeft) }
        } catch {
            onTypingChange(false)
            throw error
        }
        onTypingChange(false)

        let response = Message(
            text: text,
            isFromCurrentUser: false,
            sender: sender,
            chatRoomId: chatRoom.id.uuidString
        )
        if chatRoom.disappearingDuration > 0 {
            response.isDisappearing = true
            response.disappearAfterSeconds = chatRoom.disappearingDuration
        }

        try await messageRepository.saveMessage(response)
        try await chatRoomRepository.updateChatRoom(chatRoom, lastMessage: text, timestamp: Date())
        onMessage(response)
    }

    private func reply(to conversation: [SummaryMessage], as partner: String, language: String?) async -> String {
        for writer in writers {
            if let text = await writer.reply(to: conversation, as: partner, language: language) { return text }
        }
        return "👍"
    }
}
