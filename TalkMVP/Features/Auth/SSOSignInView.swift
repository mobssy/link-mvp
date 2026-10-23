//
//  SSOSignInView.swift
//  TalkMVP
//

import SwiftUI
import AuthenticationServices

struct SSOSignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            orDivider
            appleButton
            googleButton
        }
    }

    // MARK: - Subviews

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(UIColor.separator))
            Text(languageManager.localize(ko: "또는", en: "or", ja: "または", zh: "或者", es: "o"))
                .font(.footnote)
                .foregroundStyle(Color.secondary)
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(UIColor.separator))
        }
        // As wide as the fields and buttons around it, not the whole screen on a wide one.
        .frame(maxWidth: 360)
    }

    private var appleButton: some View {
        let isDark = colorScheme == .dark
        let background: Color = isDark ? .white : .black
        let foreground: Color = isDark ? .black : .white
        let label = languageManager.localize(
            ko: "Apple로 로그인",
            en: "Sign in with Apple",
            ja: "Appleでサインイン",
            zhHans: "通过 Apple 登录",
            zhHant: "使用 Apple 登入",
            es: "Iniciar sesión con Apple"
        )

        return Button(action: triggerAppleSignIn) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 17, weight: .medium))
                Text(label)
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: 360)
            .frame(height: 50)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        }
    }

    private var googleButton: some View {
        let isDark = colorScheme == .dark
        let background: Color = isDark ? Color(UIColor.secondarySystemBackground) : .white
        let label = languageManager.localize(
            ko: "Google로 로그인",
            en: "Sign in with Google",
            ja: "Googleでサインイン",
            zh: "通过 Google 登录",
            es: "Iniciar sesión con Google"
        )

        return Button(action: triggerGoogleSignIn) {
            HStack(spacing: 8) {
                Image("google-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(label)
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: 360)
            .frame(height: 50)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(Color(UIColor.separator), lineWidth: 1)
            )
        }
    }

    // MARK: - Auth

    private func triggerAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = AppleSignInCoordinator.shared
        controller.presentationContextProvider = AppleSignInCoordinator.shared
        AppleSignInCoordinator.shared.onCompletion = handleAppleResult
        controller.performRequests()
    }

    private func triggerGoogleSignIn() {
        Task {
            await authManager.signInWithGoogle()
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            Task {
                await authManager.signInWithApple(
                    userId: credential.user,
                    email: credential.email,
                    fullName: credential.fullName
                )
            }
        case .failure(let error):
            guard (error as? ASAuthorizationError)?.code != .canceled else { return }
            authManager.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Coordinator (singleton to avoid deallocation during auth flow)

private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    static let shared = AppleSignInCoordinator()
    var onCompletion: ((Result<ASAuthorization, Error>) -> Void)?

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let scene = active else { preconditionFailure("No window scene") }
        return scene.windows.first(where: { $0.isKeyWindow }) ?? UIWindow(windowScene: scene)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion?(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        onCompletion?(.failure(error))
    }
}
