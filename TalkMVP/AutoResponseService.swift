//
//  AutoResponseService.swift
//  TalkMVP
//

import Foundation

@MainActor
final class AutoResponseService {
    private let messageRepository: MessageRepositoryProtocol
    private let chatRoomRepository: ChatRoomRepositoryProtocol

    init(
        messageRepository: MessageRepositoryProtocol,
        chatRoomRepository: ChatRoomRepositoryProtocol
    ) {
        self.messageRepository = messageRepository
        self.chatRoomRepository = chatRoomRepository
    }

    func generateResponse(
        for chatRoom: ChatRoom,
        onTypingChange: @escaping (Bool) -> Void,
        onMessage: @escaping (Message) -> Void
    ) async throws {
        try await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.0...5.0) * 1_000_000_000))

        let responses = [
            "네 알겠습니다! 👍", "좋은 생각이네요 😊", "그렇네요!",
            "재미있겠어요 😄", "사진 감사해요! 📸", "파일 잘 받았습니다 📄",
            "언제 시간 되실 때 연락주세요", "오늘도 좋은 하루 되세요!",
            "네네 맞습니다", "정말요? 대박이네요! 🎉"
        ]
        let randomResponse = responses.randomElement() ?? "네!"

        onTypingChange(true)
        try await Task.sleep(nanoseconds: UInt64(Double.random(in: 1.0...2.0) * 1_000_000_000))
        onTypingChange(false)

        let response = Message(
            text: randomResponse,
            isFromCurrentUser: false,
            sender: chatRoom.name,
            chatRoomId: chatRoom.id.uuidString
        )
        if chatRoom.disappearingDuration > 0 {
            response.isDisappearing = true
            response.disappearAfterSeconds = chatRoom.disappearingDuration
        }

        try await messageRepository.saveMessage(response)
        try await chatRoomRepository.updateChatRoom(chatRoom, lastMessage: randomResponse, timestamp: Date())
        onMessage(response)
    }
}
