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
import os

private let notificationLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "NotificationManager")

/// The user's "notifications on" switch in Settings.
///
/// Settings shows it as on before the user has ever touched it, but nothing writes that
/// default to UserDefaults, so `bool(forKey:)` read a fresh install as "off" and every
/// notification was suppressed until the switch was flipped off and on again.
nonisolated enum NotificationPreferences {
    static let enabledKey = "notificationsEnabled"

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }
}

/// The parts of `UNUserNotificationCenter` the app uses, so they can be faked in tests.
protocol NotificationScheduling {
    func isAuthorizedToNotify() async -> Bool
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func setBadgeCount(_ newBadgeCount: Int) async throws
    func removeAllPendingNotificationRequests()
    func removeAllDeliveredNotifications()
}

extension UNUserNotificationCenter: NotificationScheduling {
    func isAuthorizedToNotify() async -> Bool {
        switch await notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }
}

@MainActor
class NotificationManager {
    private let center: NotificationScheduling
    private let defaults: UserDefaults

    private var notificationsEnabled: Bool { NotificationPreferences.isEnabled(in: defaults) }

    private func loc(ko: String, en: String, ja: String, zh: String, es: String) -> String {
        let lang = LanguageManager.currentLanguageCode
        if lang.hasPrefix("ko") { return ko }
        if lang.hasPrefix("ja") { return ja }
        if lang.hasPrefix("zh") { return zh }
        if lang.hasPrefix("es") { return es }
        return en
    }

    init(center: NotificationScheduling = UNUserNotificationCenter.current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
    }

    func requestPermission() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            notificationLogger.error("Permission request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 친구 요청 알림. Permission is checked when the notification is scheduled rather than
    /// cached at init: the cached flag was filled in asynchronously, so a manager created
    /// right before scheduling always still saw "no permission" and dropped the notification.
    func scheduleFriendRequestNotification(from friendName: String, email: String) async {
        guard notificationsEnabled, await center.isAuthorizedToNotify() else { return }

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

        do {
            try await center.add(request)
        } catch {
            notificationLogger.error("Friend request notification failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // 배지 숫자 업데이트
    @discardableResult
    func updateBadgeCount(_ count: Int) -> Task<Void, Never> {
        let effective = notificationsEnabled ? count : 0
        return Task {
            try? await center.setBadgeCount(effective)
        }
    }

    // 모든 알림 제거
    func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        updateBadgeCount(0)
    }
}
