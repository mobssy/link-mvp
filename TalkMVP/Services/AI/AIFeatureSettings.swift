//
//  AIFeatureSettings.swift
//  TalkMVP
//
//  The switches in Settings → AI Features
//

import Foundation

/// One switch in Settings → AI Features: where it is stored and what it is until changed.
nonisolated struct AIFeatureSwitch: Sendable {
    let key: String
    let defaultValue: Bool

    /// The current value, for code that can't use `@AppStorage`.
    var isOn: Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue }
}

/// Every AI feature switch, shared by the settings screen and the chat that reads them, so a
/// key or a default can't drift between the two. All start on: a feature hidden behind a switch
/// nobody opens is one nobody trying the app sees.
nonisolated enum AIFeatureSettings {
    static let summary = AIFeatureSwitch(key: "aiSummaryEnabled", defaultValue: true)
    static let search = AIFeatureSwitch(key: "aiSearchEnabled", defaultValue: true)
    /// The key predates the notes being opened on demand rather than written automatically.
    static let meetingNotes = AIFeatureSwitch(key: "aiAutoMeetingNotesEnabled", defaultValue: true)
    static let replySuggestions = AIFeatureSwitch(key: "aiReplySuggestionsEnabled", defaultValue: true)
}
