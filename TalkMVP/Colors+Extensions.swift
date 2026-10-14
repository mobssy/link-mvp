//  Colors+Extensions.swift
//  TalkMVP
//
//  Convenience colors bridging UIKit label colors to SwiftUI.

import SwiftUI

extension Color {
    static var tertiaryLabel: Color { Color(UIColor.tertiaryLabel) }
    static let appPrimary = Color(red: 181/255, green: 199/255, blue: 235/255)
    /// A deeper shade of `appPrimary` for fills behind white text, such as a selected list
    /// row: white on `appPrimary` itself is too faint to read (about 1.6:1; this is 6.4:1).
    static let appPrimaryStrong = Color(red: 57/255, green: 92/255, blue: 172/255)
}

extension UIColor {
    static let appPrimary = UIColor(red: 181/255.0, green: 199/255.0, blue: 235/255.0, alpha: 1.0)
}
