//
//  SSOSignInView.swift
//  TalkMVP
//

import SwiftUI
import AuthenticationServices

struct SSOSignInView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.colorScheme) private var colorScheme

    private var appleButtonStyle: SignInWithAppleButton.Style {
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
        SignInWithAppleButton(
            .signIn,
            onRequest: { $0.requestedScopes = [.fullName, .email] },
            onCompletion: handleAppleResult
        )
        .signInWithAppleButtonStyle(appleButtonStyle)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
