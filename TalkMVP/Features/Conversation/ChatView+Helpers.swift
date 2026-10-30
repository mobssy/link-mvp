//
//  ChatView+Helpers.swift
//  TalkMVP
//

import SwiftUI
import SwiftData
import UIKit
import os

private let helpersLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "ChatView")

extension ChatView {
    func setupViewModelIfNeeded() {
        chatService.modelContext = modelContext

        if viewModel == nil {
            let vm = ChatViewModel(modelContext: modelContext, chatRoom: chatRoom, chatService: chatService)
            viewModel = vm
        } else {
            Task {
                await viewModel?.loadMessages()
            }
        }
    }

    /// The name VoiceOver reads before a message: the reader's own label for their messages,
    /// otherwise the sender shown above the bubble. In a group the room's name isn't who wrote
    /// the message, so it only stands in when a message has no sender.
    static func spokenSender(isFromCurrentUser: Bool, sender: String, roomName: String, meLabel: String) -> String {
        if isFromCurrentUser { return meLabel }
        let name = sender.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? roomName : name
    }

    func accessibilityLabelForMessage(_ message: Message) -> String {
        let sender = Self.spokenSender(
            isFromCurrentUser: message.isFromCurrentUser,
            sender: message.sender,
            roomName: chatRoom.name,
            meLabel: localizedText("me")
        )
        let time = Self.timeFormatter.string(from: message.timestamp)
        let lang: Language = languageManager.currentLanguage.asLocalizationLanguage
        let svc = LocalizationService.shared

        let contentLabel: String
        switch message.messageType {
        case .text:
            // The translation is part of the message, so it is read with it, while it is shown.
            contentLabel = translatedTexts[message.id].flatMap { translation(for: message) == nil ? nil : $0 }.map {
                "\(message.text). \(svc.text(for: .translated, language: lang)): \($0)"
            } ?? message.text
        case .image:
            contentLabel = [svc.text(for: .photoMessage, language: lang), message.imageDescription]
                .compactMap { $0 }
                .joined(separator: ": ")
        case .video:
            contentLabel = svc.text(for: .videoMessage, language: lang)
        case .audio:
            // The row's label replaces its children's, so the transcript has to be read out here.
            contentLabel = [svc.text(for: .audioMessageLabel, language: lang), message.transcript]
                .compactMap { $0 }
                .joined(separator: ": ")
        case .file:
            let fileName = message.fileName ?? svc.text(for: .fileMessage, language: lang)
            contentLabel = "\(svc.text(for: .fileMessage, language: lang)): \(fileName)"
        case .deleted:
            contentLabel = svc.text(for: .deletedMessageLabel, language: lang)
        case .location:
            contentLabel = svc.text(for: .locationMessageLabel, language: lang)
        }

        let readStatus: String
        if message.isFromCurrentUser {
            readStatus = message.isRead
                ? ", \(svc.text(for: .messageRead, language: lang))"
                : ", \(svc.text(for: .messageUnread, language: lang))"
        } else {
            readStatus = ""
        }

        return "\(sender): \(contentLabel), \(time)\(readStatus)"
    }

    func showReactionPicker(for message: Message) {
        reactionToMessage = message
        showingReactionPicker = true
    }

    func startEditingMessage(_ message: Message) {
        editingMessage = message
        editingText = message.text
        showingEditAlert = true
    }

    func deleteMessageForMe(_ message: Message) {
        viewModel?.deleteMessage(message, forEveryone: false)
    }

    func deleteMessageForEveryone(_ message: Message) {
        viewModel?.deleteMessage(message, forEveryone: true)
    }

