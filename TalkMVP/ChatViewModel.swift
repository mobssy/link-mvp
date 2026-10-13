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
import os

private let vmLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatViewModel")

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText: String = ""
    @Published var otherUserTyping = false
    @Published var isOnline = true
    @Published var replyingToMessage: Message?
    @Published var errorMessage: String?

    // MARK: - Pagination
    private static let pageSize = 50
    @Published private(set) var hasMoreMessages = true
    private var isLoadingMore = false

    // Dependencies injected via constructor (Dependency Inversion Principle)
    private let messageRepository: MessageRepositoryProtocol
    private let chatRoomRepository: ChatRoomRepositoryProtocol
    private let autoResponder: AutoResponding
    private var chatRoom: ChatRoom
    private var chatService: ChatServiceProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var onlineStatusTask: Task<Void, Never>?

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
        chatService: ChatServiceProtocol? = nil,
        autoResponder: AutoResponding? = nil
    ) {
        self.messageRepository = messageRepository
        self.chatRoomRepository = chatRoomRepository
        self.autoResponder = autoResponder ?? AutoResponseService(messageRepository: messageRepository, chatRoomRepository: chatRoomRepository)
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
        onlineStatusTask?.cancel()
    }

    func loadMessages() async {
        do {
            let fetched = try await messageRepository.fetchMessages(
                for: chatRoom.id.uuidString,
                limit: Self.pageSize,
                before: nil
            )
            messages = fetched
            hasMoreMessages = fetched.count == Self.pageSize
        } catch {
            vmLogger.error("Failed to load messages: \(error.localizedDescription, privacy: .public)")
            errorMessage = localizedVM(ko: "메시지를 불러오지 못했습니다.", en: "Failed to load messages.", ja: "メッセージの読み込みに失敗しました。", zh: "加载消息失败。", es: "Error al cargar los mensajes.")
        }
    }

    func loadMoreMessages() async {
        guard hasMoreMessages, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let oldestTimestamp = messages.first?.timestamp
        do {
            let older = try await messageRepository.fetchMessages(
                for: chatRoom.id.uuidString,
                limit: Self.pageSize,
                before: oldestTimestamp
            )
            // Prepend older messages; avoid duplicates at the seam
            let existingIds = Set(messages.map { $0.id })
            let unique = older.filter { !existingIds.contains($0.id) }
            messages = unique + messages
            hasMoreMessages = older.count == Self.pageSize
        } catch {
            vmLogger.error("Failed to load more messages: \(error.localizedDescription, privacy: .public)")
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
                    self.simulateTypingIndicator()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Sending

    @discardableResult
    func sendMessage() -> Task<Void, Never>? {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let message = Message(
            text: newMessageText,
            isFromCurrentUser: true,
            chatRoomId: chatRoom.id.uuidString,
            replyToMessageId: replyingToMessage?.id
        )
        newMessageText = ""
        replyingToMessage = nil

        return deliver(
            message,
            preview: message.text,
            failureMessage: localizedVM(ko: "메시지 전송에 실패했습니다.", en: "Failed to send message.", ja: "メッセージの送信に失敗しました。", zh: "发送消息失败。", es: "Error al enviar el mensaje.")
        )
    }

    @discardableResult
    func sendImage(_ imageData: Data) -> Task<Void, Never> {
        deliver(
            Message(imageData: imageData, isFromCurrentUser: true, chatRoomId: chatRoom.id.uuidString),
            preview: localizedVM(ko: "사진을 보냈습니다", en: "Photo sent", ja: "写真を送りました", zh: "发送了照片", es: "Foto enviada"),
            failureMessage: localizedVM(ko: "사진 전송에 실패했습니다.", en: "Failed to send image.", ja: "画像の送信に失敗しました。", zh: "发送图片失败。", es: "Error al enviar la imagen.")
        )
    }

    @discardableResult
    func sendVoiceMessage(audioData: Data, duration: Double) -> Task<Void, Never> {
        deliver(
            Message(audioData: audioData, duration: duration, isFromCurrentUser: true, chatRoomId: chatRoom.id.uuidString),
            preview: localizedVM(ko: "음성 메시지", en: "Voice message", ja: "音声メッセージ", zh: "语音消息", es: "Mensaje de voz"),
            failureMessage: localizedVM(ko: "음성 메시지 전송에 실패했습니다.", en: "Failed to send voice message.", ja: "音声メッセージの送信に失敗しました。", zh: "发送语音消息失败。", es: "Error al enviar el mensaje de voz.")
        )
    }

    @discardableResult
    func sendFile(fileName: String, fileExtension: String, fileSize: Int, fileURL: String? = nil) -> Task<Void, Never> {
        let message = Message(
            fileName: fileName,
            fileExtension: fileExtension,
            fileSize: fileSize,
            isFromCurrentUser: true,
            chatRoomId: chatRoom.id.uuidString
        )
        message.fileURL = fileURL
        return deliver(
            message,
            preview: localizedVM(ko: "파일을 보냈습니다", en: "Sent a file", ja: "ファイルを送りました", zh: "发送了一个文件", es: "Envió un archivo"),
            failureMessage: localizedVM(ko: "파일 전송에 실패했습니다.", en: "Failed to send file.", ja: "ファイルの送信に失敗しました。", zh: "发送文件失败。", es: "Error al enviar el archivo.")
        )
    }

    @discardableResult
    func sendVideo(_ videoData: Data) -> Task<Void, Never> {
        let preview = localizedVM(ko: "동영상을 보냈습니다", en: "Sent a video", ja: "動画を送りました", zh: "发送了一个视频", es: "Envió un video")
        let message = Message(
            text: preview,
            isFromCurrentUser: true,
            chatRoomId: chatRoom.id.uuidString,
            messageType: .video
        )
        message.videoData = videoData
        return deliver(
            message,
            preview: preview,
            failureMessage: localizedVM(ko: "동영상 전송에 실패했습니다.", en: "Failed to send video.", ja: "動画の送信に失敗しました。", zh: "发送视频失败。", es: "Error al enviar el vídeo.")
        )
    }

    @discardableResult
    func sendLocationMessage(latitude: Double, longitude: Double) -> Task<Void, Never> {
        deliver(
            Message(latitude: latitude, longitude: longitude, isFromCurrentUser: true, chatRoomId: chatRoom.id.uuidString),
            preview: localizedVM(ko: "위치를 공유했습니다", en: "Location shared", ja: "位置情報を共有しました", zh: "共享了位置", es: "Ubicación compartida"),
            failureMessage: localizedVM(ko: "위치 전송에 실패했습니다.", en: "Failed to send location.", ja: "位置情報の送信に失敗しました。", zh: "发送位置失败。", es: "Error al enviar ubicación."),
            requestsReply: false
        )
    }

    /// The one path every outgoing message takes: apply the room's options, persist it,
    /// show it, update the chat list preview and hand it to the real-time service, then
    /// (unless the caller opts out) trigger the simulated reply. If persisting fails the
    /// message is taken back out of the conversation and `errorMessage` is set.
    private func deliver(
        _ message: Message,
        preview: String,
        failureMessage: String,
        requestsReply: Bool = true
    ) -> Task<Void, Never> {
        applyRoomSettings(to: message)

        let task = Task {
            do {
                try await messageRepository.saveMessage(message)
                messages.append(message)
                try await chatRoomRepository.updateChatRoom(chatRoom, lastMessage: preview, timestamp: Date())
                chatService?.sendMessage(message, to: chatRoom)
            } catch {
                vmLogger.error("Failed to send \(message.messageType.rawValue, privacy: .public) message: \(error.localizedDescription, privacy: .public)")
                errorMessage = failureMessage
                if let index = messages.lastIndex(where: { $0.id == message.id }) {
                    messages.remove(at: index)
                }
            }
        }

        if requestsReply {
            sendAutoResponse()
        }
        return task
    }

    /// Applies the room's per-chat options to an outgoing message. Currently that's the
    /// disappearing-message timer, which covers every message type sent while it is on.
    private func applyRoomSettings(to message: Message) {
        guard chatRoom.disappearingDuration > 0 else { return }
        message.isDisappearing = true
        message.disappearAfterSeconds = chatRoom.disappearingDuration
    }

    private func simulateTypingIndicator() {
        otherUserTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.5...3.0)) { [weak self] in
            self?.otherUserTyping = false
        }
    }

    private func sendAutoResponse() {
        // Capture the dependencies up front so the pending reply (a few seconds away)
        // doesn't keep this view model alive after the chat screen has closed.
        let responder = autoResponder
        let room = chatRoom
        Task { [weak self] in
            do {
                try await responder.generateResponse(
                    for: room,
                    onTypingChange: { typing in self?.otherUserTyping = typing },
                    onMessage: { message in self?.receiveAutoResponse(message) }
                )
            } catch {
                vmLogger.error("Auto response failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func receiveAutoResponse(_ message: Message) {
        markSentMessagesAsRead()
        messages.append(message)
    }

    func markSentMessagesAsRead() {
        let unread = messages.filter { $0.isFromCurrentUser && !$0.isRead }
        guard !unread.isEmpty else { return }
        unread.forEach { $0.isRead = true }
        Task {
            for msg in unread {
                try? await messageRepository.updateMessage(msg)
            }
            objectWillChange.send()
        }
    }

    private func markAsRead() async {
        do {
            try await chatRoomRepository.updateUnreadCount(for: chatRoom.id, count: 0)
            chatService?.markAsRead(chatRoom: chatRoom)
        } catch {
            vmLogger.error("Failed to mark as read: \(error.localizedDescription, privacy: .public)")
        }
    }

    func startOnlineStatusPolling() {
        stopOnlineStatusPolling()
        onlineStatusTask = Task { [weak self] in
            while !Task.isCancelled {
                // Simulate realistic presence: 80% chance online, brief offline spikes
                self?.isOnline = Int.random(in: 1...10) <= 8
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stopOnlineStatusPolling() {
        onlineStatusTask?.cancel()
        onlineStatusTask = nil
    }

    // MARK: - 답장 관련 메서드들

    func setReplyMessage(_ message: Message?) {
        replyingToMessage = message
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
                vmLogger.error("Failed to edit message: \(error.localizedDescription, privacy: .public)")
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
                vmLogger.error("Failed to delete message: \(error.localizedDescription, privacy: .public)")
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
                vmLogger.error("Failed to hide message: \(error.localizedDescription, privacy: .public)")
                errorMessage = localizedVM(ko: "메시지 숨기기에 실패했습니다.", en: "Failed to hide message.", ja: "メッセージの非表示に失敗しました。", zh: "隐藏消息失败。", es: "Error al ocultar el mensaje.")
                // Rollback UI
                messages.append(message)
                messages.sort { $0.timestamp < $1.timestamp }
            }
        }
    }
}
