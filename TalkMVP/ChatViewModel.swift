//
//  ChatViewModel.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import Combine
import SwiftData
import UIKit
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText: String = ""
    @Published var isTyping = false
    @Published var otherUserTyping = false
    @Published var isOnline = true
    @Published var replyingToMessage: Message?
    @Published var errorMessage: String?

    // Translation state (no placeholder text while translating)
    @Published var translations: [UUID: String] = [:]
    @Published var translating: Set<UUID> = []

    // Read translation settings from UserDefaults to avoid @AppStorage dependency in non-View types
    private var translationEnabled: Bool { UserDefaults.standard.bool(forKey: "translationEnabled") }
    private var translationAutoDetect: Bool { UserDefaults.standard.bool(forKey: "translationAutoDetect") }
    private var translationTargetLanguage: String { UserDefaults.standard.string(forKey: "translationTargetLanguage") ?? "auto" }

    // Dependencies injected via constructor (Dependency Inversion Principle)
    private let messageRepository: MessageRepositoryProtocol
    private let chatRoomRepository: ChatRoomRepositoryProtocol
    private var chatRoom: ChatRoom
    private var chatService: ChatServiceProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    private let currentUserId = "currentUser" // 실제 앱에서는 사용자 관리 시스템에서 가져옴

    init(
        messageRepository: MessageRepositoryProtocol,
        chatRoomRepository: ChatRoomRepositoryProtocol,
        chatRoom: ChatRoom,
        chatService: ChatServiceProtocol? = nil
    ) {
        self.messageRepository = messageRepository
        self.chatRoomRepository = chatRoomRepository
        self.chatRoom = chatRoom
        self.chatService = chatService

        Task {
            await loadMessages()
        }
        setupNotificationObservers()
        Task {
            await markAsRead()
        }
    }

    // Convenience initializer for existing code (backward compatibility)
    convenience init(modelContext: ModelContext, chatRoom: ChatRoom, chatService: ChatServiceProtocol? = nil) {
        self.init(
            messageRepository: LocalMessageRepository(modelContext: modelContext),
            chatRoomRepository: LocalChatRoomRepository(modelContext: modelContext),
            chatRoom: chatRoom,
            chatService: chatService
        )
    }

    deinit {
        cancellables.removeAll()
        typingTimer?.invalidate()
    }

    func loadMessages() async {
        do {
            messages = try await messageRepository.fetchMessages(for: chatRoom.id.uuidString)
        } catch {
            print("❌ [ChatViewModel] Failed to load messages: \(error)")
            errorMessage = "Failed to load messages. Please try again."
        }
    }

    func translateIfNeeded(_ message: Message) {
        // Only translate text messages when translation is enabled
        guard translationEnabled else { return }
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard translations[message.id] == nil else { return }

        let isKorean: Bool = {
            if let saved = UserDefaults.standard.string(forKey: "selectedLanguage") { return saved.hasPrefix("ko") }
            if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String], let first = langs.first { return first.hasPrefix("ko") }
            return false
        }()
        // Show a user-friendly placeholder while translating
        self.translations[message.id] = isKorean ? "번역중..." : "Translating..."

        Task {
            let result = await AIService.shared.translate(
                trimmed,
                autoDetect: translationAutoDetect,
                target: translationTargetLanguage
            )
            await MainActor.run {
                self.translations[message.id] = result
            }
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .newMessageReceived)
            .sink { [weak self] notification in
                guard let self = self,
                      let message = notification.userInfo?["message"] as? Message,
                      message.chatRoomId == self.chatRoom.id.uuidString else { return }

                Task { @MainActor in
                    self.messages.append(message)
                    self.translateIfNeeded(message)
                    self.simulateTypingIndicator()
                }
            }
            .store(in: &cancellables)
    }

    func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let message = Message(
            text: newMessageText,
            isFromCurrentUser: true,
            chatRoomId: chatRoom.id.uuidString,
            replyToMessageId: replyingToMessage?.id
        )

        Task {
            do {
                // Save message via repository
                try await messageRepository.saveMessage(message)

                // Update UI
                messages.append(message)
                translateIfNeeded(message)

                // Update chat room's last message
                try await chatRoomRepository.updateChatRoom(
                    chatRoom,
                    lastMessage: newMessageText,
                    timestamp: Date()
                )

                // Send via real-time service
                chatService?.sendMessage(message, to: chatRoom)

            } catch {
                print("❌ [ChatViewModel] Failed to send message: \(error)")
                errorMessage = "Failed to send message. Please try again."
                // Rollback UI: remove the optimistically added message
                if let index = messages.lastIndex(where: { $0.id == message.id }) {
                    messages.remove(at: index)
                }
            }
        }

        newMessageText = ""
        replyingToMessage = nil
        stopTyping()

        // Auto response
        sendAutoResponse()
    }

    func sendImage(_ imageData: Data) {
        let message = Message(
            imageData: imageData,
            isFromCurrentUser: true,
            chatRoomId: chatRoom.id.uuidString
        )

        Task {
            do {
                try await messageRepository.saveMessage(message)

                messages.append(message)

                try await chatRoomRepository.updateChatRoom(
                    chatRoom,
                    lastMessage: "사진을 보냈습니다",
                    timestamp: Date()
                )

                chatService?.sendMessage(message, to: chatRoom)

            } catch {
                print("❌ [ChatViewModel] Failed to send image: \(error)")
                errorMessage = "Failed to send image. Please try again."
                // Rollback UI
                if let index = messages.lastIndex(where: { $0.id == message.id }) {
                    messages.remove(at: index)
                }
            }
        }

        sendAutoResponse()
    }

    func sendFile(fileName: String, fileExtension: String, fileSize: Int) {
        let message = Message(
            fileName: fileName,
            fileExtension: fileExtension,
            fileSize: fileSize,
            isFromCurrentUser: true,
            chatRoomId: chatRoom.id.uuidString
        )

        Task {
            do {
                try await messageRepository.saveMessage(message)

                messages.append(message)

                try await chatRoomRepository.updateChatRoom(
                    chatRoom,
                    lastMessage: "\(fileName).\(fileExtension)",
                    timestamp: Date()
                )

                chatService?.sendMessage(message, to: chatRoom)

            } catch {
                print("❌ [ChatViewModel] Failed to send file: \(error)")
                errorMessage = "Failed to send file. Please try again."
                // Rollback UI
                if let index = messages.lastIndex(where: { $0.id == message.id }) {
                    messages.remove(at: index)
                }
            }
        }

        sendAutoResponse()
    }

    // 타이핑 상태 관리
    func startTyping() {
        // 항상 타이핑 상태로 전환하고 타이머를 리셋합니다.
        isTyping = true

        // 실제 앱에서는 서버로 타이핑 시작 이벤트 전송
        print("User started typing in chat: \(chatRoom.name)")

        // 타이핑 타이머 리셋 (selector 기반으로 @Sendable 캡처 회피)
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(typingTimerFired(_:)), userInfo: nil, repeats: false)
    }

    @objc private func typingTimerFired(_ timer: Timer) {
        stopTyping()
    }

    func stopTyping() {
        guard isTyping else { return }
        isTyping = false

        // 실제 앱에서는 서버로 타이핑 중단 이벤트 전송
        print("User stopped typing in chat: \(chatRoom.name)")

        typingTimer?.invalidate()
        typingTimer = nil
    }

    private func simulateTypingIndicator() {
        otherUserTyping = true

        // 2-3초 후 타이핑 인디케이터 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.5...3.0)) {
            self.otherUserTyping = false
        }
    }

    private func sendAutoResponse() {
        Task {
            // 실시간 느낌을 위해 랜덤 지연
            try await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.0...5.0) * 1_000_000_000))

            let responses = [
                "네 알겠습니다! 👍", "좋은 생각이네요 😊", "그렇네요!",
                "재미있겠어요 😄", "사진 감사해요! 📸", "파일 잘 받았습니다 📄",
                "언제 시간 되실 때 연락주세요", "오늘도 좋은 하루 되세요!",
                "네네 맞습니다", "정말요? 대박이네요! 🎉"
            ]
            let randomResponse = responses.randomElement() ?? "네!"

            // 타이핑 인디케이터 먼저 표시
            otherUserTyping = true
            try await Task.sleep(nanoseconds: UInt64(Double.random(in: 1.0...2.0) * 1_000_000_000))
            otherUserTyping = false

            let response = Message(
                text: randomResponse,
                isFromCurrentUser: false,
                sender: chatRoom.name,
                chatRoomId: chatRoom.id.uuidString
            )

            do {
                try await messageRepository.saveMessage(response)

                messages.append(response)
                translateIfNeeded(response)

                try await chatRoomRepository.updateChatRoom(
                    chatRoom,
                    lastMessage: randomResponse,
                    timestamp: Date()
                )
            } catch {
                print("❌ [ChatViewModel] Failed to save auto response: \(error)")
            }
        }
    }

    private func markAsRead() async {
        do {
            try await chatRoomRepository.updateUnreadCount(for: chatRoom.id, count: 0)
            chatService?.markAsRead(chatRoom: chatRoom)
        } catch {
            print("❌ [ChatViewModel] Failed to mark as read: \(error)")
        }
    }

    // 온라인 상태 확인 (시뮬레이션)
    func checkOnlineStatus() {
        // 실제 앱에서는 서버에서 사용자 온라인 상태 확인
        isOnline = Bool.random() // 랜덤하게 온라인/오프라인 시뮬레이션

        // 5초마다 상태 업데이트
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.checkOnlineStatus()
        }
    }

    // MARK: - 반응(Reactions) 관련 메서드들

    func addReaction(_ emoji: String, to message: Message) {
        message.addReaction(emoji, from: currentUserId)

        Task {
            do {
                try await messageRepository.updateMessage(message)
                // UI update trigger
                objectWillChange.send()

                // Send to server
                chatService?.sendReaction(emoji, to: message, in: chatRoom)
            } catch {
                print("❌ [ChatViewModel] Failed to save reaction: \(error)")
                errorMessage = "Failed to add reaction. Please try again."
                // Rollback UI: remove the reaction from the message
                message.removeReaction(emoji, from: currentUserId)
                objectWillChange.send()
            }
        }
    }

    func removeReaction(_ emoji: String, from message: Message) {
        message.removeReaction(emoji, from: currentUserId)

        Task {
            do {
                try await messageRepository.updateMessage(message)
                objectWillChange.send()

                chatService?.removeReaction(emoji, from: message, in: chatRoom)
            } catch {
                print("❌ [ChatViewModel] Failed to remove reaction: \(error)")
            }
        }
    }

    func toggleReaction(_ emoji: String, for message: Message) {
        if message.hasReaction(emoji, from: currentUserId) {
            removeReaction(emoji, from: message)
        } else {
            addReaction(emoji, to: message)
        }
    }

    // MARK: - 답장 관련 메서드들

    func setReplyMessage(_ message: Message?) {
        replyingToMessage = message
    }

    func clearReplyMessage() {
        replyingToMessage = nil
    }

    func getRepliedMessage(for messageId: UUID) -> Message? {
        return messages.first { $0.id == messageId }
    }

    // MARK: - 메시지 편집/삭제 메서드들

    func editMessage(_ message: Message, newText: String) {
        guard message.isFromCurrentUser else { return }

        message.text = newText
        message.isEdited = true
        message.editedAt = Date()

        Task {
            do {
                try await messageRepository.updateMessage(message)
                objectWillChange.send()

                chatService?.editMessage(message, in: chatRoom)
            } catch {
                print("❌ [ChatViewModel] Failed to edit message: \(error)")
            }
        }
    }

    func deleteMessage(_ message: Message) {
        guard message.isFromCurrentUser else { return }

        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages.remove(at: index)
        }

        Task {
            do {
                try await messageRepository.deleteMessage(message)

                chatService?.deleteMessage(message, in: chatRoom)
            } catch {
                print("❌ [ChatViewModel] Failed to delete message: \(error)")
                errorMessage = "Failed to delete message. Please try again."
                // Rollback UI: add message back at the correct position
                messages.append(message)
                messages.sort { $0.timestamp < $1.timestamp }
            }
        }
    }
}