    func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector?.matches(in: text, options: [], range: range)
        return matches?.first?.url
    }

    func addReaction(emoji: String, to message: Message) {
        guard let currentUserId = getCurrentUserId() else {
            helpersLogger.error("Cannot add reaction: no current user")
            return
        }

        viewModel?.addReaction(emoji, to: message, from: currentUserId)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let announcement = languageManager.localize(
            ko: "반응 \(emoji)를 추가했습니다",
            en: "Added reaction \(emoji)",
            ja: "リアクション \(emoji) を追加しました",
            zh: "添加了反应 \(emoji)",
            es: "Reacción \(emoji) añadida"
        )
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    // MARK: - Bookmarks

    func toggleBookmark(_ message: Message) {
        viewModel?.toggleBookmark(message)
        let label = message.isBookmarked
            ? languageManager.localize(ko: "북마크 추가됨", en: "Bookmarked", ja: "ブックマーク済み", zh: "已收藏", es: "Marcado")
            : languageManager.localize(ko: "북마크 해제됨", en: "Bookmark removed", ja: "ブックマーク解除", zh: "已取消收藏", es: "Marcador eliminado")
        UIAccessibility.post(notification: .announcement, argument: label)
    }

    // MARK: - Disappearing Messages

    func checkDisappearingMessages() {
        guard let vm = viewModel else { return }
        let now = Date()
        let expired = vm.messages.filter { msg in
            guard msg.isDisappearing, msg.disappearAfterSeconds > 0 else { return false }
            return now >= msg.timestamp.addingTimeInterval(TimeInterval(msg.disappearAfterSeconds))
        }
        guard !expired.isEmpty else { return }
        let expiredIds = Set(expired.map { $0.id })

        if reduceMotion {
            vm.deleteExpiredMessages(expired)
            return
        }

        // Phase 1: bounce up (통통 튀기)
        withAnimation(.spring(response: 0.12, dampingFraction: 0.35)) {
            poppingMessageIds.formUnion(expiredIds)
        }

        // Phase 2: shrink to nothing after bounce peaks
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.16)) {
                    vm.messages.removeAll { expiredIds.contains($0.id) }
                    poppingMessageIds.subtract(expiredIds)
                }
                vm.deleteExpiredMessages(expired)
            }
        }
    }

    // MARK: - Scheduled Send

    func scheduleMessage(viewModel: ChatViewModel, sendAt date: Date) {
        guard viewModel.scheduleMessage(inputText, sendAt: date) != nil else { return }
        inputText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func generateMeetingNotes() {
        let snapshot = (viewModel?.messages ?? []).map(SummaryMessage.init)
        let language = appLanguageCode()
        let me = languageManager.localize(ko: "나", en: "Me", ja: "自分", zh: "我", es: "Yo")
        aiResults.meetingNotes = nil
        aiResults.isMeetingNotesLoading = true
        showingMeetingNotes = true
        Task {
            aiResults.meetingNotes = await AIService.shared.meetingNotes(messages: snapshot, targetLanguage: language, meLabel: me)
            aiResults.isMeetingNotesLoading = false
        }
    }

    func generateSummary() {
        guard let viewModel, !viewModel.messages.isEmpty else { return }
        let language = appLanguageCode()
        aiResults.isSummaryLoading = true
        aiResults.summaryText = ""
        aiResults.summaryProgress = nil
        showingSummarySheet = true
        Task {
            let (progress, reporter) = AsyncStream<SummaryProgress>.makeStream()
            let showingProgress = Task { for await step in progress { aiResults.summaryProgress = step } }
            let conversation = await viewModel.recentConversation(limit: AIService.summaryMessageLimit)
            let result = await AIService.shared.summarize(messages: conversation, targetLanguage: language) { reporter.yield($0) }
            reporter.finish()
            await showingProgress.value
            aiResults.summaryProgress = nil
            await MainActor.run {
                aiResults.summaryText = result
                aiResults.isSummaryLoading = false
            }
        }
    }

    func localizedText(_ key: String) -> String {
        guard let locKey = LocalizationKey(rawValue: key) else { return key }
        let language: Language = languageManager.currentLanguage.asLocalizationLanguage
        return LocalizationService.shared.text(for: locKey, language: language)
    }
}
