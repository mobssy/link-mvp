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
    @State private var isSignUp = false
    @State private var username = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var appIcon: UIImage? = nil
    
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
                    
                    Text("TalkMVP")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // 폼 영역
                VStack(spacing: 20) {
                    authForm
                    
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.appPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(25)
                    .disabled(authManager.isLoading || !isFormValid)
                    
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
                .padding(.horizontal, 32)
                
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
        let isKorean = (languageManager.currentLanguage == .korean)
        
        switch key {
        case "signin": return isKorean ? "로그인" : "Sign In"
        case "signup": return isKorean ? "회원가입" : "Sign Up"
        case "have_account": return isKorean ? "이미 계정이 있나요? 로그인" : "Already have an account? Sign In"
        case "no_account": return isKorean ? "계정이 없나요? 회원가입" : "Don't have an account? Sign Up"
        case "username": return isKorean ? "사용자명" : "Username"
        case "username_or_email": return isKorean ? "사용자명 또는 이메일" : "Username or Email"
        case "display_name": return isKorean ? "표시 이름" : "Display Name"
        case "email": return isKorean ? "이메일" : "Email"
        case "password": return isKorean ? "비밀번호" : "Password"
        case "confirm_password": return isKorean ? "비밀번호 확인" : "Confirm Password"
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
    let container = try! ModelContainer(for: User.self)
    let context = ModelContext(container)
    let auth = AuthManager(modelContext: context)
    return AuthView()
        .environmentObject(auth)
        .environmentObject(LanguageManager())
}
