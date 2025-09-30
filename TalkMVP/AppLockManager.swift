import SwiftUI
import Combine
import LocalAuthentication
import Foundation

@MainActor
class AppLockManager: ObservableObject {
    
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @Published var isLocked: Bool = false
    @Published var errorMessage: String?

    // 앱 시작 시 현재 설정을 반영하여 잠금 여부 결정
    func updateLockStateOnLaunch() {
        isLocked = appLockEnabled
    }

    // ScenePhase 변화에 따라 잠금 처리 (활성화될 때 잠금 요구)
    func handleScenePhase(_ phase: ScenePhase) {
        if appLockEnabled {
            switch phase {
            case .inactive, .background:
                // App is leaving the foreground: require authentication next time
                isLocked = true
            case .active:
                // Do not force-lock on becoming active; AppLockView will prompt if `isLocked` is already true
                break
            @unknown default:
                break
            }
        } else {
            isLocked = false
        }
    }

    // 인증 시도 (Face ID/Touch ID 또는 기기 암호)
    func authenticate(reason: String = "앱을 잠금 해제하려면 인증이 필요합니다.") {
        let context = LAContext()
        context.localizedFallbackTitle = "암호 사용"
        var authError: NSError?

        // Prefer biometrics only if available AND Face ID usage description key exists (avoids crash on devices with Face ID when key is missing)
        let hasFaceIDUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") != nil
        let biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)
        let policy: LAPolicy = (biometricsAvailable && hasFaceIDUsageDescription) ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication

        if context.canEvaluatePolicy(policy, error: &authError) {
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                Task { @MainActor in
                    if success {
                        self.isLocked = false
                        self.errorMessage = nil
                    } else {
                        self.isLocked = true
                        self.errorMessage = (error as NSError?)?.localizedDescription ?? "인증에 실패했습니다."
                    }
                }
            }
        } else {
            // 어떤 정책도 사용할 수 없는 경우
            self.isLocked = true
            self.errorMessage = authError?.localizedDescription ?? "이 기기에서는 인증을 사용할 수 없습니다."
        }
    }
}

