//
//  FriendBanner.swift
//  TalkMVP
//

import SwiftUI

/// What a one-to-one chat shows under its navigation bar about the person it is with: the one
/// place to add them, instead of a button on every message they sent.
nonisolated enum FriendBanner: Equatable {
    case none, addFriend, requestSent

    /// `standing` is nil until it has been looked up. A group has no one person to add, and
    /// someone blocked is unblocked from the menu, not befriended from a banner.
    init(isGroup: Bool, standing: FriendStanding?, isBlocked: Bool) {
        guard !isGroup, !isBlocked else {
            self = .none
            return
        }
        switch standing {
        case .stranger: self = .addFriend
        case .requested: self = .requestSent
        case .friend, nil: self = .none
        }
    }
}

struct FriendBannerView: View {
    @Environment(LanguageManager.self) private var languageManager

    let banner: FriendBanner
    let name: String
    let onAddFriend: () -> Void

    var body: some View {
        if banner != .none {
            HStack(spacing: 12) {
                Text(String(format: languageManager.localize(ko: "%@님은 친구가 아닙니다", en: "%@ isn't your friend", ja: "%@さんは友だちではありません", zh: "%@ 不是你的朋友", es: "%@ no es tu amigo"), name))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if banner == .addFriend {
                    Button(languageManager.localize(ko: "친구 추가", en: "Add Friend", ja: "友だち追加", zh: "添加好友", es: "Agregar amigo"), action: onAddFriend)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(.appPrimaryText)
                } else {
                    Text(Self.requestSentText(languageManager))
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
    }

    static func requestSentText(_ languageManager: LanguageManager) -> String {
        languageManager.localize(ko: "요청 보냄", en: "Request Sent", ja: "リクエスト送信済み", zh: "已发送请求", es: "Solicitud enviada")
    }
}
