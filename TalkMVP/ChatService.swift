//
//  ChatService.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import Combine
import SwiftData

@MainActor
class ChatService: ObservableObject, ChatServiceProtocol {
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private var timer: Timer?
    var modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case reconnecting
        
        var displayText: String {
            switch self {
            case .disconnected: return "연결 끊김"
            case .connecting: return "연결 중..."
            case .connected: return "연결됨"
            case .reconnecting: return "재연결 중..."
            }
        }
        
        var color: String {
            switch self {
            case .disconnected: return "red"
            case .connecting: return "orange"
            case .connected: return "green"
            case .reconnecting: return "orange"
            }
        }
    }
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        startConnection()
    }
    
    deinit {
        // Only perform non-actor-isolated cleanup in deinit
        timer?.invalidate()
    }
    
    func startConnection() {
        connectionStatus = .connecting
        
        // 실제 WebSocket 연결 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.connectionStatus = .connected
            self.isConnected = true
            self.startHeartbeat()
            self.startRandomMessageSimulation()
        }
    }
    
    func disconnect() {
        connectionStatus = .disconnected
        isConnected = false
        timer?.invalidate()
        timer = nil
    }
    
    func reconnect() {
        disconnect()
        connectionStatus = .reconnecting
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.startConnection()
        }
    }
    
    private func startHeartbeat() {
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            // 실제 앱에서는 서버로 heartbeat 전송
            print("Heartbeat sent")
        }
    }
    
    // 실시간 메시지 시뮬레이션
    private func startRandomMessageSimulation() {
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 15...45), repeats: true) { _ in
            Task { @MainActor in
                self.simulateIncomingMessage()
            }
        }
    }
    
    private func simulateIncomingMessage() {
        // 랜덤하게 채팅방 선택
        let descriptor = FetchDescriptor<ChatRoom>()
        guard let chatRooms = try? modelContext.fetch(descriptor),
              let randomChatRoom = chatRooms.randomElement() else { return }
        
        let randomMessages = [
            "안녕하세요! 어떻게 지내세요?",
            "오늘 날씨가 정말 좋네요 ☀️",
            "커피 한잔 할까요?",
            "업무는 어떠신가요?",
            "주말에 뭐 하세요?",
            "새로운 소식이 있어요!",
            "이 사진 한번 보세요 📸",
            "점심 뭐 드셨어요?",
            "요즘 바쁘시죠?",
            "연락 드려요! 😊"
        ]
        
        let randomMessage = randomMessages.randomElement() ?? "안녕하세요!"
        
        let message = Message(
            text: randomMessage,
            isFromCurrentUser: false,
            sender: randomChatRoom.name,
            chatRoomId: randomChatRoom.id.uuidString
        )
        
        modelContext.insert(message)
        
        // 채팅방 정보 업데이트
        randomChatRoom.lastMessage = randomMessage
        randomChatRoom.timestamp = Date()
        randomChatRoom.unreadCount += 1
        
        try? modelContext.save()
        
        // 알림 시뮬레이션
        NotificationCenter.default.post(
            name: .newMessageReceived,
            object: nil,
            userInfo: ["message": message, "chatRoom": randomChatRoom]
        )
    }
    
    func sendMessage(_ message: Message, to chatRoom: ChatRoom) {
        // 실제 서버로 메시지 전송 시뮬레이션
        print("Sending message to server: \(message.text)")
        
        // 전송 성공 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 메시지 전송 상태 업데이트 (실제 앱에서 구현)
            print("Message sent successfully")
        }
    }
    
    func markAsRead(chatRoom: ChatRoom) {
        chatRoom.unreadCount = 0
        try? modelContext.save()
    }
    
    func sendReaction(_ emoji: String, to message: Message, in chatRoom: ChatRoom) {
        // 실제 서버로 반응 전송 시뮬레이션
        print("Sending reaction \(emoji) to message \(message.id) in room \(chatRoom.name)")
        // ViewModel에서 이미 로컬 모델 업데이트 및 저장을 처리합니다.
    }
    
    func removeReaction(_ emoji: String, from message: Message, in chatRoom: ChatRoom) {
        // 실제 서버로 반응 제거 전송 시뮬레이션
        print("Removing reaction \(emoji) from message \(message.id) in room \(chatRoom.name)")
    }
    
    func editMessage(_ message: Message, in chatRoom: ChatRoom) {
        // 실제 서버로 편집 메시지 전송 시뮬레이션
        print("Editing message \(message.id) in room \(chatRoom.name)")
        // 로컬 저장은 ViewModel에서 처리되었습니다.
    }
    
    func deleteMessage(_ message: Message, in chatRoom: ChatRoom) {
        // 실제 서버로 메시지 삭제 전송 시뮬레이션
        print("Deleting message \(message.id) in room \(chatRoom.name)")
        // 로컬 삭제는 ViewModel에서 처리되었습니다.
    }
}

// 알림 확장
extension Notification.Name {
    static let newMessageReceived = Notification.Name("newMessageReceived")
    static let messageStatusUpdated = Notification.Name("messageStatusUpdated")
}

