//
//  ChatViewAlertModifiers.swift
//  TalkMVP
//
//  Created by Claude Code
//

import SwiftUI

// MARK: - Alert Modifiers
// Single Responsibility: Alert UI 표시만 담당
// Open/Closed: 새로운 Alert 타입 추가 시 새 struct만 추가하면 됨

/// 메시지 편집 Alert
struct EditMessageAlertModifier: ViewModifier {
    let localizationService: LocalizationServiceProtocol
    let language: Language

    @Binding var isPresented: Bool
    @Binding var editingText: String
    @Binding var editingMessage: Message?
    let onSave: (Message, String) -> Void

    init(
        isPresented: Binding<Bool>,
        editingText: Binding<String>,
        editingMessage: Binding<Message?>,
        onSave: @escaping (Message, String) -> Void,
        localizationService: LocalizationServiceProtocol = LocalizationService.shared,
        language: Language
    ) {
        self._isPresented = isPresented
        self._editingText = editingText
        self._editingMessage = editingMessage
        self.onSave = onSave
        self.localizationService = localizationService
        self.language = language
    }

    func body(content: Content) -> some View {
        content.alert(localizedAlertText(.edit, language) + " " + localizedAlertText(.message, language), isPresented: $isPresented) {
            TextField(localizedAlertText(.message, language), text: $editingText)
            Button(localizedAlertText(.cancel, language), role: .cancel) {
                editingMessage = nil
                editingText = ""
            }
            Button(localizedAlertText(.save, language)) {
                if let message = editingMessage {
                    let newText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !newText.isEmpty {
                        onSave(message, newText)
                    }
                }
                editingMessage = nil
                editingText = ""
                UIAccessibility.post(notification: .announcement, argument: localizedAlertText(.editedMessageAnnouncement, language))
            }
        } message: {
            Text(localizedAlertText(.editMessagePrompt, language))
        }
    }
}

/// 긴급 호출 Alert
struct EmergencyAlertModifier: ViewModifier {
    let localizationService: LocalizationServiceProtocol
    let language: Language
    @Binding var isPresented: Bool

    init(
        isPresented: Binding<Bool>,
        localizationService: LocalizationServiceProtocol = LocalizationService.shared,
        language: Language
    ) {
        self._isPresented = isPresented
        self.localizationService = localizationService
        self.language = language
    }

    func body(content: Content) -> some View {
        content.alert(localizedAlertText(.emergencyCall, language), isPresented: $isPresented) {
            Button(localizedAlertText(.ok, language)) {}
        } message: {
            Text(localizedAlertText(.emergencyStarted, language))
        }
    }
}

/// 위치 권한 Alert
struct LocationPermissionAlertModifier: ViewModifier {
    let localizationService: LocalizationServiceProtocol
    let language: Language
    @Binding var isPresented: Bool
    let openSettings: () -> Void

    init(
        isPresented: Binding<Bool>,
        openSettings: @escaping () -> Void,
        localizationService: LocalizationServiceProtocol = LocalizationService.shared,
        language: Language
    ) {
        self._isPresented = isPresented
        self.openSettings = openSettings
        self.localizationService = localizationService
        self.language = language
    }

    func body(content: Content) -> some View {
        content.alert(localizedAlertText(.locationPermissionTitle, language), isPresented: $isPresented) {
            Button(localizedAlertText(.cancel, language), role: .cancel) {}
            Button(localizedAlertText(.openSettings, language)) { openSettings() }
        } message: {
            Text(localizedAlertText(.locationPermissionMessage, language))
        }
    }
}

/// 신고 Alert
struct ReportAlertModifier: ViewModifier {
    let localizationService: LocalizationServiceProtocol
    let language: Language
    @Binding var isPresented: Bool
    let name: String

    init(
        isPresented: Binding<Bool>,
        name: String,
        localizationService: LocalizationServiceProtocol = LocalizationService.shared,
        language: Language
    ) {
        self._isPresented = isPresented
        self.name = name
        self.localizationService = localizationService
        self.language = language
    }

    func body(content: Content) -> some View {
        content.alert(localizedAlertText(.reportUser, language), isPresented: $isPresented) {
            Button(localizedAlertText(.ok, language), role: .cancel) {}
        } message: {
            Text(String(format: localizedAlertText(.reportedUserMessage, language), name))
        }
    }
}

/// 차단 Alert
struct BlockAlertModifier: ViewModifier {
    let localizationService: LocalizationServiceProtocol
    let language: Language
    @Binding var isPresented: Bool
    let name: String
    let onBlock: () -> Void

