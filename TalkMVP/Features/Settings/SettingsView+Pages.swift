//
//  SettingsView+Pages.swift
//  TalkMVP
//

import SwiftUI

/// The pages the Settings list opens, as navigation values: the split view puts the chosen one
/// in its detail column, or pushes it when collapsed.
enum SettingsPage: Hashable {
    case theme, language, appLock, aiFeatures, translation, contacts, accessibility
    case help, appInfo, terms
}

extension SettingsView {
    @ViewBuilder
    func destination(for page: SettingsPage) -> some View {
        switch page {
        case .theme: ThemeSettingsView()
        case .language: LanguageSettingsView()
        case .appLock: SecuritySettingsView()
        case .aiFeatures: AISettingsView()
        case .translation: TranslationSettingsView()
        case .contacts: ContactsSettingsView()
        case .accessibility: AccessibilitySettingsView()
        case .help: HelpView()
        case .appInfo: AppInfoView()
        case .terms: TermsPoliciesView()
        }
    }
}
