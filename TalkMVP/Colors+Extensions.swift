//  Colors+Extensions.swift
//  TalkMVP
//
//  Convenience colors bridging UIKit label colors to SwiftUI.

import SwiftUI

extension Color {
    static var tertiaryLabel: Color { Color(UIColor.tertiaryLabel) }
    static let appPrimary = Color(red: 181/255, green: 199/255, blue: 235/255)
}

// MARK: - Glass Effect Modifier
struct GlassEffect: ViewModifier {
    let style: GlassStyle
    let shape: GlassShape
    
    enum GlassStyle {
        case regular
        case thin
        case thick
        
        var opacity: Double {
            switch self {
            case .regular: return 0.1
            case .thin: return 0.05
            case .thick: return 0.2
            }
        }
    }
    
    enum GlassShape {
        case rect(cornerRadius: CGFloat)
        case circle
        case capsule
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    switch shape {
                    case .rect(let cornerRadius):
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                            .opacity(style.opacity)
                    case .circle:
                        Circle()
                            .fill(.ultraThinMaterial)
                            .opacity(style.opacity)
                    case .capsule:
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .opacity(style.opacity)
                    }
                }
            )
    }
}

extension GlassEffect.GlassStyle {
    func tint(_ color: Color) -> GlassEffect.GlassStyle {
        return self
    }
    
    func interactive() -> GlassEffect.GlassStyle {
        return self
    }
}

extension View {
    func glassEffect(_ style: GlassEffect.GlassStyle = .regular, in shape: GlassEffect.GlassShape = .rect(cornerRadius: 12)) -> some View {
        self.modifier(GlassEffect(style: style, shape: shape))
    }
}

extension UIColor {
    static let appPrimary = UIColor(red: 181/255.0, green: 199/255.0, blue: 235/255.0, alpha: 1.0)
}
