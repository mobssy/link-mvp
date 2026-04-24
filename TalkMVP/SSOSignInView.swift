//
//  SSOSignInView.swift
//  TalkMVP
//

import SwiftUI
import AuthenticationServices
import UIKit

struct SSOSignInView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.colorScheme) private var colorScheme

    private var appleButtonStyle: ASAuthorizationAppleIDButton.Style {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        VStack(spacing: 12) {
            orDivider
            appleButton
        }
    }

    // MARK: - Subviews

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(UIColor.separator))
            Text(languageManager.localize(ko: "또는", en: "or", ja: "または", zh: "或者", es: "o"))
                .font(.footnote)
                .foregroundColor(.secondary)
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(UIColor.separator))
        }
    }

    private var appleButton: some View {
        LocalizedAppleSignInButton(
            style: appleButtonStyle,
            onCompletion: handleAppleResult
        )
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        // Force recreation of UIKit button when language changes so it reads updated "AppleLanguages"
        .id(languageManager.currentLanguage)
    }

    // MARK: - Handlers

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

// MARK: - UIViewRepresentable wrapper for locale-aware Apple button

private struct LocalizedAppleSignInButton: UIViewRepresentable {
    let style: ASAuthorizationAppleIDButton.Style
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: style)
        button.cornerRadius = 12
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}

// MARK: - Coordinator

extension LocalizedAppleSignInButton {
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onCompletion: (Result<ASAuthorization, Error>) -> Void

        init(onCompletion: @escaping (Result<ASAuthorization, Error>) -> Void) {
            self.onCompletion = onCompletion
        }

        @objc func handleTap() {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let activeScene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first
            guard let scene = activeScene else { preconditionFailure("No window scene available") }
            return scene.windows.first(where: { $0.isKeyWindow }) ?? UIWindow(windowScene: scene)
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            onCompletion(.success(authorization))
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            onCompletion(.failure(error))
        }
    }
}
