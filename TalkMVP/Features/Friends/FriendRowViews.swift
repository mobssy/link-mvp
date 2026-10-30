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
    var authManager: AuthManager
    @Environment(LanguageManager.self) private var languageManager
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
                    SenderAvatarView(name: localizedDisplayName(), size: 60)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedDisplayName().capitalized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.primary)

                    Text(localizedStatusMessage())
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingProfileEdit) {
            ProfileEditView(authManager: authManager)
                .environment(languageManager)
        }
    }

    private func localizedDisplayName() -> String {
        let raw = (authManager.currentUser?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return L10n.text("user", languageManager.currentLanguage)
        }
        if raw == "테스터" || raw == "Tester" {
            return languageManager.localize(ko: "테스터", en: "Tester", ja: "テスター", zh: "测试员", es: "Tester")
        }
        return raw
    }

    private func localizedStatusMessage() -> String {
        let raw = (authManager.currentUser?.statusMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return L10n.text("status_message", languageManager.currentLanguage)
        }
        return TestData.statusMessage(raw, testModeStatus: languageManager.localize(
            ko: "테스트 모드로 체험 중입니다",
            en: "Experiencing in test mode",
            ja: "テストモードで体験中です",
            zh: "正在以测试模式体验",
            es: "Experimentando en modo de prueba"
        ))
    }
}

// MARK: - Friend Row
struct FriendRow: View {
    let friendship: Friendship
    let onDataChanged: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var languageManager

    /// Selects the friend in the Friends list, which opens their profile.
    var body: some View {
        NavigationLink(value: friendship.id) {
            HStack(spacing: 16) {
                SenderAvatarView(name: friendship.friendName, size: 50)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        // No fixed color, so it turns white on a selected row.
                        Text(friendship.friendName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if friendship.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggleFavorite()
            } label: {
                Label(
                    friendship.isFavorite
                        ? L10n.text("unfavorite", languageManager.appLanguage)
                        : L10n.text("favorite", languageManager.appLanguage),
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
                    friendship.notificationsEnabled
                        ? L10n.text("mute_notifications", languageManager.appLanguage)
                        : L10n.text("unmute_notifications", languageManager.appLanguage),
                    systemImage: friendship.notificationsEnabled ? "bell.slash.fill" : "bell.fill"
                )
            }
            .tint(friendship.notificationsEnabled ? .gray : .blue)
        }
    }

    private var friendships: FriendshipRepositoryProtocol {
        LocalFriendshipRepository(modelContext: modelContext)
    }

    private func toggleFavorite() {
        try? friendships.setFavorite(!friendship.isFavorite, of: friendship)
        onDataChanged()
    }

    private func toggleNotifications() {
        try? friendships.setNotificationsEnabled(!friendship.notificationsEnabled, of: friendship)
        onDataChanged()
    }
}

// MARK: - Received Friend Request Row
struct ReceivedRequestRow: View {
    @ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 40
    let friendship: Friendship
    let repository: FriendshipRepositoryProtocol
    let onDataChanged: () -> Void
    var onAccepted: ((Friendship) -> Void)?
    @State private var isAccepting = false
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        HStack {
            SenderAvatarView(name: friendship.friendName, size: avatarSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                Text(L10n.text("friend_request", languageManager.appLanguage))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button(L10n.text("accept", languageManager.appLanguage)) {
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
        try? repository.setStatus(.accepted, of: friendship)
        onDataChanged()
        onAccepted?(friendship)
        isAccepting = false
    }
}

// MARK: - Pending Friend Request Row
struct PendingRequestRow: View {
    @ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 40
    let friendship: Friendship
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        HStack {
            // Gray until they accept.
            SenderAvatarView(name: friendship.friendName, size: avatarSize)
                .saturation(0)

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName)
                    .font(.headline)
                    .foregroundStyle(Color.primary)

                Text(L10n.text("request_pending", languageManager.appLanguage))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Text(L10n.text("pending_short", languageManager.appLanguage))
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(.vertical, 4)
    }
}
