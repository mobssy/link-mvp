//
//  TranslationPreferences.swift
//  TalkMVP
//

import Foundation

/// Whether messages in another language are translated.
nonisolated enum TranslationPreferences {
    static let enabledKey = "translationEnabled"
    /// On until someone turns it off: translation is what the app is for, and a first look
    /// shouldn't depend on finding it in Settings.
    static let enabledByDefault = true

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? enabledByDefault
    }

    /// Whether a chat translates: its own choice, or the app's setting when it hasn't made one.
    static func isOn(inChat choice: Bool?, appSetting: Bool) -> Bool {
        choice ?? appSetting
    }
}
