//
//  GroupInfoSheet.swift
//  TalkMVP
//

import SwiftUI

/// What a group chat is: its members, with their faces and languages, and Add Friend for those
/// who aren't friends yet. Opened from the chat's title.
struct GroupInfoSheet: View {
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss

    let name: String
    let members: [String]
    /// Each member's language badge, when it isn't the reader's.
    let languageBadges: [String: String]
    /// How the reader stands with each member, by name.
    let standings: [String: FriendStanding]
    /// Sends a member a friend request; throws if it couldn't be saved.
    let onAddFriend: (String) throws -> Void

    /// Members asked while the sheet is open.
    @State private var requested: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        GroupAvatarView(avatar: GroupAvatar(members: members), size: 72)
                            .accessibilityHidden(true)
                        Text(name)
                            .font(.title2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section(String(format: languageManager.localize(ko: "멤버 %d명", en: "%d Members", ja: "メンバー %d人", zh: "%d 位成员", es: "%d miembros"), members.count)) {
                    ForEach(members, id: \.self) { member in
                        row(for: member)
                    }
                }
            }
            .accessibilityIdentifier("groupMembers")
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageManager.localize(ko: "완료", en: "Done", ja: "完了", zh: "完成", es: "Listo")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(for member: String) -> some View {
        HStack(spacing: 12) {
            SenderAvatarView(avatar: SenderAvatar(name: member), languageBadge: languageBadges[member], size: 40)
                .accessibilityHidden(true)
            Text(member)
            Spacer()
            switch requested.contains(member) ? .requested : (standings[member] ?? .stranger) {
            case .friend:
                Text(languageManager.localize(ko: "친구", en: "Friend", ja: "友だち", zh: "好友", es: "Amigo"))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            case .requested:
                Text(FriendBannerView.requestSentText(languageManager))
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            case .stranger:
                Button(languageManager.localize(ko: "친구 추가", en: "Add Friend", ja: "友だち追加", zh: "添加好友", es: "Agregar amigo")) {
                    do {
                        try onAddFriend(member)
                        requested.insert(member)
                    } catch {
                        // Not sent: the button stays, so it can be tried again.
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}
