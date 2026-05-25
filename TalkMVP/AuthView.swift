//
//  AuthView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData
import UIKit

struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSignUp = false
    @State private var username = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var appIcon: UIImage?

    private var appTitle: AttributedString {
        var str = AttributedString("L!NK")
        if let range = str.range(of: "!") {
            str[range].foregroundColor = Color.appPrimary
        }
        return str
    }

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                VStack(spacing: 30) {
                // 로고 영역
                VStack(spacing: 16) {
                    if let icon = appIcon {
                        Image(uiImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else {
                        Image(systemName: "message.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.appPrimary)
                    }

                    Text(appTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.top, 50)

                Spacer()

                // 폼 영역 (다크 모드에서 다크 그레이 래퍼 적용)
                Group {
                    if colorScheme == .dark {
                        formContent
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(UIColor.secondarySystemBackground))
                            )
                            .padding(.horizontal, 16)
                    } else {
                        formContent
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .tint(.appPrimary)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea(.all, edges: .all)
            .onAppear {
                if appIcon == nil {
                    appIcon = appIconUIImage()
                }
            }
        }
    }

    private var authForm: some View {
        VStack(spacing: 16) {
            CustomTextField(
                text: $username,
                placeholder: localizedText(isSignUp ? "username" : "username_or_email"),
                icon: "person.fill"
            )

            if isSignUp {
                CustomTextField(
                    text: $displayName,
                    placeholder: localizedText("display_name"),
                    icon: "person.crop.circle.fill"
                )
                CustomTextField(
                    text: $email,
                    placeholder: localizedText("email"),
                    icon: "envelope.fill",
                    keyboardType: .emailAddress
                )
            }

            CustomTextField(
                text: $password,
                placeholder: localizedText("password"),
                icon: "lock.fill",
                isSecure: true
            )

            if isSignUp {
                CustomTextField(
                    text: $confirmPassword,
                    placeholder: localizedText("confirm_password"),
                    icon: "lock.fill",
                    isSecure: true
                )
            }
        }
    }

    private var formContent: some View {
        VStack(spacing: 20) {
            authForm
                .frame(maxWidth: 360)

            // 오류 메시지
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            // 로그인/회원가입 버튼
            Button(action: handleAuth) {
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(localizedText(isSignUp ? "signup" : "signin"))
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: 360)
            .frame(height: 50)
            .background(Color.appPrimary)
            .foregroundColor(.white)
            .cornerRadius(25)
            .disabled(authManager.isLoading || !isFormValid)

            // SSO 버튼 (로그인 화면에서만)
            if !isSignUp {
                SSOSignInView()
            }

            // 전환 버튼
            Button(action: {
                withAnimation {
                    isSignUp.toggle()
                    clearForm()
                }
            }) {
                Text(localizedText(isSignUp ? "have_account" : "no_account"))
                    .foregroundColor(.appPrimary)
            }
        }
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !username.isEmpty && !displayName.isEmpty && !email.isEmpty &&
                   !password.isEmpty && password == confirmPassword && password.count >= 6
        } else {
            return !username.isEmpty && !password.isEmpty
        }
    }

    private func handleAuth() {
        Task {
            if isSignUp {
                await authManager.signUp(username: username, displayName: displayName, email: email, password: password)
            } else {
                await authManager.signIn(username: username, password: password)
            }
        }
    }

    private func clearForm() {
        username = ""
        displayName = ""
        email = ""
        password = ""
        confirmPassword = ""
        authManager.errorMessage = nil
    }

    private func localizedText(_ key: String) -> String {
        switch key {
        case "signin":
            return languageManager.localize(ko: "로그인", en: "Sign In", ja: "ログイン", zh: "登录", es: "Iniciar sesión")
        case "signup":
            return languageManager.localize(ko: "회원가입", en: "Sign Up", ja: "新規登録", zh: "注册", es: "Registrarse")
        case "have_account":
            return languageManager.localize(ko: "이미 계정이 있나요? 로그인", en: "Already have an account? Sign In", ja: "すでにアカウントをお持ちですか？ログイン", zh: "已有账号？登录", es: "¿Ya tienes cuenta? Inicia sesión")
        case "no_account":
            return languageManager.localize(ko: "계정이 없나요? 회원가입", en: "Don't have an account? Sign Up", ja: "アカウントがありませんか？新規登録", zh: "没有账号？注册", es: "¿No tienes cuenta? Regístrate")
        case "username":
            return languageManager.localize(ko: "사용자명", en: "Username", ja: "ユーザー名", zh: "用户名", es: "Nombre de usuario")
        case "username_or_email":
            return languageManager.localize(ko: "사용자명 또는 이메일", en: "Username or Email", ja: "ユーザー名またはメール", zh: "用户名或邮箱", es: "Usuario o correo")
        case "display_name":
            return languageManager.localize(ko: "표시 이름", en: "Display Name", ja: "表示名", zh: "显示名称", es: "Nombre visible")
        case "email":
            return languageManager.localize(ko: "이메일", en: "Email", ja: "メール", zh: "邮箱", es: "Correo")
        case "password":
            return languageManager.localize(ko: "비밀번호", en: "Password", ja: "パスワード", zh: "密码", es: "Contraseña")
        case "confirm_password":
            return languageManager.localize(ko: "비밀번호 확인", en: "Confirm Password", ja: "パスワード確認", zh: "确认密码", es: "Confirmar contraseña")
        default: return key
        }
    }

    private func appIconUIImage() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let iconName = files.last,
           let image = UIImage(named: iconName) {
            return image
        }
        return nil
    }
}

// 커스텀 텍스트 필드
struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(keyboardType)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    if let container = try? ModelContainer(for: User.self) {
        AuthView()
            .environmentObject(AuthManager(modelContext: ModelContext(container)))
            .environmentObject(LanguageManager())
    } else {
        Text("Preview unavailable")
    }
}
