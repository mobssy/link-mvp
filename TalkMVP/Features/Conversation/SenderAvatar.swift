//
//  SenderAvatar.swift
//  TalkMVP
//

import SwiftUI

/// How a message's sender is drawn: their initial on a color picked from their name, so each
/// person in a group looks different and the same in every chat.
nonisolated struct SenderAvatar: Equatable {
    /// How many colors there are to pick from.
    static let paletteCount = 5

    let initial: String
    let colorIndex: Int

    init(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        initial = trimmed.first.map { String($0).uppercased() } ?? "?"
        // Not `hashValue`, which changes with every launch.
        colorIndex = trimmed.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % Self.paletteCount }
    }

    /// The badge on the avatar of someone who writes in another language than the reader:
    /// the language's code ("JA"), not a flag, since a language isn't a country. Nil otherwise.
    static func languageBadge(senderLanguage: String?, readerLanguage: String) -> String? {
        guard let senderLanguage, !ConversationLanguage.isSame(senderLanguage, readerLanguage) else { return nil }
        return String(senderLanguage.prefix(2)).uppercased()
    }
}

/// A sender's initial in a colored circle, with their language's code when it isn't the reader's.
struct SenderAvatarView: View {
    let avatar: SenderAvatar
    var languageBadge: String?
    var size: CGFloat = 36

    /// System colors that keep white text readable in both themes.
    private static let palette: [Color] = [.blue, .indigo, .purple, .pink, .brown]

    var body: some View {
        Circle()
            .fill(Self.palette[avatar.colorIndex % Self.palette.count].gradient)
            .overlay {
                Text(avatar.initial)
                    .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
            .overlay(alignment: .bottomTrailing) {
                if let languageBadge {
                    Text(languageBadge)
                        .font(.system(size: size * 0.26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color(UIColor.systemBackground)))
                        .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 0.5))
                        .offset(x: 6, y: 4)
                }
            }
    }
}
