//
//  LanguageManager+Extensions.swift
//  TalkMVP
//
//  Centralized helpers for language checks to reduce duplication.
//

import Foundation

extension LanguageManager.Language {
    /// Converts to the LocalizationService.Language type used in ChatView helpers.
    var asLocalizationLanguage: Language {
        switch self {
        case .korean:            return .korean
        case .english:           return .english
        case .japanese:          return .japanese
        case .chinese,
             .chineseTraditional: return .chinese
        case .spanish:           return .spanish
        }
    }
}

extension LanguageManager {
    /// Reads the persisted language code from UserDefaults.
    /// Use this in non-View contexts (ViewModels, services) that cannot access the @EnvironmentObject.
    static var currentLanguageCode: String {
        if let saved = UserDefaults.standard.string(forKey: "selectedLanguage") { return saved }
        if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String], let first = langs.first { return first }
        return "en"
    }

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
