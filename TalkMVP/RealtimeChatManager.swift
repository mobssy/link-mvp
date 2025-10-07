//
//  RealtimeChatManager.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import Combine
import SwiftData

@MainActor
class RealtimeChatManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var onlineUsers: Set<String> = []

    private var simulationTimer: Timer?
    private var modelContext: ModelContext
    private var currentUserId: String?

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case reconnecting

        var displayText: String {
            switch self {
            case .disconnected: return "연결 끊김"
            case .connecting: return "연결중..."
            case .connected: return "온라인"
            case .reconnecting: return "재연결중..."
            }
        }

        var color: String {
            switch self {
            case .disconnected: return "red"
            case .connecting, .reconnecting: return "orange"
            case .connected: return "green"
            }
        }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        startConnection()
    }

    func setCurrentUser(_ userId: String) {
        currentUserId = userId
        simulateUserOnline(userId)
    }

    func startConnection() {
        connectionStatus = .connecting

        // 실제 앱에서는 WebSocket 연결
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.connectionStatus = .connected
            self.isConnected = true
            self.startSimulation()
        }
    }

    func disconnect() {
        connectionStatus = .disconnected
        isConnected = false
        simulationTimer?.invalidate()
        simulationTimer = nil
        onlineUsers.removeAll()
    }

    func reconnect() {
        connectionStatus = .reconnecting

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.connectionStatus = .connected
            self.isConnected = true
            self.startSimulation()
        }
    }

    private func startSimulation() {
        // 실시간 채팅 시뮬레이션
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task {
                await self.simulateIncomingMessage()
            }
        }

        // 온라인 사용자 시뮬레이션
        simulateOnlineUsers()
    }

    private func simulateOnlineUsers() {
        let sampleUsers = ["friend1", "friend2", "friend3", "friend4"]

        // 랜덤하게 사용자들을 온라인/오프라인 상태로 변경
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                let randomUser = sampleUsers.randomElement()!

                if self.onlineUsers.contains(randomUser) {
                    self.onlineUsers.remove(randomUser)
                } else {
                    self.onlineUsers.insert(randomUser)
                }
            }
        }
    }

    private func simulateUserOnline(_ userId: String) {
        onlineUsers.insert(userId)
    }

    private func simulateIncomingMessage() async {
        guard isConnected, currentUserId != nil else { return }

        // 랜덤하게 메시지 받기
        let shouldReceiveMessage = Bool.random()
        guard shouldReceiveMessage else { return }

        // 채팅방 목록 가져오기
        let descriptor = FetchDescriptor<ChatRoom>()
        guard let chatRooms = try? modelContext.fetch(descriptor),
              let randomRoom = chatRooms.randomElement() else { return }

        let incomingMessages = [
            "안녕하세요! 😊",
            "지금 뭐하고 있어요?",
            "오늘 날씨가 좋네요!",
            "커피 한잔 어때요? ☕️",
            "새로운 소식 있나요?",
            "주말에 시간 있으세요?",
            "재미있는 영화 추천해주세요!",
            "맛있는 식당 알아요? 🍽️"
        ]

        let randomMessage = incomingMessages.randomElement()!
        let message = Message(
            text: randomMessage,
            isFromCurrentUser: false,
            sender: randomRoom.name,
            chatRoomId: randomRoom.id.uuidString
        )

        modelContext.insert(message)

        // 채팅방 업데이트
        randomRoom.lastMessage = randomMessage
        randomRoom.timestamp = Date()
        randomRoom.unreadCount += 1

        try? modelContext.save()

        // 실시간 알림 시뮬레이션
        sendNotification(from: randomRoom.name, message: randomMessage)
    }

    private func sendNotification(from sender: String, message: String) {
        // 실제 앱에서는 로컬 푸시 알림
        print("📱 새 메시지: \(sender) - \(message)")
    }

    func sendMessage(_ message: Message, to chatRoom: ChatRoom) {
        // 실제 앱에서는 서버로 메시지 전송
        // 여기서는 로컬에서만 처리

        modelContext.insert(message)
        chatRoom.lastMessage = message.text
        chatRoom.timestamp = message.timestamp

        try? modelContext.save()

        // 읽음 표시 시뮬레이션 (2초 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // 실제 앱에서는 서버에서 읽음 상태 업데이트
            print("✓ 메시지가 전달되었습니다")
        }
    }

    func markAsRead(chatRoom: ChatRoom) {
        chatRoom.unreadCount = 0
        try? modelContext.save()
    }

    deinit {
        simulationTimer?.invalidate()
    }
}
