//  Colors+Extensions.swift
//  TalkMVP
//
//  Convenience colors bridging UIKit label colors to SwiftUI.

import SwiftUI

extension Color {
    static var tertiaryLabel: Color { Color(UIColor.tertiaryLabel) }
    static let appPrimary = Color(red: 181/255, green: 199/255, blue: 235/255)
}

extension UIColor {
    static let appPrimary = UIColor(red: 181/255.0, green: 199/255.0, blue: 235/255.0, alpha: 1.0)
}
