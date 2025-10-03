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

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText: String = ""
    @Published var isTyping = false
    @Published var otherUserTyping = false
    @Published var isOnline = true
    @Published var replyingToMessage: Message?
    
    private var modelContext: ModelContext
    private var chatRoom: ChatRoom
    private var chatService: ChatServiceProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    private let currentUserId = "currentUser" // 실제 앱에서는 사용자 관리 시스템에서 가져옴
    
    init(modelContext: ModelContext, chatRoom: ChatRoom, chatService: ChatServiceProtocol? = nil) {
        self.modelContext = modelContext
        self.chatRoom = chatRoom
        self.chatService = chatService
        loadMessages()
        setupNotificationObservers()
        markAsRead()
    }
    
    deinit {
        cancellables.removeAll()
        typingTimer?.invalidate()
    }
    
    func loadMessages() {
        let chatRoomIdString = chatRoom.id.uuidString
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate<Message> { message in
                message.chatRoomId == chatRoomIdString
            },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        do {
            messages = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load messages: \(error)")
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
    
    func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = Message(
            text: newMessageText, 
            isFromCurrentUser: true, 
            chatRoomId: chatRoom.id.uuidString,
            replyToMessageId: replyingToMessage?.id
        )
        
        modelContext.insert(message)
        messages.append(message)
        
        // 채팅방 마지막 메시지 업데이트
        chatRoom.lastMessage = newMessageText
        chatRoom.timestamp = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("❌ sendMessage 저장 실패: \(error)")
        }
        
        // 실시간 서비스로 메시지 전송
        chatService?.sendMessage(message, to: chatRoom)
        
        newMessageText = ""
        replyingToMessage = nil // 답장 상태 초기화
        stopTyping()
        
        // 자동 응답 (실시간 느낌을 위해 약간 지연)
        sendAutoResponse()
    }
    
    func sendImage(_ imageData: Data) {
        let message = Message(
            imageData: imageData,
            isFromCurrentUser: true,
            chatRoomId: chatRoom.id.uuidString
        )
        
        modelContext.insert(message)
        messages.append(message)
        
        // 채팅방 마지막 메시지 업데이트
        chatRoom.lastMessage = "사진을 보냈습니다"
        chatRoom.timestamp = Date()
        
        do {
            try modelContext.save()
        } catch {
            print("❌ sendImage 저장 실패: \(error)")
        }
        
        // 실시간 서비스로 이미지 전송
        chatService?.sendMessage(message, to: chatRoom)
        
        // 자동 응답
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
        
        modelContext.insert(message)
        messages.append(message)
        
        // 채팅방 마지막 메시지 업데이트
        chatRoom.lastMessage = "\(fileName).\(fileExtension)"
        chatRoom.timestamp = Date()
        
        try? modelContext.save()
        
        // 실시간 서비스로 파일 전송
        chatService?.sendMessage(message, to: chatRoom)
        
        // 자동 응답
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
            
            modelContext.insert(response)
            messages.append(response)
            
            chatRoom.lastMessage = randomResponse
            chatRoom.timestamp = Date()
            
            try? modelContext.save()
        }
    }
    
    private func markAsRead() {
        chatService?.markAsRead(chatRoom: chatRoom)
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
        
        do {
            try modelContext.save()
            // UI 업데이트를 위해 messages 배열 갱신 트리거
            objectWillChange.send()
        } catch {
            print("Failed to save reaction: \(error)")
        }
        
        // 실제 앱에서는 서버로 반응 전송
        chatService?.sendReaction(emoji, to: message, in: chatRoom)
    }
    
    func removeReaction(_ emoji: String, from message: Message) {
        message.removeReaction(emoji, from: currentUserId)
        
        do {
            try modelContext.save()
            objectWillChange.send()
        } catch {
            print("Failed to remove reaction: \(error)")
        }
        
        // 실제 앱에서는 서버로 반응 제거 전송
        chatService?.removeReaction(emoji, from: message, in: chatRoom)
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
        
        do {
            try modelContext.save()
            objectWillChange.send()
        } catch {
            print("Failed to edit message: \(error)")
        }
        
        // 실제 앱에서는 서버로 편집된 메시지 전송
        chatService?.editMessage(message, in: chatRoom)
    }
    
    func deleteMessage(_ message: Message) {
        guard message.isFromCurrentUser else { return }
        
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages.remove(at: index)
        }
        
        modelContext.delete(message)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete message: \(error)")
        }
        
        // 실제 앱에서는 서버로 메시지 삭제 전송
        chatService?.deleteMessage(message, in: chatRoom)
    }
}

