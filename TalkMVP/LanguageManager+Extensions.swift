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
}
