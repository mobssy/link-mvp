//
//  NotificationManager.swift
//  L!nkMVP
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
    @Published var pendingRequests: [UNNotificationRequest] = []

    private var notificationsEnabled: Bool { UserDefaults.standard.bool(forKey: "notificationsEnabled") }

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
            print("알림 권한 요청 실패: \(error)")
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
        content.title = "새 친구 요청"
        content.body = "\(friendName)님이 친구 요청을 보냈습니다"
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
                print("알림 스케줄링 실패: \(error)")
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
                print("메시지 알림 스케줄링 실패: \(error)")
            }
        }
    }

    // 강력한 메시지 알림 (노인분들용)
    func scheduleStrongMessageNotification(from friendName: String, message: String) {
        guard hasPermission else { return }
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "💝 \(friendName)님이 메시지를 보냈어요!"
        content.body = "📱 \(message)"

        // 더 큰 소리와 반복 알림을 위한 설정
        content.sound = UNNotificationSound(named: UNNotificationSoundName("strong_notification.wav"))
        content.badge = 1
        content.categoryIdentifier = "MESSAGE_CATEGORY"

        // 친근한 알림 텍스트
        if friendName.contains("손주") || friendName.contains("가족") {
            content.subtitle = "🥰 사랑하는 가족이 연락했어요!"
        } else {
            content.subtitle = "😊 소중한 사람이 메시지를 보냈어요!"
        }

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
                print("중요 메시지 알림 스케줄링 실패: \(error)")
            } else {
                print("💪 강력한 알림 설정 완료: \(friendName)")
            }
        }

        // 3초 후 추가 리마인더 알림
        scheduleReminderNotification(from: friendName, message: message)
    }

    // 리마인더 알림 (3초 후)
    private func scheduleReminderNotification(from friendName: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "🔔 메시지를 확인해주세요!"
        content.body = "\(friendName)님이 기다리고 있어요"
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
                print("리마인더 알림 실패: \(error)")
            }
        }
    }

    // 음성 알림 (TTS)
    func scheduleVoiceNotification(from friendName: String) {
        guard notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "📞 음성 알림"
        content.body = "\(friendName)님이 메시지를 보냈어요. 확인해주세요!"
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

// 알림 델리게이트
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    // 앱이 포어그라운드에 있을 때 알림 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // 알림을 탭했을 때
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String {
            switch type {
            case "friend_request":
                // 친구 요청 화면으로 이동
                NotificationCenter.default.post(name: .openFriendRequests, object: nil)
            case "message":
                // 채팅 화면으로 이동
                if let friendName = userInfo["friendName"] as? String {
                    NotificationCenter.default.post(name: .openChat, object: friendName)
                }
            default:
                break
            }
        }

        completionHandler()
    }
}

// 알림 관련 Notification.Name 확장
extension Notification.Name {
    static let openFriendRequests = Notification.Name("openFriendRequests")
    static let openChat = Notification.Name("openChat")
}
