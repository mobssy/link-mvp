//
//  ChatSubtitle.swift
//  TalkMVP
//

import Foundation

/// The line under a chat's title. It says only what the app knows: who is in a group, and what
/// language the other person writes in. With no server there is no presence to show.
nonisolated enum ChatSubtitle {
    /// Members named before the rest are counted.
    static let namedMembers = 3

    /// A group's members ("강호동, 한소희", or "A, B +3" when there are more than three), or the
    /// other person's language when it isn't the reader's ("Japanese · Translated"). Nil when
    /// there is nothing to say.
    static func text(
        isGroup: Bool, memberNames: [String], partnerLanguage: String?,
        readerLanguage: String, isTranslating: Bool, translatedLabel: String
    ) -> String? {
        if isGroup {
            guard !memberNames.isEmpty else { return nil }
            guard memberNames.count > namedMembers else { return memberNames.joined(separator: ", ") }
            return memberNames.prefix(namedMembers - 1).joined(separator: ", ") + " +\(memberNames.count - (namedMembers - 1))"
        }
        guard let partnerLanguage, !sameLanguage(partnerLanguage, readerLanguage),
              let name = Locale(identifier: readerLanguage).localizedString(forIdentifier: partnerLanguage)
        else { return nil }
        let language = name.prefix(1).uppercased() + name.dropFirst()
        return isTranslating ? "\(language) · \(translatedLabel)" : language
    }

    /// Whether two language codes are the same language: Chinese by script, the rest by language.
    private static func sameLanguage(_ a: String, _ b: String) -> Bool {
        let a = a.lowercased(), b = b.lowercased()
        if a.hasPrefix("zh") || b.hasPrefix("zh") { return a == b }
        return a.prefix(2) == b.prefix(2)
    }
}
