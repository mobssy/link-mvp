//  Colors+Extensions.swift
//  TalkMVP
//
//  Convenience colors bridging UIKit label colors to SwiftUI.

import SwiftUI

extension Color {
    static var tertiaryLabel: Color { Color(UIColor.tertiaryLabel) }
    static let appPrimary = Color(red: 181/255, green: 199/255, blue: 235/255)
    /// A deeper shade of `appPrimary` for fills behind white text, such as a selected list
    /// row: white on `appPrimary` itself is too faint to read (about 1.7:1; this is 6.4:1).
    static let appPrimaryStrong = Color(red: 57/255, green: 92/255, blue: 172/255)
    /// Text and icons on `appPrimary`. The brand color is light in both appearances, so what sits
    /// on it has to be dark: white was about 1.7:1, this is about 10:1.
    static let onAppPrimary = Color(red: 21/255, green: 28/255, blue: 48/255)
    /// The brand color for text and tinted controls on the system background: `appPrimary` in
    /// dark mode, where it reads well, and `appPrimaryStrong` in light mode, where `appPrimary`
    /// on white is about 1.7:1.
    static let appPrimaryText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .appPrimary : UIColor(red: 57/255, green: 92/255, blue: 172/255, alpha: 1)
    })

    /// The fill of your own message bubbles. With high contrast on it is the label color, the
    /// strongest fill in either appearance.
    static func ownBubble(highContrast: Bool) -> Color {
        highContrast ? Color(UIColor.label) : .appPrimary
    }

    /// Text and icons on your own message bubbles.
    static func onOwnBubble(highContrast: Bool) -> Color {
        highContrast ? Color(UIColor.systemBackground) : .onAppPrimary
    }
}

/// The brand colors as shape styles, so `.foregroundStyle(.appPrimaryText)` reads like the
/// system colors do.
extension ShapeStyle where Self == Color {
    static var appPrimary: Color { Color.appPrimary }
    static var appPrimaryStrong: Color { Color.appPrimaryStrong }
    static var onAppPrimary: Color { Color.onAppPrimary }
    static var appPrimaryText: Color { Color.appPrimaryText }
    static var tertiaryLabel: Color { Color.tertiaryLabel }
}

extension UIColor {
    static let appPrimary = UIColor(red: 181/255.0, green: 199/255.0, blue: 235/255.0, alpha: 1.0)
}
