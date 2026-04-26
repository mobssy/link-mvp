//
//  ChatView+Sheets.swift
//  TalkMVP
//

import SwiftUI

// MARK: - Bookmarked Messages

struct BookmarkedMessagesSheet: View {
    let messages: [Message]
    let chatRoomName: String
    let onDismiss: () -> Void
    @EnvironmentObject private var languageManager: LanguageManager

    private var title: String { languageManager.currentLanguage == .korean ? "북마크" : "Bookmarks" }
    private var emptyLabel: String { languageManager.currentLanguage == .korean ? "북마크된 메시지가 없습니다" : "No bookmarked messages" }
    private var doneLabel: String { languageManager.currentLanguage == .korean ? "완료" : "Done" }

    var body: some View {
        NavigationStack {
            Group {
                if messages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(emptyLabel)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(messages.sorted { $0.timestamp > $1.timestamp }) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(message.isFromCurrentUser
                                    ? (languageManager.currentLanguage == .korean ? "나" : "Me")
                                    : message.sender)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.appPrimary)
                                Spacer()
                                Text(message.timestamp, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(message.text)
                                .font(.body)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(doneLabel) { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Disappearing Message Duration Picker

struct DisappearingMessagePickerSheet: View {
    let chatRoom: ChatRoom
    let onDismiss: () -> Void
    @EnvironmentObject private var languageManager: LanguageManager

    private var isKorean: Bool { languageManager.currentLanguage == .korean }

    private let options: [(label: String, seconds: Int)] = [
        ("끄기 / Off", 0),
        ("1분 / 1 min", 60),
        ("5분 / 5 min", 300),
        ("1시간 / 1 hour", 3600),
        ("1일 / 1 day", 86400)
    ]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(isKorean ? "새 메시지가 전송 후 자동으로 삭제됩니다" : "New messages will be deleted after being sent")) {
                    ForEach(options, id: \.seconds) { option in
                        Button {
                            chatRoom.disappearingDuration = option.seconds
                            onDismiss()
                        } label: {
                            HStack {
                                Text(option.label)
                                    .foregroundColor(.primary)
                                Spacer()
                                if chatRoom.disappearingDuration == option.seconds {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.appPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isKorean ? "자폭 메시지" : "Disappearing Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isKorean ? "완료" : "Done") { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Scheduled Send Picker

struct ScheduledSendSheet: View {
    @Binding var scheduledDate: Date
    let onConfirm: (Date) -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var languageManager: LanguageManager

    private var isKorean: Bool { languageManager.currentLanguage == .korean }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundColor(.appPrimary)

                Text(isKorean ? "메시지를 보낼 시간을 선택하세요" : "Choose when to send this message")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                DatePicker(
                    "",
                    selection: $scheduledDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()

                Spacer()
            }
            .padding()
            .navigationTitle(isKorean ? "예약 발송" : "Schedule Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isKorean ? "취소" : "Cancel") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isKorean ? "예약" : "Schedule") {
                        onConfirm(scheduledDate)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
