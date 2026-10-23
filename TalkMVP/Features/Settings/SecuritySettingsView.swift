import SwiftUI

struct SecuritySettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $appLockEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.purple)
                        Text(localizedText("app_lock"))
                    }
                }
                .accessibilityHint(localizedText("app_lock_hint"))
            }
        }
        .navigationTitle(localizedText("security"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func localizedText(_ key: String) -> String {
        switch key {
        case "security": return languageManager.localize(ko: "보안", en: "Security", ja: "セキュリティ", zh: "安全", es: "Seguridad")
        case "app_lock": return languageManager.localize(ko: "앱 잠금", en: "App Lock", ja: "アプリロック", zh: "应用锁定", es: "Bloqueo de aplicación")
        case "app_lock_hint": return languageManager.localize(ko: "앱을 열 때 Face ID/Touch ID 인증을 요구합니다", en: "Require Face ID/Touch ID to unlock the app", ja: "アプリを開く際にFace ID/Touch IDの認証が必要です", zh: "打开应用时需要Face ID/Touch ID验证", es: "Requiere Face ID/Touch ID para desbloquear la app")
        default: return key
        }
    }
}
