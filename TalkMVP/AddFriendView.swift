//
//  AddFriendView.swift
//  TalkMVP
//
//  Friend adding views following Single Responsibility Principle
//

import SwiftUI
import SwiftData

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
                        TextField(L10n.text("friend_email_placeholder", languageManager.currentLanguage == .korean ? .korean : .english), text: $friendEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                searchForUsers()
                            }

                        Button(L10n.text("search", languageManager.currentLanguage == .korean ? .korean : .english)) {
                            searchForUsers()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(friendEmail.isEmpty || isSearching)
                    }
                } header: {
                    Text(L10n.text("add_by_email", languageManager.currentLanguage == .korean ? .korean : .english))
                } footer: {
                    Text(L10n.text("add_by_email_footer", languageManager.currentLanguage == .korean ? .korean : .english))
                }

                if isSearching {
                    Section(L10n.text("searching", languageManager.currentLanguage == .korean ? .korean : .english)) {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.text("searching_users", languageManager.currentLanguage == .korean ? .korean : .english))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if !searchResults.isEmpty {
                    Section(L10n.text("search_results", languageManager.currentLanguage == .korean ? .korean : .english)) {
                        ForEach(searchResults, id: \.id) { result in
                            UserSearchResultRow(
                                result: result,
                                authManager: authManager,
                                notificationManager: notificationManager,
                                modelContext: modelContext
                            ) { success, message in
                                print("📝 UserSearchResultRow onComplete: success=\(success), message=\(message)")
                                lastActionWasSuccess = success
                                alertMessage = message
                                showingAlert = true
                                if success {
                                    searchResults.removeAll()
                                    friendEmail = ""
                                    print("📝 Calling onFriendAdded callback...")
                                    onFriendAdded()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.text("add_friend", languageManager.currentLanguage == .korean ? .korean : .english))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.text("cancel", languageManager.currentLanguage == .korean ? .korean : .english)) {
                        dismiss()
                    }
                }
            }
        }
        .alert(L10n.text("alert", languageManager.currentLanguage == .korean ? .korean : .english), isPresented: $showingAlert) {
            Button(L10n.text("ok", languageManager.currentLanguage == .korean ? .korean : .english)) {
                if lastActionWasSuccess {
                    print("✅ Alert OK pressed, dismissing AddFriendView...")
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
            alertMessage = NSLocalizedString("enter_email_message", comment: "")
            showingAlert = true
            return
        }
        guard isValidEmail(email) else {
            alertMessage = NSLocalizedString("invalid_email_format", comment: "")
            showingAlert = true
            return
        }

        print("사용자 검색 시작: \(email)")
        isSearching = true
        searchResults = []

        Task {
            do {
                let results = try await FriendSearchService.searchUsers(by: email)
                await MainActor.run {
                    print("검색 결과: \(results.count)개")
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    print("검색 오류: \(error.localizedDescription)")
                    self.alertMessage = NSLocalizedString("search_error_prefix", comment: "") + error.localizedDescription
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
    let modelContext: ModelContext
    let onComplete: (Bool, String) -> Void

    @State private var isSendingRequest = false

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.appPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(result.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(L10n.text("add_friend", languageManager.currentLanguage == .korean ? .korean : .english)) {
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
                        onComplete(false, L10n.text("friend_request_failed", languageManager.currentLanguage == .korean ? .korean : .english))
                        return
                    }

                    // Create outgoing (sender) friendship record
                    guard let senderId = authManager.currentUser?.id.uuidString else {
                        onComplete(false, L10n.text("error_occurred_prefix", languageManager.currentLanguage == .korean ? .korean : .english) + "User not found")
                        return
                    }

                    let outgoing = Friendship(
                        userId: senderId,
                        friendId: result.id,
                        friendName: result.displayName,
                        friendEmail: result.email,
                        status: .pending
                    )
                    outgoing.ownerUserId = senderId
                    modelContext.insert(outgoing)

                    // Create incoming (receiver) mirror record for backend readiness
                    let mirror = Friendship(
                        userId: result.id,
                        friendId: senderId,
                        friendName: authManager.currentUser?.displayName ?? L10n.text("user", languageManager.currentLanguage == .korean ? .korean : .english),
                        friendEmail: authManager.currentUser?.email ?? "",
                        status: .pending
                    )
                    mirror.ownerUserId = result.id
                    modelContext.insert(mirror)

                    // Try to save - if it fails, we'll still notify (data is in memory)
                    do {
                        try modelContext.save()
                        print("✅ Friendship saved successfully to persistent store")
                    } catch let error as NSError {
                        print("⚠️ Save to persistent store failed: \(error)")
                        print("⚠️ Error domain: \(error.domain), code: \(error.code)")
                        print("⚠️ Data remains in memory context and will be used")
                    }

                    // Schedule a local notification to simulate receiver-side alert
                    let senderName = authManager.currentUser?.displayName ?? L10n.text("user", languageManager.currentLanguage == .korean ? .korean : .english)
                    let senderEmail = authManager.currentUser?.email ?? ""
                    notificationManager.scheduleFriendRequestNotification(from: senderName, email: senderEmail)

                    // Post notification AFTER insert (data is in modelContext even if save failed)
                    NotificationCenter.default.post(name: .friendshipPendingCreated, object: nil, userInfo: ["friendId": result.id])
                    print("✅ Notification posted, data available in memory")

                    onComplete(true, L10n.text("friend_request_sent", languageManager.currentLanguage == .korean ? .korean : .english))
                }
            } catch {
                await MainActor.run {
                    print("❌ sendFriendRequest error: \(error)")
                    onComplete(false, L10n.text("error_occurred_prefix", languageManager.currentLanguage == .korean ? .korean : .english) + error.localizedDescription)
                    isSendingRequest = false
                }
            }
        }
    }
}
