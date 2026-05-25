//
//  AuthManager.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import SwiftData
import Combine
import UserNotifications
import os

@ModelActor
private actor AuthStoreActor {
    func hasCurrentUser() throws -> Bool {
        var descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.isCurrentUser == true
            }
        )
        descriptor.fetchLimit = 1
        let users = try modelContext.fetch(descriptor)
        return users.first != nil
    }
}

private let authLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "AuthManager")

@MainActor
class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    var modelContext: ModelContext

    // MARK: - Lightweight localization for non-View layer
    private func loc(_ key: String, _ param: String = "") -> String {
        let lang = LanguageManager.currentLanguageCode
        let isKo = lang.hasPrefix("ko")
        let isJa = lang.hasPrefix("ja")
        let isZh = lang.hasPrefix("zh")
        let isEs = lang.hasPrefix("es")

        switch key {
        case "signup_exists":
            if isKo { return "이미 존재하는 사용자명 또는 이메일입니다." }
            if isJa { return "既に存在するユーザー名またはメールアドレスです。" }
            if isZh { return "用户名或电子邮件已存在。" }
            if isEs { return "El nombre de usuario o correo electrónico ya existe." }
            return "Username or email already exists."
        case "signup_error_prefix":
            if isKo { return "회원가입 중 오류가 발생했습니다: " }
            if isJa { return "会員登録中にエラーが発生しました: " }
            if isZh { return "注册时发生错误: " }
            if isEs { return "Se produjo un error durante el registro: " }
            return "An error occurred during sign up: "
        case "signin_not_found":
            if isKo { return "존재하지 않는 사용자입니다." }
            if isJa { return "ユーザーが見つかりません。" }
            if isZh { return "用户不存在。" }
            if isEs { return "Usuario no encontrado." }
            return "User not found."
        case "signin_error_prefix":
            if isKo { return "로그인 중 오류가 발생했습니다: " }
            if isJa { return "ログイン中にエラーが発生しました: " }
            if isZh { return "登录时发生错误: " }
            if isEs { return "Se produjo un error durante el inicio de sesión: " }
            return "An error occurred during sign in: "
        case "apple_signin_error":
            if isKo { return "Apple 로그인 중 오류가 발생했습니다." }
            if isJa { return "Apple サインイン中にエラーが発生しました。" }
            if isZh { return "Apple登录时发生错误。" }
            if isEs { return "Se produjo un error durante el inicio de sesión con Apple." }
            return "An error occurred during Apple sign in."
        default:
            return param.isEmpty ? key : "\(key) \(param)"
        }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCurrentUser()
    }

    func loadCurrentUser() {
        // Perform database fetch on a SwiftData model actor to avoid main-thread I/O during launch.
        let store = AuthStoreActor(modelContainer: modelContext.container)
        Task(priority: .userInitiated) {
            let isLoggedIn: Bool
            do {
                isLoggedIn = try await store.hasCurrentUser()
            } catch {
                print("Failed to load current user (background): \(error)")
                isLoggedIn = false
            }

            // Back on the main actor to update UI state
            self.isAuthenticated = isLoggedIn
            if !isLoggedIn {
                self.currentUser = nil
            }
        }
    }

    func signUp(username: String, displayName: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        // 실제 앱에서는 서버 API 호출
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초 시뮬레이션

        // 사용자명 중복 검사
        let existingUserDescriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username || user.email == email
            }
        )

        do {
            let existingUsers = try modelContext.fetch(existingUserDescriptor)
            if !existingUsers.isEmpty {
                errorMessage = loc("signup_exists")
                isLoading = false
                return
            }

            // 기존 현재 사용자 해제
            clearCurrentUser()

            // 새 사용자 생성
            let lang = LanguageManager.currentLanguageCode
            let defaultStatus: String
            if lang.hasPrefix("ko") { defaultStatus = "안녕하세요!" }
            else if lang.hasPrefix("ja") { defaultStatus = "よろしくお願いします！" }
            else if lang.hasPrefix("zh") { defaultStatus = "你好！" }
            else if lang.hasPrefix("es") { defaultStatus = "¡Hola!" }
            else { defaultStatus = "Hey there!" }

            let newUser = User(
                username: username,
                displayName: displayName,
                email: email,
                statusMessage: defaultStatus,
                isCurrentUser: true
            )

            modelContext.insert(newUser)
            try modelContext.save()

            currentUser = newUser
            isAuthenticated = true
            UserDefaults.standard.set(newUser.id.uuidString, forKey: "currentUserId")

            // 샘플 친구들 추가
            createSampleFriends(for: newUser)

        } catch {
            errorMessage = loc("signup_error_prefix") + error.localizedDescription
        }

        isLoading = false
    }

    func signIn(username: String, password: String) async {
        isLoading = true
        errorMessage = nil

        // 실제 앱에서는 서버 API 호출
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1초 시뮬레이션

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username || user.email == username
            }
        )

        do {
            let users = try modelContext.fetch(descriptor)
            if let user = users.first {
                // 기존 현재 사용자 해제
                clearCurrentUser()

                // 로그인한 사용자를 현재 사용자로 설정
                user.isCurrentUser = true
                user.lastActiveAt = Date()

                try modelContext.save()

                currentUser = user
                isAuthenticated = true
                UserDefaults.standard.set(user.id.uuidString, forKey: "currentUserId")
            } else {
                errorMessage = loc("signin_not_found")
            }
        } catch {
            errorMessage = loc("signin_error_prefix") + error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        clearCurrentUser()
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "currentUserId")
    }

    private func clearCurrentUser() {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.isCurrentUser == true
            }
        )

        do {
            let users = try modelContext.fetch(descriptor)
            for user in users {
                user.isCurrentUser = false
            }
            try modelContext.save()
        } catch {
            print("Failed to clear current user: \(error)")
        }
    }

    private func createSampleFriends(for user: User) {
        let sampleFriends = [
            ("friend1", "김친구", "friend1@example.com"),
            ("friend2", "이동료", "friend2@example.com"),
            ("friend3", "박가족", "friend3@example.com"),
            ("friend4", "최스터디", "friend4@example.com")
        ]

        for (_, name, email) in sampleFriends {
            let friendship = Friendship(
                userId: user.id.uuidString,
                friendId: UUID().uuidString,
                friendName: name,
                friendEmail: email,
                status: .accepted
            )

            modelContext.insert(friendship)
        }

        // 테스트용 받은 친구 요청들 추가
        let pendingRequests = [
            ("pending1", "신청자1", "pending1@example.com"),
            ("pending2", "신청자2", "pending2@example.com")
        ]

        for (_, name, email) in pendingRequests {
            let receivedRequest = Friendship(
                userId: UUID().uuidString, // 다른 사용자의 ID
                friendId: user.id.uuidString, // 현재 사용자가 친구로 추가되는 것
                friendName: name,
                friendEmail: email,
                status: .pending
            )
            receivedRequest.ownerUserId = user.id.uuidString
            modelContext.insert(receivedRequest)
        }

        do {
            try modelContext.save()
        } catch {
            authLogger.error("Failed to save sample friends: \(error)")
        }
    }

    // MARK: - SSO Sign-In

    func signInWithApple(userId: String, email: String?, fullName: PersonNameComponents?) async {
        isLoading = true
        errorMessage = nil

        let identifier = "apple_\(String(userId.prefix(8)))"
        let name = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        do {
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in user.username == identifier }
            )
            let existing = try modelContext.fetch(descriptor)
            clearCurrentUser()

            let user: User
            if let existingUser = existing.first {
                existingUser.isCurrentUser = true
                existingUser.lastActiveAt = Date()
                user = existingUser
            } else {
                let newUser = User(
                    username: identifier,
                    displayName: name.isEmpty ? "Apple User" : name,
                    email: email ?? "",
                    statusMessage: "안녕하세요!",
                    isCurrentUser: true
                )
                modelContext.insert(newUser)
                user = newUser
            }

            try modelContext.save()
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = loc("apple_signin_error")
        }

        isLoading = false
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            let info = try await GoogleOAuthService.signIn()
            let identifier = "google_\(String(info.userId.prefix(8)))"

            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate<User> { user in user.username == identifier }
            )
            let existing = try modelContext.fetch(descriptor)
            clearCurrentUser()

            let user: User
            if let existingUser = existing.first {
                existingUser.isCurrentUser = true
                existingUser.lastActiveAt = Date()
                user = existingUser
            } else {
                let newUser = User(
                    username: identifier,
                    displayName: info.displayName,
                    email: info.email,
                    statusMessage: "안녕하세요!",
                    isCurrentUser: true
                )
                modelContext.insert(newUser)
                user = newUser
            }

            try modelContext.save()
            currentUser = user
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateProfile(displayName: String, statusMessage: String, profileImageData: Data?) {
        guard let user = currentUser else { return }

        user.displayName = displayName
        user.statusMessage = statusMessage
        user.profileImageData = profileImageData
        user.lastActiveAt = Date()
        objectWillChange.send()

        try? modelContext.save()
    }

    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        guard let user = currentUser else { return }

        // 실제 앱에서는 서버에 계정 삭제 요청
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 시뮬레이션

        let uid = user.id.uuidString

        // 관련 친구 관계 삭제
        let friendshipDescriptor = FetchDescriptor<Friendship>()
        do {
            let allFriendships = try modelContext.fetch(friendshipDescriptor)
            for friendship in allFriendships where friendship.userId == uid || friendship.friendId == uid {
                modelContext.delete(friendship)
            }
        } catch {
            print("Failed to fetch friendships for deletion: \(error)")
        }

        // 사용자 삭제
        modelContext.delete(user)

        do {
            try modelContext.save()
        } catch {
            print("Failed to save context after account deletion: \(error)")
        }

        // 알림 정리
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        try? await UNUserNotificationCenter.current().setBadgeCount(0)

        // 로컬 세션 종료
        currentUser = nil
        isAuthenticated = false
    }
}
