import SwiftUI
import LocalAuthentication

extension SettingsView {
    @ViewBuilder
    var securitySection: some View {
        SettingsSectionCard(title: localizedText("security")) {
            AppLockToggleRow(localizedText: localizedText)
        }
    }
}

private struct AppLockToggleRow: View {
    @EnvironmentObject private var appLock: AppLockManager
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    let localizedText: (String) -> String

    private func languageManagerIsKorean() -> Bool {
        if let saved = UserDefaults.standard.string(forKey: "selectedLanguage") { return saved.hasPrefix("ko") }
        if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String], let first = langs.first { return first.hasPrefix("ko") }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "lock.square")
                    .foregroundColor(.blue)
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 24, height: 24)
                Text(localizedText("app_lock_title"))
                Spacer()
                Toggle("", isOn: $appLockEnabled)
                    .labelsHidden()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(localizedText("app_lock_title"))

            if appLockEnabled {
                Text(localizedText("app_lock_desc"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
            }
        }
        .onChange(of: appLockEnabled) { oldValue, newValue in
            if newValue {
                // Pre-check: Only allow enabling if device can authenticate
                if appLock.canAuthenticate() {
                    appLock.isLocked = true
                    appLock.authenticate(reason: localizedText("unlock_reason"))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if appLock.isLocked {
                            // Authentication failed or cancelled -> revert toggle
                            appLockEnabled = false
                        }
                    }
                } else {
                    // Revert and optionally provide feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    appLockEnabled = false
                    appLock.errorMessage = languageManagerIsKorean() ? "이 기기에서는 인증을 사용할 수 없습니다." : "Authentication is unavailable on this device."
                }
            } else {
                appLock.isLocked = false
            }
        }
    }
}
