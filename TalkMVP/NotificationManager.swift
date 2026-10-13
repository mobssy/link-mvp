//
//  NotificationManager.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

@MainActor
class NotificationManager: ObservableObject {
    @Published var hasPermission = false

    private var notificationsEnabled: Bool { UserDefaults.standard.bool(forKey: "notificationsEnabled") }

    private func loc(ko: String, en: String, ja: String, zh: String, es: String) -> String {
        let lang = LanguageManager.currentLanguageCode
        if lang.hasPrefix("ko") { return ko }
        if lang.hasPrefix("ja") { return ja }
        if lang.hasPrefix("zh") { return zh }
        if lang.hasPrefix("es") { return es }
        return en
    }

    init() {
        Task {
            await checkPermission()
        }
    }

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            hasPermission = granted
        } catch {
            print("❌ [NotificationManager] Permission request failed: \(error)")
        }
    }

    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        hasPermission = settings.authorizationStatus == .authorized
    }

    // 친구 요청 알림
    func scheduleFriendRequestNotification(from friendName: String, email: String) {
        guard hasPermission else { return }
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = loc(ko: "새 친구 요청", en: "New Friend Request", ja: "新しい友達リクエスト", zh: "新的好友请求", es: "Nueva solicitud de amistad")
        content.body = loc(ko: "\(friendName)님이 친구 요청을 보냈습니다", en: "\(friendName) sent you a friend request", ja: "\(friendName)さんから友達リクエストが届きました", zh: "\(friendName)发送了好友请求", es: "\(friendName) te envió una solicitud de amistad")
        content.sound = .default
        content.badge = 1

        // 사용자 정보를 userInfo에 저장
        content.userInfo = [
            "type": "friend_request",
            "friendName": friendName,
            "friendEmail": email
        ]

        // 즉시 알림
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "friend_request_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [NotificationManager] Friend request notification failed: \(error)")
            }
        }
    }

    // 배지 숫자 업데이트
    func updateBadgeCount(_ count: Int) {
        Task {
            let effective = notificationsEnabled ? count : 0
            try? await UNUserNotificationCenter.current().setBadgeCount(effective)
        }
    }

    // 모든 알림 제거
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        updateBadgeCount(0)
    }
}
