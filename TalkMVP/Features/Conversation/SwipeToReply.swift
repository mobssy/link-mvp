//
//  SwipeToReply.swift
//  TalkMVP
//
//  Swiping a message to the right to reply to it
//

import SwiftUI
import UIKit

extension View {
    /// Swiping the view to the right starts a reply.
    ///
    /// On iOS 27 that is a leading swipe action. On iOS 26 swipe actions only work in a List (the
    /// messages sit in a ScrollView), so the swipe went to iOS 26's back gesture and left the
    /// chat. There the message follows the finger instead, and letting go after a long enough
    /// swipe starts the reply.
    func swipeToReply(_ label: String, onReply: @escaping () -> Void) -> some View {
        modifier(SwipeToReply(label: label, onReply: onReply))
    }
}

private struct SwipeToReply: ViewModifier {
    let label: String
    let onReply: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var isArmed = false

    /// How far the message travels before letting go replies.
    private let threshold: CGFloat = 56

    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(label) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onReply()
                }
                // The action's fill, under white text: the deeper shade reads in both modes.
                .tint(.appPrimaryStrong)
            }
        } else {
            content
                .offset(x: offset)
                .background(alignment: .leading) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .foregroundStyle(Color.appPrimaryText)
                        .opacity(min(offset / threshold, 1))
                        .padding(.leading, 12)
                        .accessibilityHidden(true)
                }
                .gesture(RightwardPan(onChange: follow, onEnd: release))
        }
    }

    private func follow(_ distance: CGFloat) {
        offset = min(max(distance, 0), threshold * 1.4)
        if !isArmed, distance >= threshold {
            isArmed = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func release() {
        if isArmed { onReply() }
        isArmed = false
        withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) { offset = 0 }
    }
}

/// A pan that only begins when the finger starts moving to the right, more sideways than up or
/// down. A SwiftUI DragGesture on the messages, even a simultaneous one, kept the chat from
/// scrolling when a drag started on a bubble; this one fails at once for a vertical drag and
/// leaves it to the scroll view.
private struct RightwardPan: UIGestureRecognizerRepresentable {
    let onChange: (CGFloat) -> Void
    let onEnd: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed: onChange(recognizer.translation(in: recognizer.view).x)
        case .ended, .cancelled, .failed: onEnd()
        default: break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return velocity.x > 0 && velocity.x > abs(velocity.y) * 1.5
        }

        /// iOS 26's swipe back from anywhere in the content waits for this pan, so a swipe that
        /// starts on a message replies instead of leaving the chat. Elsewhere it still goes back.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            var responder: UIResponder? = gestureRecognizer.view
            while let current = responder, !(current is UIViewController) { responder = current.next }
            guard let navigation = (responder as? UIViewController)?.navigationController else { return false }
            return other === navigation.interactiveContentPopGestureRecognizer
        }
    }
}
