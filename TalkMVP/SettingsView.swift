// MARK: - Extracted Sections to help the compiler

import SwiftUI
import UIKit
extension SettingsView {
    @ViewBuilder
    var destructiveSection: some View {
        Section {
            VStack(spacing: 0) {
                Button(localizedText("delete_account"), role: .destructive) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    showingDeleteAlert = true
                }
                .frame(maxWidth: .infinity)
                .font(.headline)
                .accessibilityLabel(Text(localizedText("delete_account")))
                .accessibilityHint(Text(localizedText("delete_account_hint")))
                .padding(.vertical, 12)

                // Custom divider to avoid clipped system separator
                Divider()
                    .frame(height: 0.5)
                    .overlay(Color(UIColor.separator))
                    .padding(.horizontal, 16)

                Button(localizedText("logout")) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    showingLogoutAlert = true
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .font(.headline)
                .accessibilityLabel(Text(localizedText("logout")))
                .accessibilityHint(Text(localizedText("logout_hint")))
                .padding(.vertical, 12)
            }
            // Hide the default list separator for this one section row
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
}

