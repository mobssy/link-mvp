import SwiftUI

struct AppLockView: View {
    @EnvironmentObject var appLock: AppLockManager
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.appPrimary)

                Text(localizedText("unlock_required"))
                    .font(.title2)
                    .fontWeight(.semibold)

                if let error = appLock.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: {
                    appLock.authenticate()
                }) {
                    HStack {
                        Image(systemName: "faceid")
                        Text(localizedText("try_authentication"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                if appLock.errorMessage != nil {
                    Button(role: .destructive) {
                        appLock.disableLock()
                    } label: {
                        Text(languageManager.currentLanguage == .korean ? "앱 잠금 비활성화" : "Disable App Lock")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && appLock.isLocked {
                // 포그라운드 복귀 시 자동 인증 시도
                appLock.authenticate(reason: localizedText("unlock_reason"))
            }
        }
        .onAppear {
            if appLock.isLocked {
                appLock.authenticate(reason: localizedText("unlock_reason"))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localizedText("app_lock_screen"))
        .accessibilityHint(localizedText("auth_hint"))
    }
    
    private func localizedText(_ key: String) -> String {
        switch key {
        case "unlock_required":
            return languageManager.currentLanguage == .korean ? "잠금 해제 필요" : "Unlock Required"
        case "try_authentication":
            return languageManager.currentLanguage == .korean ? "인증 시도" : "Authenticate"
        case "app_lock_screen":
            return languageManager.currentLanguage == .korean ? "앱 잠금 화면" : "App Lock Screen"
        case "auth_hint":
            return languageManager.currentLanguage == .korean ? "Face ID 또는 Touch ID로 인증하세요" : "Authenticate with Face ID or Touch ID"
        case "unlock_reason":
            return languageManager.currentLanguage == .korean ? "앱을 잠금 해제하려면 인증이 필요합니다." : "Authentication is required to unlock the app."
        default:
            return key
        }
    }
}

#Preview {
    AppLockView()
        .environmentObject(AppLockManager())
        .environmentObject(LanguageManager())
}
