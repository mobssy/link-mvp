//
//  ChatService.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import Combine
import SwiftData
import UserNotifications
import UIKit

@MainActor
class ChatService: ObservableObject, ChatServiceProtocol {
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected

    private var notificationsEnabled: Bool { UserDefaults.standard.bool(forKey: "notificationsEnabled") }

    private var timer: Timer?
    private var randomMessageTimer: Timer?
    private var hasStartedConnection = false
    private var hasRequestedNotificationAuth = false
    var modelContext: ModelContext {
        didSet {
            if !hasStartedConnection {
                startConnection()
                hasStartedConnection = true
            }
        }
    }
    private var cancellables = Set<AnyCancellable>()

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case reconnecting

        var displayText: String {
            let isKorean: Bool = {
                if let saved = UserDefaults.standard.string(forKey: "selectedLanguage") {
                    return saved.hasPrefix("ko")
                }
                if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String], let first = langs.first {
                    return first.hasPrefix("ko")
                }
                return false
            }()
            switch self {
            case .disconnected: return isKorean ? "연결 끊김" : "Disconnected"
            case .connecting: return isKorean ? "연결 중..." : "Connecting..."
            case .connected: return isKorean ? "연결됨" : "Connected"
            case .reconnecting: return isKorean ? "재연결 중..." : "Reconnecting..."
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
        // Connection will start when a proper modelContext is attached by the view.
    }

    deinit {
        // Only perform non-actor-isolated cleanup in deinit
        timer?.invalidate()
        randomMessageTimer?.invalidate()
        randomMessageTimer = nil
    }

    private func ensureNotificationSetup() {
        guard !hasRequestedNotificationAuth else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        center.delegate = LocalNotificationDelegate.shared
        hasRequestedNotificationAuth = true
    }

    private func setAppBadgeCount(_ count: Int) {
        let effectiveCount = notificationsEnabled ? count : 0
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(effectiveCount) { error in
                if let error = error {
                    print("❌ Failed to set badge count: \(error)")
                }
            }
        } else {
            setLegacyBadgeCount(effectiveCount)
        }
    }

    @available(iOS, deprecated: 17.0, message: "Use UNUserNotificationCenter.setBadgeCount on iOS 17+")
    private func setLegacyBadgeCount(_ count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
    }

    func startConnection() {
        ensureNotificationSetup()
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
        randomMessageTimer?.invalidate()
        randomMessageTimer = nil
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
        randomMessageTimer?.invalidate()
        let interval = Double.random(in: 15...45)
        randomMessageTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(randomMessageTimerFired(_:)), userInfo: nil, repeats: true)
    }

    @objc private func randomMessageTimerFired(_ timer: Timer) {
        // As ChatService is @MainActor and the timer runs on the main run loop, this is safe.
        simulateIncomingMessage()
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
        Task { @MainActor in
            randomChatRoom.lastMessage = randomMessage
            randomChatRoom.timestamp = Date()
            randomChatRoom.unreadCount += 1

            do {
                try modelContext.save()
            } catch {
                print("❌ simulateIncomingMessage 저장 실패: \(error)")
            }

            // Update badge count based on total unread across all rooms
            do {
                let rooms = try modelContext.fetch(FetchDescriptor<ChatRoom>())
                let totalUnread = rooms.map { $0.unreadCount }.reduce(0, +)
                self.setAppBadgeCount(totalUnread)

                // Schedule a local notification for the incoming message (respect user setting)
                if self.notificationsEnabled {
                    let content = UNMutableNotificationContent()
                    content.title = randomChatRoom.name
                    content.body = randomMessage
                    content.sound = .default
                    content.badge = NSNumber(value: totalUnread)
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    if #available(iOS 17.0, *) {
                        try await UNUserNotificationCenter.current().add(request)
                    } else {
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            UNUserNotificationCenter.current().add(request) { error in
                                if let error = error { continuation.resume(throwing: error) } else { continuation.resume() }
                            }
                        }
                    }
                } else {
                    // Notifications disabled: keep badge at 0
                    self.setAppBadgeCount(0)
                }
            } catch {
                print("❌ Failed to update badge/schedule notification: \(error)")
            }
        }

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
        // 이 서비스의 modelContext에 바인딩된 인스턴스로 다시 가져와서 업데이트합니다.
        // 서로 다른 ModelContext 간의 객체를 저장하려고 하면 Core Data/SwiftData 예외가 발생할 수 있습니다.
        let roomID = chatRoom.id
        do {
            let descriptor = FetchDescriptor<ChatRoom>(predicate: #Predicate { $0.id == roomID })
            if let room = try modelContext.fetch(descriptor).first {
                room.unreadCount = 0
                try modelContext.save()
            } else {
                // Refetch 실패 시, 최소한의 폴백 처리
                print("⚠️ markAsRead: 해당 채팅방을 현재 컨텍스트에서 찾지 못했습니다.")
            }
        } catch {
            print("❌ markAsRead 저장 실패: \(error)")
        }
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

class LocalNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound, .badge])
    }
}
