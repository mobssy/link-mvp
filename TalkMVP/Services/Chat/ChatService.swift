//
//  ChatService.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import SwiftData
import UserNotifications
import os

private let chatServiceLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatService")

@MainActor
@Observable
class ChatService: ChatServiceProtocol {
    private var hasStarted = false
    private var hasRequestedNotificationAuth = false
    var modelContext: ModelContext {
        // There is no server: once the view hands over its context, the service only asks for
        // notification permission.
        didSet {
            guard !hasStarted else { return }
            hasStarted = true
            ensureNotificationSetup()
        }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Starts when the view attaches its own modelContext.
    }

    private func ensureNotificationSetup() {
        guard !hasRequestedNotificationAuth else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        center.delegate = LocalNotificationDelegate.shared
        hasRequestedNotificationAuth = true
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

