//
//  AccessibilityPreferences.swift
//  TalkMVP
//

import SwiftUI

/// The app's own accessibility switches add to the system's: each applies when either the iOS
/// setting or the in-app switch is on, never one in place of the other.
nonisolated struct AccessibilityPreferences: Equatable {
    static let boldTextKey = "inAppBoldText"
    static let reduceMotionKey = "inAppReduceMotion"
    static let highContrastKey = "inAppHighContrast"

    var systemReducesMotion = false
    var inAppReducesMotion = false
    var systemIncreasesContrast = false
    var inAppHighContrast = false

    var reducesMotion: Bool { systemReducesMotion || inAppReducesMotion }
    var highContrast: Bool { systemIncreasesContrast || inAppHighContrast }
}

extension EnvironmentValues {
    /// Reduce Motion from iOS Settings or from the app's Accessibility settings. Read this rather
    /// than `accessibilityReduceMotion`, which only knows the system's.
    @Entry var prefersReducedMotion = false
    /// Increase Contrast from iOS Settings or the app's High Contrast Bubbles switch.
    @Entry var prefersHighContrast = false
}

/// Works out the combined preferences once, at the top of the app, for every view below.
struct AccessibilityPreferencesModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemReducesMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @AppStorage(AccessibilityPreferences.boldTextKey) private var boldText = false
    @AppStorage(AccessibilityPreferences.reduceMotionKey) private var inAppReducesMotion = false
    @AppStorage(AccessibilityPreferences.highContrastKey) private var inAppHighContrast = false

    func body(content: Content) -> some View {
        let preferences = AccessibilityPreferences(
            systemReducesMotion: systemReducesMotion,
            inAppReducesMotion: inAppReducesMotion,
            systemIncreasesContrast: contrast == .increased,
            inAppHighContrast: inAppHighContrast
        )
        content
            .environment(\.prefersReducedMotion, preferences.reducesMotion)
            .environment(\.prefersHighContrast, preferences.highContrast)
            // Nil when off, so the system's Bold Text and each font's own weight still apply.
            .fontWeight(boldText ? .bold : nil)
    }
}

extension View {
    /// Applies the app's accessibility switches together with the system's.
    func accessibilityPreferences() -> some View {
        modifier(AccessibilityPreferencesModifier())
    }
}
