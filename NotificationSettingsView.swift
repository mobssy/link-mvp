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
        switch key {
        case "notifications": return languageManager.localize(ko: "알림", en: "Notifications", ja: "通知", zh: "通知", es: "Notificaciones")
        case "push_permission": return languageManager.localize(ko: "푸시 권한", en: "Push Permission", ja: "プッシュ権限", zh: "推送权限", es: "Permiso de notificaciones")
        case "granted": return languageManager.localize(ko: "허용됨", en: "Granted", ja: "許可済み", zh: "已允许", es: "Permitido")
        case "denied": return languageManager.localize(ko: "거부됨", en: "Denied", ja: "拒否済み", zh: "已拒绝", es: "Denegado")
        case "request_permission": return languageManager.localize(ko: "권한 요청", en: "Request Permission", ja: "権限をリクエスト", zh: "请求权限", es: "Solicitar permiso")
        default: return key
        }
    }

    private func notificationFooterText() -> String {
        return languageManager.localize(
            ko: "알림 권한은 기기 설정에서 변경할 수 있습니다",
            en: "You can change notification permissions in the device Settings",
            ja: "通知権限はデバイスの設定から変更できます",
            zh: "您可以在设备设置中更改通知权限",
            es: "Puedes cambiar los permisos de notificación en la configuración del dispositivo"
        )
    }
}
