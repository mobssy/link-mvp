import SwiftUI

struct AppLockSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var appLock: AppLockManager
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("appLockMethod") private var appLockMethod: String = "biometrics" // "biometrics", "passcode"
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { appLockEnabled },
                    set: { newValue in
                        if newValue {
                            appLock.authenticate(reason: localized("unlock_reason"))
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                // Wait a short moment for auth to complete and update isLocked
                                appLockEnabled = !appLock.isLocked
                            }
                        } else {
                            appLock.isLocked = false
                            appLockEnabled = false
                        }
                    }
                )) {
                    Text(localized("app_lock_title"))
                }
            }
            
            Section {
                Picker("", selection: $appLockMethod) {
                    Text(localized("biometrics")).tag("biometrics")
                    Text(localized("passcode")).tag("passcode")
                }
                .pickerStyle(.segmented)
                .disabled(!appLockEnabled)
            }
            
            Section {
                Button(action: {
                    appLock.authenticate(reason: localized("unlock_reason"))
                }) {
                    Text(localized("test_auth"))
                }
                .disabled(!appLockEnabled)
            }
        }
        .navigationTitle(localized("security"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func localized(_ key: String) -> String {
        switch key {
        case "security":
            return languageManager.currentLanguage == .korean ? "보안" : "Security"
        case "app_lock_title":
            return languageManager.currentLanguage == .korean ? "앱 잠금 (Face ID)" : "App Lock (Face ID)"
        case "unlock_reason":
            return languageManager.currentLanguage == .korean ? "앱 잠금을 해제합니다." : "Unlock the app lock."
        case "biometrics":
            return languageManager.currentLanguage == .korean ? "생체 인식" : "Biometrics"
        case "passcode":
            return languageManager.currentLanguage == .korean ? "암호" : "Passcode"
        case "test_auth":
            return languageManager.currentLanguage == .korean ? "인증 테스트" : "Test Authentication"
        default:
            return key
        }
    }
}

#Preview {
    NavigationView {
        AppLockSettingsView()
    }
    .environmentObject(AppLockManager())
    .environmentObject(LanguageManager())
}
