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

private let authLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "AuthManager")

/// Owns the signed-in session. The persisted source of truth is the single `User`
/// flagged `isCurrentUser`; every sign-in path goes through `activate(_:)` and every
/// sign-out path through `endSession()`, so the flag and `currentUser` never disagree.
@MainActor
class AuthManager: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var isAuthenticated: Bool { currentUser != nil }

    private let modelContext: ModelContext
    /// Stand-in for a server round trip on sign-up / sign-in. Tests pass `.zero`.
    private let simulatedLatency: Duration
    private let attachmentFiles: AttachmentFileStoring

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

    init(
        modelContext: ModelContext,
        simulatedLatency: Duration = .seconds(1),
        attachmentFiles: AttachmentFileStoring = DiskAttachmentFileStore()
    ) {
        self.modelContext = modelContext
        self.simulatedLatency = simulatedLatency
        self.attachmentFiles = attachmentFiles
        restoreSession()
    }

    /// Picks up the user that was signed in when the app last ran.
    /// A single indexed fetch, so it runs synchronously: the first frame already
    /// shows the right screen instead of flashing the sign-in form.
    private func restoreSession() {
        var descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.isCurrentUser == true
            }
        )
        descriptor.fetchLimit = 1
        do {
            currentUser = try modelContext.fetch(descriptor).first
        } catch {
            authLogger.error("Failed to restore session: \(error.localizedDescription, privacy: .public)")
            currentUser = nil
        }
    }

    func signUp(username: String, displayName: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 실제 앱에서는 서버 API 호출
        try? await Task.sleep(for: simulatedLatency)

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
                return
            }

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
                statusMessage: defaultStatus
            )
            modelContext.insert(newUser)
            try activate(newUser)

            // 샘플 친구들 추가
            createSampleFriends(for: newUser)
        } catch {
            errorMessage = loc("signup_error_prefix") + error.localizedDescription
        }
    }

    func signIn(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 실제 앱에서는 서버 API 호출
        try? await Task.sleep(for: simulatedLatency)

        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username || user.email == username
            }
        )

        do {
            guard let user = try modelContext.fetch(descriptor).first else {
                errorMessage = loc("signin_not_found")
                return
            }
            try activate(user)
        } catch {
            errorMessage = loc("signin_error_prefix") + error.localizedDescription
        }
    }

    /// Starts the credential-free demo session ("test mode") as a fresh local tester account.
    func startTestSession(displayName: String, statusMessage: String, friends: [(name: String, email: String)]) {
        errorMessage = nil
        let tester = User(
            username: "tester",
            displayName: displayName,
            email: "test@example.com",
            statusMessage: statusMessage
        )
        modelContext.insert(tester)
        for friend in friends {
            modelContext.insert(Friendship(
                userId: tester.id.uuidString,
                friendId: UUID().uuidString,
                friendName: friend.name,
                friendEmail: friend.email,
                status: .accepted
            ))
        }

        do {
            try activate(tester)
        } catch {
            authLogger.error("Failed to start test session: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try clearCurrentUserFlags()
            try modelContext.save()
        } catch {
            authLogger.error("Failed to persist sign-out: \(error.localizedDescription, privacy: .public)")
        }
        currentUser = nil
    }

    /// Marks `user` as the one signed-in account and publishes it.
    private func activate(_ user: User) throws {
        try clearCurrentUserFlags()
        user.isCurrentUser = true
        user.lastActiveAt = Date()
        try modelContext.save()
        currentUser = user
    }

    private func clearCurrentUserFlags() throws {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.isCurrentUser == true
            }
        )
        for user in try modelContext.fetch(descriptor) {
            user.isCurrentUser = false
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
        defer { isLoading = false }

        let name = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        do {
            try signInWithSSO(
                identifier: "apple_\(String(userId.prefix(8)))",
                displayName: name.isEmpty ? "Apple User" : name,
                email: email ?? ""
            )
        } catch {
            errorMessage = loc("apple_signin_error")
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let info = try await GoogleOAuthService.signIn()
            try signInWithSSO(
                identifier: "google_\(String(info.userId.prefix(8)))",
                displayName: info.displayName,
                email: info.email
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Reuses the local account created by an earlier sign-in with the same provider identity,
    /// or creates it on first use.
    private func signInWithSSO(identifier: String, displayName: String, email: String) throws {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in user.username == identifier }
        )
        let user: User
        if let existingUser = try modelContext.fetch(descriptor).first {
            user = existingUser
        } else {
            user = User(
                username: identifier,
                displayName: displayName,
                email: email,
                statusMessage: "안녕하세요!"
            )
            modelContext.insert(user)
        }
        try activate(user)
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

    /// Deletes the account. With no backend yet, that means wiping everything stored on
    /// this device — conversations and their attachment files, friendships and local
    /// accounts — then ending the session.
    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            for message in try modelContext.fetch(FetchDescriptor<Message>()) {
                modelContext.delete(message)
            }
            for chatRoom in try modelContext.fetch(FetchDescriptor<ChatRoom>()) {
                modelContext.delete(chatRoom)
            }
            for friendship in try modelContext.fetch(FetchDescriptor<Friendship>()) {
                modelContext.delete(friendship)
            }
            for user in try modelContext.fetch(FetchDescriptor<User>()) {
                modelContext.delete(user)
            }
            try modelContext.save()
        } catch {
            authLogger.error("Failed to delete account data: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            return
        }
        attachmentFiles.removeFiles(keeping: [])

        // 알림 정리
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        try? await center.setBadgeCount(0)

        currentUser = nil
    }
}
