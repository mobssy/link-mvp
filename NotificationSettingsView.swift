import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var notificationManager = NotificationManager()

    var body: some View {
        Form {
            Section(footer: Text(notificationFooterText())) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(.orange)
                    Text(localizedText("push_permission"))
                    Spacer()
                    Circle()
                        .fill(notificationManager.hasPermission ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(notificationManager.hasPermission ? localizedText("granted") : localizedText("denied"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button {
                    Task { await notificationManager.requestPermission() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap")
                            .foregroundColor(.blue)
                        Text(localizedText("request_permission"))
                    }
                }
            }
        }
        .navigationTitle(localizedText("notifications"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await notificationManager.checkPermission() }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.isKorean
        switch key {
        case "notifications": return isKorean ? "알림" : "Notifications"
        case "push_permission": return isKorean ? "푸시 권한" : "Push Permission"
        case "granted": return isKorean ? "허용됨" : "Granted"
        case "denied": return isKorean ? "거부됨" : "Denied"
        case "request_permission": return isKorean ? "권한 요청" : "Request Permission"
        default: return key
        }
    }

    private func notificationFooterText() -> String {
        return languageManager.isKorean ?
            "알림 권한은 기기 설정에서 변경할 수 있습니다" :
            "You can change notification permissions in the device Settings"
    }
}
