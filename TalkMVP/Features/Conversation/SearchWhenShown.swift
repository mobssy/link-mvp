//
//  SearchWhenShown.swift
//  TalkMVP
//

import SwiftUI

/// Puts a search field under the title only while `isShown`, so the conversation has the screen
/// the rest of the time. Cancelling hides it again and clears the search.
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
    }
}
