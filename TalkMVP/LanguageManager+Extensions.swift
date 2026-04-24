//
//  LanguageManager+Extensions.swift
//  TalkMVP
//
//  Centralized helpers for language checks to reduce duplication.
//

import Foundation

extension LanguageManager {
    /// Convenience flag for checking if the current app language is Korean.
    var isKorean: Bool { currentLanguage == .korean }

    /// Convenience flag for checking if the current app language is Japanese.
    var isJapanese: Bool { currentLanguage == .japanese }

    /// Convenience flag for checking if the current app language is Chinese (Simplified).
    var isChinese: Bool { currentLanguage == .chinese }

    /// Convenience flag for checking if the current app language is Chinese (Traditional).
    var isChineseTraditional: Bool { currentLanguage == .chineseTraditional }

    /// Convenience flag for checking if the current app language is Spanish.
    var isSpanish: Bool { currentLanguage == .spanish }

    /// Converts the current LanguageManager.Language to AppLanguage for use with L10n helpers.
    var appLanguage: AppLanguage {
        switch currentLanguage {
        case .korean: return .korean
        case .english: return .english
        case .japanese: return .japanese
        case .chinese: return .chinese
        case .chineseTraditional: return .chinese
        case .spanish: return .spanish
        }
    }
}
