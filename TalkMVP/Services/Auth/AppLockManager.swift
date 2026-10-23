import SwiftUI
import Combine
import LocalAuthentication
import Foundation

/// What App Lock needs from the device: whether the owner can be checked at all, and the check.
nonisolated protocol DeviceOwnerAuthenticating: Sendable {
    func canAuthenticate() -> Bool
    func authenticate(reason: String, fallbackTitle: String) async throws
}

/// Face ID or Touch ID first, then the device passcode. The owner can always get in this way, so
/// the lock screen never needs a way around the lock.
nonisolated struct LocalDeviceOwnerAuthenticator: DeviceOwnerAuthenticating {
    private let policy = LAPolicy.deviceOwnerAuthentication

    func canAuthenticate() -> Bool {
        LAContext().canEvaluatePolicy(policy, error: nil)
    }

    func authenticate(reason: String, fallbackTitle: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = fallbackTitle
        _ = try await context.evaluatePolicy(policy, localizedReason: reason)
    }
}

@MainActor
@Observable
class AppLockManager {
    /// The setting SecuritySettingsView turns on and off.
    static let enabledKey = "appLockEnabled"

    var isLocked: Bool = false
    var errorMessage: String?

    private let authenticator: DeviceOwnerAuthenticating
    private let defaults: UserDefaults
    private var isAuthenticating = false

    init(authenticator: DeviceOwnerAuthenticating = LocalDeviceOwnerAuthenticator(), defaults: UserDefaults = .standard) {
        self.authenticator = authenticator
        self.defaults = defaults
    }

    private var isLockEnabled: Bool {
        defaults.bool(forKey: Self.enabledKey)
    }

    // 앱 시작 시 현재 설정을 반영하여 잠금 여부 결정
    func updateLockStateOnLaunch() {
        if isLockEnabled && !authenticator.canAuthenticate() {
            // No passcode on the device any more, so there is nothing to check the owner
            // against: turn the setting off rather than lock the owner out for good.
            defaults.set(false, forKey: Self.enabledKey)
            isLocked = false
        } else {
            isLocked = isLockEnabled
        }
    }

    // ScenePhase 변화에 따라 잠금 처리 (활성화될 때 잠금 요구)
    func handleScenePhase(_ phase: ScenePhase) {
        if isLockEnabled {
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

    // 인증 시도 (Face ID/Touch ID, 안 되면 기기 암호)
    func authenticate(reason: String? = nil) async {
        // The lock screen asks on appear and again on returning to the foreground; one prompt at a time.
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let currentLanguage: String = {
            if let saved = defaults.string(forKey: "selectedLanguage") { return saved }
            if let langs = defaults.array(forKey: "AppleLanguages") as? [String], let first = langs.first { return first }
            return "en"
        }()
        let reasonText: String
        let fallbackTitle: String
        let unavailable: String
        if currentLanguage.hasPrefix("ja") {
            reasonText = reason ?? "アプリのロックを解除するには認証が必要です。"
            fallbackTitle = "パスコードを使用"
            unavailable = "このデバイスでは認証を使用できません。"
        } else if currentLanguage.hasPrefix("zh") {
            reasonText = reason ?? "解锁应用需要进行身份验证。"
            fallbackTitle = "使用密码"
            unavailable = "此设备上无法使用身份验证。"
        } else if currentLanguage.hasPrefix("es") {
            reasonText = reason ?? "Se requiere autenticación para desbloquear la app."
            fallbackTitle = "Usar código"
            unavailable = "La autenticación no está disponible en este dispositivo."
        } else if currentLanguage.hasPrefix("ko") {
            reasonText = reason ?? "앱을 잠금 해제하려면 인증이 필요합니다."
            fallbackTitle = "암호 사용"
            unavailable = "이 기기에서는 인증을 사용할 수 없습니다."
        } else {
            reasonText = reason ?? "Authentication is required to unlock the app."
            fallbackTitle = "Use Passcode"
            unavailable = "Authentication is unavailable on this device."
        }

        guard authenticator.canAuthenticate() else {
            isLocked = true
            errorMessage = unavailable
            return
        }
        do {
            try await authenticator.authenticate(reason: reasonText, fallbackTitle: fallbackTitle)
            isLocked = false
            errorMessage = nil
        } catch {
            // Cancelling or failing leaves the app locked; the only way in is to try again.
            isLocked = true
            errorMessage = error.localizedDescription
        }
    }
}
