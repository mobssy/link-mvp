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
import os

private let chatServiceLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatService")

@MainActor
@Observable
class ChatService: ChatServiceProtocol {
    private var notificationsEnabled: Bool { NotificationPreferences.isEnabled() }

    @ObservationIgnored private var randomMessageTimer: Timer?
    /// Rooms on screen, which simulated messages leave alone.
    private let openRooms: OpenChatRooms
    private var hasStarted = false
    private var hasRequestedNotificationAuth = false
    var modelContext: ModelContext {
        // There is no server to connect to: once the view hands over its context, the service
        // asks for notification permission and starts the simulated incoming messages.
        didSet {
            guard !hasStarted else { return }
            hasStarted = true
            ensureNotificationSetup()
            startRandomMessageSimulation()
        }
    }

    /// - Parameter openRooms: The app's own list when nil; a default argument can't read it, since
    ///   default arguments aren't evaluated on the main actor.
    init(modelContext: ModelContext, openRooms: OpenChatRooms? = nil) {
        self.modelContext = modelContext
        self.openRooms = openRooms ?? .shared
        // Starts when the view attaches its own modelContext.
    }

    deinit {
        // The timers hold this service only weakly, so deinit does run once the
        // owning view goes away; stop them so the run loop doesn't keep firing.
        randomMessageTimer?.invalidate()
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
        UNUserNotificationCenter.current().setBadgeCount(effectiveCount) { error in
            if let error = error {
                chatServiceLogger.error("Failed to set badge count: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // 실시간 메시지 시뮬레이션
    private func startRandomMessageSimulation() {
        randomMessageTimer?.invalidate()
        let interval = Double.random(in: 15...45)
        // Block-based and weak: a target/selector timer retains its target until it is
        // invalidated, which kept every chat screen's service simulating messages forever.
        randomMessageTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Scheduled from the main actor, so the timer fires on the main run loop.
            MainActor.assumeIsolated {
                self?.simulateIncomingMessage()
            }
        }
    }

    /// Where a simulated message lands: any room but those on screen. In an open chat the other
    /// side already answers what was said; a canned line dropped in between ("점심 뭐 드셨어요?"
    /// in the middle of planning a launch) broke the conversation and its summary.
    static func roomForSimulatedMessage(in rooms: [ChatRoom], openRooms: OpenChatRooms) -> ChatRoom? {
        rooms.filter { !openRooms.contains($0.id) }.randomElement()
    }

    private func simulateIncomingMessage() {
        let descriptor = FetchDescriptor<ChatRoom>()
        guard let chatRooms = try? modelContext.fetch(descriptor),
              let randomChatRoom = Self.roomForSimulatedMessage(in: chatRooms, openRooms: openRooms) else { return }

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
        let sender = randomChatRoom.otherSideSender()

        let message = Message(
            text: randomMessage,
            isFromCurrentUser: false,
            sender: sender,
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
                chatServiceLogger.error("simulateIncomingMessage 저장 실패: \(error.localizedDescription, privacy: .public)")
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
                    if sender != randomChatRoom.name { content.subtitle = sender }
                    content.body = randomMessage
                    content.sound = .default
                    content.badge = NSNumber(value: totalUnread)
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    try await UNUserNotificationCenter.current().add(request)
                } else {
                    // Notifications disabled: keep badge at 0
                    self.setAppBadgeCount(0)
                }
            } catch {
                chatServiceLogger.error("Failed to update badge/schedule notification: \(error.localizedDescription, privacy: .public)")
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
        // 실제 서버로 메시지 전송 (서버 연동 전까지는 로컬 저장만으로 충분)
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
                chatServiceLogger.error("markAsRead: 해당 채팅방을 현재 컨텍스트에서 찾지 못했습니다.")
            }
        } catch {
            chatServiceLogger.error("markAsRead 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    func editMessage(_ message: Message, in chatRoom: ChatRoom) {
        // 실제 서버로 편집 메시지 전송 시뮬레이션
        // 로컬 저장은 ViewModel에서 처리되었습니다.
    }

    func deleteMessage(_ message: Message, in chatRoom: ChatRoom) {
        // 실제 서버로 메시지 삭제 전송 시뮬레이션
        // 로컬 삭제는 ViewModel에서 처리되었습니다.
    }
}

// 알림 확장
extension Notification.Name {
    static let newMessageReceived = Notification.Name("newMessageReceived")
}
