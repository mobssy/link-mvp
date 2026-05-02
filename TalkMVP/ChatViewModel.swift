//
//  ChatViewModel.swift
//  L!nkMVP
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
    private var translationTargetLanguage: String {
        let stored = UserDefaults.standard.string(forKey: "translationTargetLanguage") ?? "auto"
        guard stored == "auto" else { return stored }
        return LanguageManager.currentLanguageCode
    }

    // Dependencies injected via constructor (Dependency Inversion Principle)
    private let messageRepository: MessageRepositoryProtocol
    private let chatRoomRepository: ChatRoomRepositoryProtocol
    private let autoResponseService: AutoResponseService
    private var chatRoom: ChatRoom
    private var chatService: ChatServiceProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    private var onlineStatusTask: Task<Void, Never>?
    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "currentUserId") ?? "currentUser"
    }

    private func localizedVM(ko: String, en: String, ja: String, zh: String, es: String) -> String {
        let lang = LanguageManager.currentLanguageCode
        if lang.hasPrefix("ko") { return ko }
        if lang.hasPrefix("ja") { return ja }
        if lang.hasPrefix("zh") { return zh }
        if lang.hasPrefix("es") { return es }
        return en
    }

    init(
        messageRepository: MessageRepositoryProtocol,
        chatRoomRepository: ChatRoomRepositoryProtocol,
        chatRoom: ChatRoom,
        chatService: ChatServiceProtocol? = nil
    ) {
        self.messageRepository = messageRepository
        self.chatRoomRepository = chatRoomRepository
        self.autoResponseService = AutoResponseService(messageRepository: messageRepository, chatRoomRepository: chatRoomRepository)
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
        onlineStatusTask?.cancel()
    }

    func loadMessages() async {
        do {
            messages = try await messageRepository.fetchMessages(for: chatRoom.id.uuidString)
        } catch {
            print("❌ [ChatViewModel] Failed to load messages: \(error)")
            errorMessage = localizedVM(ko: "메시지를 불러오지 못했습니다.", en: "Failed to load messages.", ja: "メッセージの読み込みに失敗しました。", zh: "加载消息失败。", es: "Error al cargar los mensajes.")
        }
    }

    func translateIfNeeded(_ message: Message) {
        // Only translate text messages when translation is enabled
        guard translationEnabled else { return }
        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard translations[message.id] == nil else { return }

        let currentLanguage = LanguageManager.currentLanguageCode
        // Show a user-friendly placeholder while translating
        let translatingText: String
        if currentLanguage.hasPrefix("ja") {
            translatingText = "翻訳中..."
        } else if currentLanguage.hasPrefix("zh") {
            translatingText = "翻译中..."
        } else if currentLanguage.hasPrefix("es") {
            translatingText = "Traduciendo..."
        } else if currentLanguage.hasPrefix("ko") {
            translatingText = "번역중..."
        } else {
            translatingText = "Translating..."
        }
        self.translations[message.id] = translatingText

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
        if chatRoom.disappearingDuration > 0 {
            message.isDisappearing = true
            message.disappearAfterSeconds = chatRoom.disappearingDuration
        }

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
                errorMessage = localizedVM(ko: "메시지 전송에 실패했습니다.", en: "Failed to send message.", ja: "メッセージの送信に失敗しました。", zh: "发送消息失败。", es: "Error al enviar el mensaje.")
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
                    lastMessage: localizedVM(ko: "사진을 보냈습니다", en: "Photo sent", ja: "写真を送りました", zh: "发送了照片", es: "Foto enviada"),
                    timestamp: Date()
                )

                chatService?.sendMessage(message, to: chatRoom)

            } catch {
                print("❌ [ChatViewModel] Failed to send image: \(error)")
                errorMessage = localizedVM(ko: "사진 전송에 실패했습니다.", en: "Failed to send image.", ja: "画像の送信に失敗しました。", zh: "发送图片失败。", es: "Error al enviar la imagen.")
                // Rollback UI
                if let index = messages.lastIndex(where: { $0.id == message.id }) {
                    messages.remove(at: index)
                }
            }
        }

        sendAutoResponse()
    }

    func sendVoiceMessage(audioData: Data, duration: Double) {
        let message = Message(
            audioData: audioData,
            duration: duration,
            isFromCurrentUser: true,
            chatRoomId: chatRoom.id.uuidString
        )
        if chatRoom.disappearingDuration > 0 {
            message.isDisappearing = true
            message.disappearAfterSeconds = chatRoom.disappearingDuration
        }

        Task {
            do {
                try await messageRepository.saveMessage(message)
                messages.append(message)
                try await chatRoomRepository.updateChatRoom(
                    chatRoom,
                    lastMessage: localizedVM(ko: "음성 메시지", en: "Voice message", ja: "音声メッセージ", zh: "语音消息", es: "Mensaje de voz"),
                    timestamp: Date()
                )
                chatService?.sendMessage(message, to: chatRoom)
            } catch {
                print("❌ [ChatViewModel] Failed to send voice message: \(error)")
                errorMessage = localizedVM(ko: "음성 메시지 전송에 실패했습니다.", en: "Failed to send voice message.", ja: "音声メッセージの送信に失敗しました。", zh: "发送语音消息失败。", es: "Error al enviar el mensaje de voz.")
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
                errorMessage = localizedVM(ko: "파일 전송에 실패했습니다.", en: "Failed to send file.", ja: "ファイルの送信に失敗しました。", zh: "发送文件失败。", es: "Error al enviar el archivo.")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.5...3.0)) { [weak self] in
            self?.otherUserTyping = false
        }
    }

    private func sendAutoResponse() {
        Task {
            do {
                try await autoResponseService.generateResponse(
                    for: chatRoom,
                    onTypingChange: { [weak self] typing in self?.otherUserTyping = typing },
                    onMessage: { [weak self] message in
                        guard let self else { return }
                        messages.append(message)
                        translateIfNeeded(message)
                    }
                )
            } catch {
                print("❌ [ChatViewModel] Auto response failed: \(error)")
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

    func startOnlineStatusPolling() {
        stopOnlineStatusPolling()
        onlineStatusTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.isOnline = Bool.random()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopOnlineStatusPolling() {
        onlineStatusTask?.cancel()
        onlineStatusTask = nil
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

    /// 메시지 삭제
    /// - Parameter message: 삭제할 메시지
    /// - Parameter forEveryone: true면 완전 삭제, false면 본인만 숨김 처리
    func deleteMessage(_ message: Message, forEveryone: Bool = false) {
        // 본인 메시지는 완전 삭제 가능
        if message.isFromCurrentUser {
            if forEveryone {
                // 완전 삭제 (모든 사용자에게서 삭제)
                deleteMessageCompletely(message)
            } else {
                // 본인만 숨김 처리
                hideMessageForCurrentUser(message)
            }
        } else {
            // 상대방 메시지는 본인만 숨김 처리
            hideMessageForCurrentUser(message)
        }
    }
    
    /// 메시지를 완전히 삭제 (발신자만 가능)
    private func deleteMessageCompletely(_ message: Message) {
        let deletedId = message.id
        if let index = messages.firstIndex(where: { $0.id == deletedId }) {
            messages.remove(at: index)
        }

        // Clear reply references in UI immediately so reply previews don't show a ghost
        let orphans = messages.filter { $0.replyToMessageId == deletedId }
        orphans.forEach { $0.replyToMessageId = nil }

        Task {
            do {
                // Persist cleared reply references before deleting the parent
                for orphan in orphans {
                    try await messageRepository.updateMessage(orphan)
                }
                try await messageRepository.deleteMessage(message)
                chatService?.deleteMessage(message, in: chatRoom)
            } catch {
                print("❌ [ChatViewModel] Failed to delete message: \(error)")
                errorMessage = localizedVM(ko: "메시지 삭제에 실패했습니다.", en: "Failed to delete message.", ja: "メッセージの削除に失敗しました。", zh: "删除消息失败。", es: "Error al eliminar el mensaje.")
                messages.append(message)
                messages.sort { $0.timestamp < $1.timestamp }
            }
        }
    }
    
    /// 메시지를 본인만 숨김 처리 (로컬에서만 삭제)
    private func hideMessageForCurrentUser(_ message: Message) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages.remove(at: index)
        }

        Task {
            do {
                // 로컬에서만 삭제 (실제로는 숨김 플래그를 설정하는 것이 더 나을 수 있음)
                try await messageRepository.deleteMessage(message)
                
                // 서버에는 숨김 처리 요청 전송 (실제 구현 시)
                // chatService?.hideMessage(message, for: currentUserId, in: chatRoom)
            } catch {
                print("❌ [ChatViewModel] Failed to hide message: \(error)")
                errorMessage = localizedVM(ko: "메시지 숨기기에 실패했습니다.", en: "Failed to hide message.", ja: "メッセージの非表示に失敗しました。", zh: "隐藏消息失败。", es: "Error al ocultar el mensaje.")
                // Rollback UI
                messages.append(message)
                messages.sort { $0.timestamp < $1.timestamp }
            }
        }
    }
}
