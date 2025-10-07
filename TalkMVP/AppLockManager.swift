import SwiftUI
import Combine
import LocalAuthentication
import Foundation

@MainActor
class AppLockManager: ObservableObject {

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("appLockMethod") private var appLockMethod: String = "biometrics"
    @Published var isLocked: Bool = false
    @Published var errorMessage: String?

    // Check if device can perform authentication based on current settings
    func canAuthenticate() -> Bool {
        let context = LAContext()
        var error: NSError?

        // Determine policy similar to authenticate()
        let hasFaceIDUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") != nil
        let preferredMethod = appLockMethod
        let biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        let policy: LAPolicy
        if preferredMethod == "biometrics" {
            if biometricsAvailable && hasFaceIDUsageDescription {
                policy = .deviceOwnerAuthenticationWithBiometrics
            } else {
                policy = .deviceOwnerAuthentication
            }
        } else {
            policy = .deviceOwnerAuthentication
        }

        return context.canEvaluatePolicy(policy, error: &error)
    }

    // Emergency disable to avoid being locked out
    func disableLock() {
        appLockEnabled = false
        isLocked = false
        errorMessage = nil
    }

    // 앱 시작 시 현재 설정을 반영하여 잠금 여부 결정
    func updateLockStateOnLaunch() {
        if appLockEnabled && !canAuthenticate() {
            // Fallback: disable to prevent permanent lockout on unsupported devices
            disableLock()
        } else {
            isLocked = appLockEnabled
        }
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
    func authenticate(reason: String? = nil) {
        let isKorean: Bool = {
            if let saved = UserDefaults.standard.string(forKey: "selectedLanguage") { return saved.hasPrefix("ko") }
            if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String], let first = langs.first { return first.hasPrefix("ko") }
            return false
        }()
        let reasonText = reason ?? (isKorean ? "앱을 잠금 해제하려면 인증이 필요합니다." : "Authentication is required to unlock the app.")
        let fallbackTitle = isKorean ? "암호 사용" : "Use Passcode"
        let authFailed = isKorean ? "인증에 실패했습니다." : "Authentication failed."
        let unavailable = isKorean ? "이 기기에서는 인증을 사용할 수 없습니다." : "Authentication is unavailable on this device."

        let context = LAContext()
        context.localizedFallbackTitle = fallbackTitle
        var authError: NSError?

        // Determine preferred authentication policy based on user setting
        let preferredMethod = appLockMethod // "biometrics" or "passcode"
        let hasFaceIDUsageDescription = Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") != nil
        let biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError)

        let policy: LAPolicy
        if preferredMethod == "biometrics" {
            if biometricsAvailable && hasFaceIDUsageDescription {
                policy = .deviceOwnerAuthenticationWithBiometrics
            } else {
                // Fallback to device passcode if biometrics not available/allowed
                policy = .deviceOwnerAuthentication
            }
        } else { // "passcode"
            policy = .deviceOwnerAuthentication
        }

        if context.canEvaluatePolicy(policy, error: &authError) {
            context.evaluatePolicy(policy, localizedReason: reasonText) { success, error in
                Task { @MainActor in
                    if success {
                        self.isLocked = false
                        self.errorMessage = nil
                    } else {
                        self.isLocked = true
                        self.errorMessage = (error as NSError?)?.localizedDescription ?? authFailed
                    }
                }
            }
        } else {
            // 어떤 정책도 사용할 수 없는 경우
            self.isLocked = true
            self.errorMessage = authError?.localizedDescription ?? unavailable
        }
    }
}
