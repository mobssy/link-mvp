//
//  ChatView+Messages.swift
//  TalkMVP
//

import SwiftUI
import NaturalLanguage
import UIKit

extension ChatView {
    @ViewBuilder
    func chatContentView(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            messagesScrollView(viewModel: viewModel)
            Divider()
            messageInputView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    func messagesScrollView(viewModel: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    messagesList(viewModel: viewModel)

                    if viewModel.otherUserTyping {
                        TypingIndicatorView(senderName: chatRoom.name)
                            .id("typing_indicator")
                            .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                            .accessibilityLabel(String(format: localizedText("typing_indicator"), chatRoom.name))
                            .accessibilityIdentifier("typingIndicator")
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityLabel(localizedText("message_list"))
            .accessibilityHint(localizedText("scroll_messages_hint"))
            .accessibilityIdentifier("messagesScrollView")
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottomInline(proxy: proxy)
            }
            .onChange(of: viewModel.otherUserTyping) { _, isTyping in
                if isTyping {
                    scrollToBottomInline(proxy: proxy)
                }
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
        }
    }

    func scrollToBottomInline(proxy: ScrollViewProxy) {
        let animation: Animation = reduceMotion ?
            .easeInOut(duration: 0.1) :
            .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.2)

        if let lastMessage = viewModel?.messages.last {
            withAnimation(animation) {
                proxy.scrollTo(lastMessage.id, anchor: UnitPoint.bottom)
            }
        } else if viewModel?.otherUserTyping == true {
            withAnimation(animation) {
                proxy.scrollTo("typing_indicator", anchor: UnitPoint.bottom)
            }
        }
    }

    @ViewBuilder
    func messagesList(viewModel: ChatViewModel) -> some View {
        ForEach(filteredMessages(viewModel: viewModel), id: \.id) { message in
            MessageBubbleView(
                message: message,
                avatarSymbolName: chatRoom.profileImage,
                onAvatarTap: { openFriendProfile() }
            )
                .id(message.id)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("message_\(message.id)")
                .accessibilityLabel(accessibilityLabelForMessage(message))
                .accessibilityHint(localizedText("message_action_hint"))
                .onLongPressGesture {
                    showReactionPicker(for: message)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button(localizedText("reply")) {
                        replyingToMessage = message
                        isTextFieldFocused = true
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    .tint(.appPrimary)
                }
                .contextMenu {
                    if message.messageType == .text {
                        Button(localizedText("copy"), systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = message.text
                            UIAccessibility.post(notification: .announcement, argument: localizedText("copied_message"))
                        }
                    }
                    Button(localizedText("reply"), systemImage: "arrowshape.turn.up.left") {
                        replyingToMessage = message
                        isTextFieldFocused = true
                    }
                    Button(localizedText("add_reaction"), systemImage: "face.smiling") {
                        showReactionPicker(for: message)
                    }
                    Button(
                        message.isBookmarked
                            ? (languageManager.currentLanguage == .korean ? "북마크 해제" : "Remove Bookmark")
                            : (languageManager.currentLanguage == .korean ? "북마크" : "Bookmark"),
                        systemImage: message.isBookmarked ? "bookmark.slash" : "bookmark"
                    ) {
                        toggleBookmark(message)
                    }
                    if message.isFromCurrentUser {
                        Button(localizedText("edit"), systemImage: "pencil") {
                            startEditingMessage(message)
                        }
                        Divider()
                        Button(localizedText("delete_for_me"), systemImage: "trash") {
                            deleteMessageForMe(message)
                        }
                        Button(localizedText("delete_for_everyone"), systemImage: "trash.fill", role: .destructive) {
                            deleteMessageForEveryone(message)
                        }
                    } else {
                        Button(localizedText("delete_for_me"), systemImage: "trash") {
                            deleteMessageForMe(message)
                        }
                        Divider()
                        Button(localizedText("report"), systemImage: "exclamationmark.bubble") {
                            showingReportAlert = true
                        }
                        Button(localizedText("block"), systemImage: "hand.raised") {
                            showingBlockAlert = true
                        }
                    }
                }
            if message.messageType == .text, let url = firstURL(in: message.text) {
                LinkPreviewView(url: url)
                    .frame(maxWidth: .infinity, alignment: message.isFromCurrentUser ? Alignment.trailing : Alignment.leading)
                    .padding(.horizontal, 2)
            }
            if !message.isFromCurrentUser && message.messageType == .text && shouldShowTranslation(for: message.text) {
                TranslatedTextView(
                    text: message.text,
                    autoDetect: translationAutoDetect,
                    target: effectiveTargetLanguage(for: message.text),
                    showOriginal: translationShowOriginal
                )
                .frame(maxWidth: .infinity, alignment: message.isFromCurrentUser ? .trailing : .leading)
                .padding(.horizontal, 2)
                .environmentObject(languageManager)
            }
        }
    }

    func containsHangul(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            let value = scalar.value
            return (0xAC00...0xD7A3).contains(value)
        }
    }

    func detectLanguageCode(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let lang = recognizer.dominantLanguage {
            return normalizeLanguageCode(lang.rawValue.lowercased())
        }
        return nil
    }

    func normalizeLanguageCode(_ code: String) -> String {
        switch code {
        case "zh-hans", "zh_cn", "zh": return "zh-Hans"
        case "zh-hant", "zh_tw": return "zh-Hant"
        default: return code
        }
    }

    func appLanguageCode() -> String {
        switch languageManager.currentLanguage {
        case .korean: return "ko"
        case .english: return "en"
        case .japanese: return "ja"
        case .chinese: return "zh-Hans"
        case .chineseTraditional: return "zh-Hant"
        case .spanish: return "es"
        }
    }

    func shouldShowTranslation(for text: String) -> Bool {
        guard translationEnabled else { return false }

        let source = detectLanguageCode(for: text) ?? ""
        let target = effectiveTargetLanguage(for: text).lowercased()
        if !source.isEmpty {
            return source != target
        } else {
            if languageManager.currentLanguage != .korean && containsHangul(text) { return true }
            return false
        }
    }

    func filteredMessages(viewModel: ChatViewModel) -> [Message] {
        guard aiSearchEnabled, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return viewModel.messages
        }
        let query = searchText.lowercased()
        return viewModel.messages.filter { msg in
            switch msg.messageType {
            case .text, .file:
                return msg.text.lowercased().contains(query)
            case .image, .audio, .video:
                return false
            case .deleted:
                return false
            }
        }
    }

    func effectiveTargetLanguage(for text: String) -> String {
        let target = translationTargetLanguage.lowercased()
        if target != "auto" { return target }
        return appLanguageCode()
    }
}
