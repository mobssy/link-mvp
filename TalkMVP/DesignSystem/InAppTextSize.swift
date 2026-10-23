//
//  InAppTextSize.swift
//  TalkMVP
//

import SwiftUI
import UIKit

/// The text size the app shows: the system's, unless the person picked a size in the app's
/// Accessibility settings to use instead.
nonisolated enum InAppTextSize {
    static let stepKey = "inAppTextSizeStep"
    static let overridesKey = "inAppTextSizeOverridesSystem"
    /// The middle of the five steps, iOS's default size.
    static let defaultStep = 2
    static let steps = 0...4

    /// The size for a step of the in-app slider, smallest to largest.
    static func size(forStep step: Int) -> DynamicTypeSize {
        switch step {
        case 0: return .small
        case 1: return .medium
        case 3: return .xLarge
        case 4: return .xxLarge
        default: return .large
        }
    }

    /// Settles whether the in-app size replaces the system's for anyone who hasn't decided yet.
    /// Before this switch existed the in-app size always applied, so someone who had picked a
    /// size other than the default keeps it; everyone else follows the system.
    static func migrate(_ defaults: UserDefaults) {
        guard defaults.object(forKey: overridesKey) == nil else { return }
        let pickedSize = defaults.object(forKey: stepKey) != nil && defaults.integer(forKey: stepKey) != defaultStep
        defaults.set(pickedSize, forKey: overridesKey)
    }
}

/// Applies the in-app text size when it replaces the system's, and the system's otherwise.
///
/// It sets the size on the window scenes rather than with `.dynamicTypeSize` on the root view:
/// sheets take their text size from the window, so a view modifier never reached them.
struct InAppTextSizeModifier: ViewModifier {
    @AppStorage(InAppTextSize.stepKey) private var step = InAppTextSize.defaultStep
    @AppStorage(InAppTextSize.overridesKey) private var overridesSystem = false

    func body(content: Content) -> some View {
        content.onChange(of: overridesSystem ? step : nil, initial: true) { _, chosenStep in
            InAppTextSize.applyToWindows(chosenStep.map(InAppTextSize.size(forStep:)))
        }
    }
}

extension InAppTextSize {
    /// Overrides the text size of every window, or with nil hands it back to the system.
    @MainActor
    static func applyToWindows(_ size: DynamicTypeSize?) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            if let size {
                scene.traitOverrides.preferredContentSizeCategory = UIContentSizeCategory(size)
            } else {
                scene.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
            }
        }
    }
}

extension View {
    /// The text size from the app's Accessibility settings, or the system's.
    func inAppTextSize() -> some View {
        modifier(InAppTextSizeModifier())
    }
}
