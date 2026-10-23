//
//  FullScreenImageView.swift
//  TalkMVP
//

import SwiftUI

struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .padding(16)
            }
            .accessibilityLabel(L10n.text("close", languageManager.currentLanguage))
        }
    }
}