    init(
        isPresented: Binding<Bool>,
        name: String,
        onBlock: @escaping () -> Void,
        localizationService: LocalizationServiceProtocol = LocalizationService.shared,
        language: Language
    ) {
        self._isPresented = isPresented
        self.name = name
        self.onBlock = onBlock
        self.localizationService = localizationService
        self.language = language
    }

    func body(content: Content) -> some View {
        content.alert(localizedAlertText(.blockUser, language), isPresented: $isPresented) {
            Button(localizedAlertText(.cancel, language), role: .cancel) {}
            Button(localizedAlertText(.block, language), role: .destructive) {
                onBlock()
            }
        } message: {
            Text(String(format: localizedAlertText(.blockedUserMessage, language), name))
        }
    }
}

/// 의심스러운 링크 Alert
struct SuspiciousLinkAlertModifier: ViewModifier {
    let localizationService: LocalizationServiceProtocol
    let language: Language
    @Binding var isPresented: Bool
    @Binding var linkToVerify: String?
    @Binding var ignoredDomains: Set<String>
    let openURL: (URL) -> Void

    init(
        isPresented: Binding<Bool>,
        linkToVerify: Binding<String?>,
        ignoredDomains: Binding<Set<String>>,
        openURL: @escaping (URL) -> Void,
        localizationService: LocalizationServiceProtocol = LocalizationService.shared,
        language: Language
    ) {
        self._isPresented = isPresented
        self._linkToVerify = linkToVerify
        self._ignoredDomains = ignoredDomains
        self.openURL = openURL
        self.localizationService = localizationService
        self.language = language
    }

    func body(content: Content) -> some View {
        content.alert(localizedAlertText(.unverifiedInfo, language), isPresented: $isPresented) {
            Button(localizedAlertText(.cancel, language), role: .cancel) {}
            if let link = linkToVerify, let url = URL(string: link) {
                Button(localizedAlertText(.open, language)) { openURL(url) }
                if let host = url.host {
                    Button(localizedAlertText(.alwaysAllow, language)) {
                        ignoredDomains.insert(host)
                        UserDefaults.standard.set(Array(ignoredDomains), forKey: "ignoredDomains")
                    }
                }
            }
        } message: {
            Text(linkToVerify ?? localizedAlertText(.suspiciousLinkDetected, language))
        }
    }
}

// MARK: - Compound Alert Modifier
/// Combines all alert modifiers to reduce type-checking complexity
struct CompoundAlertModifier: ViewModifier {
    @Binding var showingEditAlert: Bool
    @Binding var editingText: String
    @Binding var editingMessage: Message?
    @Binding var showingEmergencyAlert: Bool
    @Binding var showingLocationPermissionAlert: Bool
    @Binding var showingReportAlert: Bool
    @Binding var showingBlockAlert: Bool
    @Binding var suspiciousLinkDetected: Bool
    @Binding var linkToVerify: String?
    @Binding var ignoredDomains: Set<String>

    let chatRoomName: String
    let openURL: (URL) -> Void
    let onEditSave: (Message, String) -> Void
    let onBlock: () -> Void

    @EnvironmentObject private var languageManager: LanguageManager

    private var language: Language {
        languageManager.currentLanguage == .korean ? .korean : .english
    }

    func body(content: Content) -> some View {
        content
            .modifier(EditMessageAlertModifier(
                isPresented: $showingEditAlert,
                editingText: $editingText,
                editingMessage: $editingMessage,
                onSave: onEditSave,
                language: language
            ))
            .modifier(EmergencyAlertModifier(
                isPresented: $showingEmergencyAlert,
                language: language
            ))
            .modifier(LocationPermissionAlertModifier(
                isPresented: $showingLocationPermissionAlert,
                openSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                },
                language: language
            ))
            .modifier(ReportAlertModifier(
                isPresented: $showingReportAlert,
                name: chatRoomName,
                language: language
            ))
            .modifier(BlockAlertModifier(
                isPresented: $showingBlockAlert,
                name: chatRoomName,
                onBlock: onBlock,
                language: language
            ))
            .modifier(SuspiciousLinkAlertModifier(
                isPresented: $suspiciousLinkDetected,
                linkToVerify: $linkToVerify,
                ignoredDomains: $ignoredDomains,
                openURL: openURL,
                language: language
            ))
    }
}

// MARK: - Localization Helper for Alerts
// Private helper to avoid conflict with global L10n
private func localizedAlertText(_ key: LocalizationKey, _ language: Language) -> String {
    return LocalizationService.shared.text(for: key, language: language)
}
