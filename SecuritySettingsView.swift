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
        let isKorean = (languageManager.currentLanguage == .korean)
        switch key {
        case "security": return isKorean ? "보안" : "Security"
        case "app_lock": return isKorean ? "앱 잠금" : "App Lock"
        case "app_lock_hint": return isKorean ? "앱을 열 때 Face ID/Touch ID 인증을 요구합니다" : "Require Face ID/Touch ID to unlock the app"
        default: return key
        }
    }
}
