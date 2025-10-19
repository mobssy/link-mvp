//
//  FriendRowViews.swift
//  TalkMVP
//
//  Friend list row components following Single Responsibility Principle
//

import SwiftUI
import SwiftData

// MARK: - My Profile Row
struct MyProfileRow: View {
    @ObservedObject var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showingProfileEdit = false

    var body: some View {
        Button(action: {
            showingProfileEdit = true
        }) {
            HStack(spacing: 16) {
                if let data = authManager.currentUser?.profileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedDisplayName().capitalized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(localizedStatusMessage())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingProfileEdit) {
            ProfileEditView(authManager: authManager)
                .environmentObject(languageManager)
        }
    }

    private func localizedDisplayName() -> String {
        let isKorean = languageManager.isKorean
        let raw = (authManager.currentUser?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return NSLocalizedString("user", comment: "")
        }
        if raw == "테스터" || raw == "Tester" {
            return isKorean ? "테스터" : "Tester"
        }
        return raw
    }

    private func localizedStatusMessage() -> String {
        let isKorean = languageManager.isKorean
        let raw = (authManager.currentUser?.statusMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return NSLocalizedString("status_message", comment: "")
        }
        if raw == "테스트 모드로 체험 중입니다" || raw == "Experiencing in test mode" {
            return isKorean ? "테스트 모드로 체험 중입니다" : "Experiencing in test mode"
        }
        return raw
    }
}

// MARK: - Friend Row
struct FriendRow: View {
    let friendship: Friendship
    let onDataChanged: () -> Void
    var onOpened: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var showingProfileView = false

    var body: some View {
        Button(action: {
            onOpened?()
            showingProfileView = true
        }) {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.appPrimary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(friendship.friendName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if friendship.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }

                    Text(L10n.text("online", languageManager.currentLanguage == .korean ? .korean : .english))
                        .font(.subheadline)
                        .foregroundColor(.green)
                }

                Spacer()

                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleFavorite()
            } label: {
                Label(
                    friendship.isFavorite ? L10n.text("unfavorite", languageManager.currentLanguage == .korean ? .korean : .english) : L10n.text("favorite", languageManager.currentLanguage == .korean ? .korean : .english),
                    systemImage: friendship.isFavorite ? "star.slash.fill" : "star.fill"
                )
            }
            .tint(friendship.isFavorite ? .gray : .yellow)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                toggleNotifications()
            } label: {
                Label(
                    friendship.notificationsEnabled ? L10n.text("mute_notifications", languageManager.currentLanguage == .korean ? .korean : .english) : L10n.text("unmute_notifications", languageManager.currentLanguage == .korean ? .korean : .english),
                    systemImage: friendship.notificationsEnabled ? "bell.slash.fill" : "bell.fill"
                )
            }
            .tint(friendship.notificationsEnabled ? .gray : .blue)
        }
        .sheet(isPresented: $showingProfileView) {
            FriendProfileView(friendship: friendship)
        }
    }

    private func toggleFavorite() {
        friendship.isFavorite.toggle()
        try? modelContext.save()
        onDataChanged()
    }

    private func toggleNotifications() {
        friendship.notificationsEnabled.toggle()
        try? modelContext.save()
        onDataChanged()
    }
}

// MARK: - Received Friend Request Row
struct ReceivedRequestRow: View {
    let friendship: Friendship
    let modelContext: ModelContext
    let onDataChanged: () -> Void
    var onAccepted: ((Friendship) -> Void)?
    @State private var isAccepting = false
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(L10n.text("friend_request", languageManager.currentLanguage == .korean ? .korean : .english))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(L10n.text("accept", languageManager.currentLanguage == .korean ? .korean : .english)) {
                acceptFriendRequest()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isAccepting)
        }
        .padding(.vertical, 4)
    }

    private func acceptFriendRequest() {
        isAccepting = true
        friendship.status = .accepted
        try? modelContext.save()
        onDataChanged()
        onAccepted?(friendship)
        isAccepting = false
    }
}

// MARK: - Pending Friend Request Row
struct PendingRequestRow: View {
    let friendship: Friendship
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

                Text(L10n.text("request_pending", languageManager.currentLanguage == .korean ? .korean : .english))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(L10n.text("pending_short", languageManager.currentLanguage == .korean ? .korean : .english))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
