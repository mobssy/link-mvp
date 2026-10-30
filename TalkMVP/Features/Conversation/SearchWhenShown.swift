//
//  SearchWhenShown.swift
//  TalkMVP
//

import SwiftUI

/// Puts a search field under the title only while `isShown`, so the conversation has the screen
/// the rest of the time. Closing it, or leaving it empty (on iPad, where the field takes the
/// title's place and has no Close button), hides it again and clears the search.
struct SearchWhenShown: ViewModifier {
    @Binding var text: String
    @Binding var isShown: Bool
    let prompt: String
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        Group {
            if isShown {
                content
                    .searchable(text: $text, isPresented: $isShown, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
                    .searchFocused($isFocused)
                    // Asked for, so ready to type into.
                    .task { isFocused = true }
            } else {
                content
            }
        }
        .onChange(of: isShown) { _, shown in
            if !shown { text = "" }
        }
        .onChange(of: isFocused) { wasFocused, focused in
            // Only once it had the keyboard: a field that never got it isn't being left.
            if wasFocused && !focused && text.isEmpty { isShown = false }
        }
    }
}
