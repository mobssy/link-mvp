//
//  FriendManagementViews.swift
//  TalkMVP
//
//  Friend management views following Single Responsibility Principle
//

import SwiftUI
import SwiftData

// MARK: - Blocked Friends View
struct BlockedFriendsView: View {
    let blockedFriends: [Friendship]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            List {
                if blockedFriends.isEmpty {
                    ContentUnavailableView(
                        L10n.text("no_blocked_friends", languageManager.currentLanguage),
                        systemImage: "person.slash",
                        description: Text(L10n.text("no_blocked_friends", languageManager.currentLanguage))
                    )
                } else {
                    ForEach(blockedFriends, id: \.id) { friendship in
                        BlockedFriendRow(friendship: friendship, modelContext: modelContext)
                    }
                }
            }
            .navigationTitle(L10n.text("blocked_list", languageManager.currentLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.text("close", languageManager.currentLanguage)) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Blocked Friend Row
struct BlockedFriendRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    @State private var showingUnblockAlert = false
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(L10n.text("blocked", languageManager.currentLanguage))
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            Button(L10n.text("unblock", languageManager.currentLanguage)) {
                showingUnblockAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .alert(L10n.text("unblock_friend", languageManager.currentLanguage), isPresented: $showingUnblockAlert) {
            Button(L10n.text("cancel", languageManager.currentLanguage), role: .cancel) { }
            Button(L10n.text("unblock", languageManager.currentLanguage), role: .destructive) {
                unblockFriend()
            }
        } message: {
            Text(String(format: L10n.text("unblock_message", languageManager.currentLanguage), friendship.friendName))
        }
    }

    private func unblockFriend() {
        friendship.status = .accepted
        try? modelContext.save()
    }
}

// MARK: - Manage Friends View
struct ManageFriendsView: View {
    let hiddenFriends: [Friendship]
    let blockedFriends: [Friendship]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(L10n.text("hidden_list", languageManager.currentLanguage))) {
                    if hiddenFriends.isEmpty {
                        ContentUnavailableView(
                            L10n.text("no_hidden_friends", languageManager.currentLanguage),
                            systemImage: "eye.slash",
                            description: Text(L10n.text("no_hidden_friends", languageManager.currentLanguage))
                        )
                    } else {
                        ForEach(hiddenFriends, id: \.id) { friendship in
                            HiddenFriendRow(friendship: friendship, modelContext: modelContext)
                        }
                    }
                }

                Section(header: Text(L10n.text("blocked_list", languageManager.currentLanguage))) {
                    if blockedFriends.isEmpty {
                        ContentUnavailableView(
                            L10n.text("no_blocked_friends", languageManager.currentLanguage),
                            systemImage: "hand.raised.slash",
                            description: Text(L10n.text("no_blocked_friends", languageManager.currentLanguage))
                        )
                    } else {
                        ForEach(blockedFriends, id: \.id) { friendship in
                            BlockedFriendRow(friendship: friendship, modelContext: modelContext)
                        }
                    }
                }
            }
            .navigationTitle(L10n.text("manage_hidden_blocked", languageManager.currentLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.text("close", languageManager.currentLanguage)) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Hidden Friend Row
struct HiddenFriendRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    @State private var showingUnhideAlert = false
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(L10n.text("hidden", languageManager.currentLanguage))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(L10n.text("unhide", languageManager.currentLanguage)) {
                showingUnhideAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
        .alert(L10n.text("unhide_friend", languageManager.currentLanguage), isPresented: $showingUnhideAlert) {
            Button(L10n.text("cancel", languageManager.currentLanguage), role: .cancel) { }
            Button(L10n.text("unhide", languageManager.currentLanguage), role: .destructive) {
                unhideFriend()
            }
        } message: {
            Text(String(format: L10n.text("unhide_message", languageManager.currentLanguage), friendship.friendName))
        }
    }

    private func unhideFriend() {
        friendship.status = .accepted
        try? modelContext.save()
    }
}
