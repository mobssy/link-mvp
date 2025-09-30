//
//  AuthView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData

struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var isSignUp = false
    @State private var username = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                VStack(spacing: 30) {
                // 로고 영역
                VStack(spacing: 16) {
                    Image(systemName: "message.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("TalkMVP")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // 폼 영역
                VStack(spacing: 20) {
                    if isSignUp {
                        signUpForm
                    } else {
                        signInForm
                    }
                    
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
                            Text(isSignUp ? "회원가입" : "로그인")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
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
                        Text(isSignUp ? "이미 계정이 있나요? 로그인" : "계정이 없나요? 회원가입")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea(.all, edges: .all)
        }
    }
    
    private var signInForm: some View {
        VStack(spacing: 16) {
            CustomTextField(text: $username, placeholder: "사용자명 또는 이메일", icon: "person.fill")
            CustomTextField(text: $password, placeholder: "비밀번호", icon: "lock.fill", isSecure: true)
        }
    }
    
    private var signUpForm: some View {
        VStack(spacing: 16) {
            CustomTextField(text: $username, placeholder: "사용자명", icon: "person.fill")
            CustomTextField(text: $displayName, placeholder: "표시 이름", icon: "person.crop.circle.fill")
            CustomTextField(text: $email, placeholder: "이메일", icon: "envelope.fill")
            CustomTextField(text: $password, placeholder: "비밀번호", icon: "lock.fill", isSecure: true)
            CustomTextField(text: $confirmPassword, placeholder: "비밀번호 확인", icon: "lock.fill", isSecure: true)
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
}

// 커스텀 텍스트 필드
struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var isSecure: Bool = false
    
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
}
