//
//  AddFriendView.swift
//  TalkMVP
//
//  Friend adding views following Single Responsibility Principle
//

import SwiftUI
import SwiftData
import os

private let addFriendLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "AddFriendView")

// MARK: - Add Friend View
struct AddFriendView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var notificationManager: NotificationManager
    let onFriendAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var friendEmail = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var lastActionWasSuccess = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(L10n.text("friend_email_placeholder", languageManager.currentLanguage), text: $friendEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                searchForUsers()
                            }

                        Button(L10n.text("search", languageManager.currentLanguage)) {
                            searchForUsers()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(friendEmail.isEmpty || isSearching)
                    }
                } header: {
                    Text(L10n.text("add_by_email", languageManager.currentLanguage))
                } footer: {
                    Text(L10n.text("add_by_email_footer", languageManager.currentLanguage))
                }

                if isSearching {
                    Section(L10n.text("searching", languageManager.currentLanguage)) {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.text("searching_users", languageManager.currentLanguage))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if !searchResults.isEmpty {
                    Section(L10n.text("search_results", languageManager.currentLanguage)) {
                        ForEach(searchResults, id: \.id) { result in
                            UserSearchResultRow(
                                result: result,
                                authManager: authManager,
                                notificationManager: notificationManager,
                                friendships: LocalFriendshipRepository(modelContext: modelContext)
                            ) { success, message in
                                lastActionWasSuccess = success
                                alertMessage = message
                                showingAlert = true
                                if success {
                                    searchResults.removeAll()
                                    friendEmail = ""
                                    onFriendAdded()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.text("add_friend", languageManager.currentLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.text("cancel", languageManager.currentLanguage)) {
                        dismiss()
                    }
                }
            }
        }
        .alert(L10n.text("alert", languageManager.currentLanguage), isPresented: $showingAlert) {
            Button(L10n.text("ok", languageManager.currentLanguage)) {
                if lastActionWasSuccess {
                    // Give time for data to propagate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            // Auto-focus keyboard when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }

    private func searchForUsers() {
        let email = friendEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            alertMessage = L10n.text("enter_email_message", languageManager.currentLanguage)
            showingAlert = true
            return
        }
        guard isValidEmail(email) else {
            alertMessage = L10n.text("invalid_email_format", languageManager.currentLanguage)
            showingAlert = true
            return
        }

        isSearching = true
        searchResults = []

        Task {
            do {
                let results = try await FriendSearchService.searchUsers(by: email)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    addFriendLogger.error("검색 오류: \(error.localizedDescription, privacy: .public)")
                    self.alertMessage = L10n.text("search_error_prefix", languageManager.currentLanguage) + error.localizedDescription
                    self.showingAlert = true
                    self.isSearching = false
                }
            }
        }
    }
}

// MARK: - User Search Result Row
struct UserSearchResultRow: View {
    let result: UserSearchResult
    @ObservedObject var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    let notificationManager: NotificationManager
    let friendships: FriendshipRepositoryProtocol
    let onComplete: (Bool, String) -> Void

    @State private var isSendingRequest = false

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.appPrimaryText)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(result.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(L10n.text("add_friend", languageManager.currentLanguage)) {
                sendFriendRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isSendingRequest)
        }
        .padding(.vertical, 4)
    }

    private func sendFriendRequest() {
        isSendingRequest = true

        Task {
            do {
                let success = try await FriendSearchService.sendFriendRequest(
                    from: authManager.currentUser?.id.uuidString ?? "",
                    to: result.id
                )

                await MainActor.run {
                    defer { isSendingRequest = false }

                    guard success else {
                        onComplete(false, L10n.text("friend_request_failed", languageManager.currentLanguage))
                        return
                    }

                    guard let me = authManager.currentUser else {
                        onComplete(false, L10n.text("error_occurred_prefix", languageManager.currentLanguage) + "User not found")
                        return
                    }
                    let senderId = me.id.uuidString

                    // An unsaved request would vanish at the next launch, so a failed save is a
                    // failed request; the repository keeps neither record then.
                    do {
                        try friendships.sendRequest(
                            from: FriendRequestParty(id: senderId, name: me.displayName, email: me.email),
                            to: FriendRequestParty(id: result.id, name: result.displayName, email: result.email)
                        )
                    } catch {
                        onComplete(false, L10n.text("friend_request_failed", languageManager.currentLanguage))
                        return
                    }

                    // Schedule a local notification to simulate receiver-side alert
                    let senderName = authManager.currentUser?.displayName ?? L10n.text("user", languageManager.currentLanguage)
                    let senderEmail = authManager.currentUser?.email ?? ""
                    Task { await notificationManager.scheduleFriendRequestNotification(from: senderName, email: senderEmail) }

                    NotificationCenter.default.post(name: .friendshipPendingCreated, object: nil, userInfo: ["friendId": result.id])

                    onComplete(true, L10n.text("friend_request_sent", languageManager.currentLanguage))
                }
            } catch {
                await MainActor.run {
                    addFriendLogger.error("Friend request failed: \(error.localizedDescription, privacy: .public)")
                    onComplete(false, L10n.text("error_occurred_prefix", languageManager.currentLanguage) + error.localizedDescription)
                    isSendingRequest = false
                }
            }
        }
    }
}
