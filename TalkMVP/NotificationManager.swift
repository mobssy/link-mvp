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

    // 메시지 알림
    func scheduleMessageNotification(from friendName: String, message: String) {
        guard hasPermission else { return }
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = friendName
        content.body = message
        content.sound = .default
        content.badge = 1

        content.userInfo = [
            "type": "message",
            "friendName": friendName
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "message_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [NotificationManager] Message notification failed: \(error)")
            }
        }
    }

    // 강력한 메시지 알림 (노인분들용)
    func scheduleStrongMessageNotification(from friendName: String, message: String) {
        guard hasPermission else { return }
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = loc(
            ko: "💝 \(friendName)님이 메시지를 보냈어요!",
            en: "💝 \(friendName) sent you a message!",
            ja: "💝 \(friendName)さんからメッセージが届きました！",
            zh: "💝 \(friendName)给您发来消息！",
            es: "💝 ¡\(friendName) te envió un mensaje!"
        )
        content.body = "📱 \(message)"

        content.sound = UNNotificationSound(named: UNNotificationSoundName("strong_notification.wav"))
        content.badge = 1
        content.categoryIdentifier = "MESSAGE_CATEGORY"

        content.subtitle = loc(
            ko: "😊 소중한 사람이 메시지를 보냈어요!",
            en: "😊 Someone special sent you a message!",
            ja: "😊 大切な方からメッセージです！",
            zh: "😊 重要的人给您发来消息！",
            es: "😊 ¡Alguien especial te escribió!"
        )

        content.userInfo = [
            "type": "message",
            "friendName": friendName,
            "message": message,
            "isImportant": true
        ]

        // 즉시 알림
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "important_message_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [NotificationManager] Strong notification failed: \(error)")
            }
        }

        // 3초 후 추가 리마인더 알림
        scheduleReminderNotification(from: friendName, message: message)
    }

    // 리마인더 알림 (3초 후)
    private func scheduleReminderNotification(from friendName: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = loc(ko: "🔔 메시지를 확인해주세요!", en: "🔔 Please check your messages!", ja: "🔔 メッセージを確認してください！", zh: "🔔 请查看您的消息！", es: "🔔 ¡Revisa tus mensajes!")
        content.body = loc(ko: "\(friendName)님이 기다리고 있어요", en: "\(friendName) is waiting for you", ja: "\(friendName)さんが待っています", zh: "\(friendName)在等您", es: "\(friendName) te está esperando")
        content.sound = .defaultRingtone
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [NotificationManager] Reminder notification failed: \(error)")
            }
        }
    }

    // 음성 알림 (TTS)
    func scheduleVoiceNotification(from friendName: String) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = loc(ko: "📞 음성 알림", en: "📞 Voice Alert", ja: "📞 音声通知", zh: "📞 语音提醒", es: "📞 Alerta de voz")
        content.body = loc(ko: "\(friendName)님이 메시지를 보냈어요. 확인해주세요!", en: "\(friendName) sent you a message. Please check it!", ja: "\(friendName)さんからメッセージが届きました。確認してください！", zh: "\(friendName)给您发来消息，请查看！", es: "¡\(friendName) te envió un mensaje. Por favor revísalo!")
        content.sound = .default
        content.userInfo = ["shouldSpeak": true, "friendName": friendName]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "voice_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
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

    // 특정 타입 알림 제거
    func clearNotifications(ofType type: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.filter { request in
                if let userInfo = request.content.userInfo as? [String: Any],
                   let notificationType = userInfo["type"] as? String {
                    return notificationType == type
                }
                return false
            }.map { $0.identifier }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
}

// 알림 관련 Notification.Name 확장
extension Notification.Name {
    static let openFriendRequests = Notification.Name("openFriendRequests")
    static let openChat = Notification.Name("openChat")
}
