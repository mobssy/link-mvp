//
//  ChatViewSupportingViews.swift
//  TalkMVP
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import Combine
import PhotosUI
import UniformTypeIdentifiers
import LinkPresentation
import CoreLocation
import os

private let supportingViewsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatView.Supporting")

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .plainText, .image, .audio, .video, .data
        ])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void

        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}

// MARK: - Photo Picker

struct PhotoPickerView: UIViewControllerRepresentable {
    let onComplete: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            parent.onComplete(results)
        }
    }
}

// MARK: - Reaction Picker View

struct ReactionPickerView: View {
    @Environment(LanguageManager.self) private var languageManager

    let message: Message?
    let onReactionSelected: (String) -> Void

    private let reactions = ["👍", "❤️", "😂", "😮", "😢", "😡", "👏", "🎉"]

    var body: some View {
        VStack(spacing: 16) {
            Text(LocalizationService.shared.text(for: .addReaction, language: currentLanguage))
                .font(.headline)
                .foregroundStyle(Color.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(reactions, id: \.self) { emoji in
                    Button(action: {
                        onReactionSelected(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 60, height: 60)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(reactionLabel(emoji))
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding()
    }

    private var currentLanguage: Language {
        languageManager.currentLanguage.asLocalizationLanguage
    }

    private func reactionLabel(_ emoji: String) -> String {
        let prefix = currentLanguage == .korean ? "반응: " : "Reaction: "
        return prefix + emoji
    }
}

// MARK: - Link Preview View

struct LinkPreviewView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(url: url)
        view.setContentHuggingPriority(.defaultHigh, for: .vertical)
        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.fetch(url: url, into: view)
        return view
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {}

    final class Coordinator {
        private var fetch: Task<Void, Never>?

        deinit { fetch?.cancel() }

        func fetch(url: URL, into view: LPLinkView) {
            fetch = Task {
                guard let metadata = try? await LPMetadataProvider().startFetchingMetadata(for: url) else { return }
                view.metadata = metadata
            }
        }
    }
}

// MARK: - Translated Text View

struct TranslatedTextView: View {
    @Environment(LanguageManager.self) private var languageManager

    let text: String
    let autoDetect: Bool
    let target: String
    let showOriginal: Bool

    /// nil once a try came back empty-handed: no translator on this device could translate it.
    @State private var translated: String?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(isLoading
                     ? LocalizationService.shared.text(for: .translatingEllipsis, language: currentLanguage)
                     : translated ?? LocalizationService.shared.text(for: .translationUnavailable, language: currentLanguage))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showOriginal {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.tertiaryLabel)
            }
        }
        .onAppear(perform: translate)
        .onChange(of: text) { _, _ in translate() }
    }

    private var currentLanguage: Language {
        languageManager.currentLanguage.asLocalizationLanguage
    }

    private func translate() {
        isLoading = true
        Task {
            let result = await AIService.shared.translate(text, autoDetect: autoDetect, target: target)
            await MainActor.run {
                self.translated = result
                self.isLoading = false
            }
        }
    }
}

// MARK: - Mini Profile Sheet

struct MiniProfileSheet: View {
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.dismiss) private var dismiss

    let name: String
    let symbol: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 64))
                    .foregroundStyle(.appPrimaryText)
                    .padding(.top, 20)
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(LocalizationService.shared.text(for: .profileInfoUnavailable, language: currentLanguage))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle(LocalizationService.shared.text(for: .profile, language: currentLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizationService.shared.text(for: .close, language: currentLanguage)) { dismiss() }
                }
            }
        }
    }

    private var currentLanguage: Language {
        languageManager.currentLanguage.asLocalizationLanguage
    }
}

// MARK: - Attachment Preview View

struct AttachmentPreviewView: View {
    let attachment: PendingAttachment?
    let onSend: () -> Void
    let onCancel: () -> Void

    @Environment(LanguageManager.self) private var languageManager
    @State private var captionText: String = ""
    @FocusState private var isCaptionFocused: Bool

    var body: some View {
        ZStack {
            // 배경 (검정색)
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 네비게이션
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(LocalizationService.shared.text(for: .cancelAttachment, language: currentLanguage))

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // 중앙 컨텐츠 (사진/동영상/파일)
                if let attachment = attachment {
                    Spacer()

                    GeometryReader { geometry in
                        attachmentContentView(attachment, geometry: geometry)
                    }

                    Spacer()

                    // 하단 입력 영역
                    bottomInputView
                } else {
                    Spacer()
                    Text(LocalizationService.shared.text(for: .noAttachment, language: currentLanguage))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func attachmentContentView(_ attachment: PendingAttachment, geometry: GeometryProxy) -> some View {
        switch attachment {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()

        case .video:
            ZStack {
                Color.black.opacity(0.5)

                VStack(spacing: 20) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)

                    Text(LocalizationService.shared.text(for: .video, language: currentLanguage))
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)

        case .document(_, let fileName, let fileSize, let ext):
            ZStack {
                Color.black.opacity(0.8)

                VStack(spacing: 24) {
                    Image(systemName: AttachmentHandler.fileIcon(for: ext ?? ""))
                        .font(.system(size: 100))
                        .foregroundStyle(.white)

                    VStack(spacing: 12) {
                        Text(fileName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        Text(AttachmentHandler.formatFileSize(fileSize))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var bottomInputView: some View {
        VStack(spacing: 0) {
            // 구분선
            Divider()
                .background(Color.white.opacity(0.2))

            HStack(alignment: .bottom, spacing: 12) {
                // 텍스트 입력 필드
                ZStack(alignment: .leading) {
                    if captionText.isEmpty {
                        Text(LocalizationService.shared.text(for: .addCaption, language: currentLanguage))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }

                    TextField("", text: $captionText)
                        .focused($isCaptionFocused)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                        )
                }

                // 보내기 버튼
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.appPrimaryText)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel(LocalizationService.shared.text(for: .sendAttachment, language: currentLanguage))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.9))
        }
    }

    private var currentLanguage: Language {
        languageManager.currentLanguage.asLocalizationLanguage
    }
}

// MARK: - Summary Paragraph Card

struct SummaryParagraphCard: View {
    let text: String

    private var isHeader: Bool {
        text.hasPrefix("📊") || text.hasPrefix("📝") || text.hasPrefix("🧠")
    }

    private var renderedText: Text {
        // Inline-only parsing keeps line breaks; full Markdown folds a section's bullet lines
        // into one line ("Key Topics: • Weather • Well-being • Weekend plans").
        if let attr = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attr)
        }
        return Text(text)
    }

    var body: some View {
        if isHeader {
            renderedText
                .font(.title3.bold())
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
        } else {
            renderedText
                .font(.body)
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
        }
    }
}
