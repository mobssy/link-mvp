//
//  ChatView+Helpers.swift
//  TalkMVP
//

import SwiftUI
import SwiftData
import UIKit

extension ChatView {
    func isWithinWorkingHours(for room: ChatRoom, now: Date = Date()) -> Bool {
        guard room.isOrganizationRoom else { return true }
        let tz = TimeZone(identifier: room.timeZoneIdentifier) ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let comps = cal.dateComponents([.weekday, .hour, .minute], from: now)
        guard let weekday = comps.weekday, let hour = comps.hour, let minute = comps.minute else { return true }
        if !room.workingDays.contains(weekday) { return false }
        let start = room.workStartHour * 60 + room.workStartMinute
        let end = room.workEndHour * 60 + room.workEndMinute
        let current = hour * 60 + minute
        return current >= start && current < end
    }

    func setupViewModelIfNeeded() {
        chatService.modelContext = modelContext

        if viewModel == nil {
            let vm = ChatViewModel(modelContext: modelContext, chatRoom: chatRoom, chatService: chatService)
            self.viewModel = vm
            vm.checkOnlineStatus()
        } else {
            Task {
                await viewModel?.loadMessages()
            }
        }
    }

    func accessibilityLabelForMessage(_ message: Message) -> String {
        let sender = message.isFromCurrentUser ? localizedText("me") : chatRoom.name
        let time = Self.timeFormatter.string(from: message.timestamp)
        let lang: Language = languageManager.currentLanguage == .korean ? .korean : .english
        let svc = LocalizationService.shared

        let contentLabel: String
        switch message.messageType {
        case .text:
            contentLabel = message.text
        case .image:
            contentLabel = svc.text(for: .photoMessage, language: lang)
        case .video:
            contentLabel = svc.text(for: .videoMessage, language: lang)
        case .audio:
            contentLabel = svc.text(for: .audioMessageLabel, language: lang)
        case .file:
            let fileName = message.fileName ?? svc.text(for: .fileMessage, language: lang)
            contentLabel = "\(svc.text(for: .fileMessage, language: lang)): \(fileName)"
        case .deleted:
            contentLabel = svc.text(for: .deletedMessageLabel, language: lang)
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
            print("❌ [ChatView] Cannot add reaction: no current user")
            return
        }

        message.addReaction(emoji, from: currentUserId)

        do {
            try modelContext.save()
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            let announcement = languageManager.currentLanguage == .korean ?
                "반응 \(emoji)를 추가했습니다" :
                "Added reaction \(emoji)"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        } catch {
            print("❌ [ChatView] Failed to save reaction: \(error)")
        }
    }

    // MARK: - Bookmarks

    func toggleBookmark(_ message: Message) {
        message.isBookmarked.toggle()
        try? modelContext.save()
        let label = message.isBookmarked
            ? (languageManager.currentLanguage == .korean ? "북마크 추가됨" : "Bookmarked")
            : (languageManager.currentLanguage == .korean ? "북마크 해제됨" : "Bookmark removed")
        UIAccessibility.post(notification: .announcement, argument: label)
    }

    // MARK: - Disappearing Messages

    func checkDisappearingMessages() {
        guard let messages = viewModel?.messages else { return }
        let now = Date()
        for message in messages {
            guard message.isDisappearing, message.disappearAfterSeconds > 0 else { continue }
            let expiresAt = message.timestamp.addingTimeInterval(TimeInterval(message.disappearAfterSeconds))
            if now >= expiresAt {
                viewModel?.deleteMessage(message, forEveryone: false)
            }
        }
    }

    // MARK: - Scheduled Send

    func scheduleMessage(viewModel: ChatViewModel, sendAt date: Date) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let message = Message(
            text: text,
            isFromCurrentUser: true,
            chatRoomId: chatRoom.id.uuidString
        )
        message.scheduledFor = date
        message.isPendingScheduled = true
        modelContext.insert(message)
        try? modelContext.save()
        inputText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func checkAndSendScheduled(viewModel: ChatViewModel) {
        let messages = viewModel.messages.filter { $0.isPendingScheduled }
        let now = Date()
        for message in messages {
            guard let sendAt = message.scheduledFor, now >= sendAt else { continue }
            message.isPendingScheduled = false
            message.scheduledFor = nil
            message.timestamp = now
            if chatRoom.disappearingDuration > 0 {
                message.isDisappearing = true
                message.disappearAfterSeconds = chatRoom.disappearingDuration
            }
            try? modelContext.save()
        }
    }

    func generateSummary() {
        guard let messages = viewModel?.messages, !messages.isEmpty else { return }
        let language = appLanguageCode()
        Task {
            let result = await AIService.shared.summarize(messages: messages, targetLanguage: language)
            await MainActor.run {
                summaryText = result
                showingSummarySheet = true
            }
        }
    }

    func localizedText(_ key: String) -> String {
        guard let locKey = LocalizationKey(rawValue: key) else { return key }
        let language: Language = languageManager.currentLanguage == .korean ? .korean : .english
        return LocalizationService.shared.text(for: locKey, language: language)
    }
}
