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
                appLock.isLocked = true
                appLock.authenticate(reason: localizedText("unlock_reason"))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if appLock.isLocked {
                        // Authentication failed or cancelled -> revert toggle
                        appLockEnabled = false
                    }
                }
            } else {
                appLock.isLocked = false
            }
        }
    }
}

