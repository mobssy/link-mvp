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

    private func loc(ko: String, en: String, ja: String, zh: String, es: String) -> String {
        languageManager.localize(ko: ko, en: en, ja: ja, zh: zh, es: es)
    }

    private var title: String { loc(ko: "북마크", en: "Bookmarks", ja: "ブックマーク", zh: "书签", es: "Marcadores") }
    private var emptyLabel: String { loc(ko: "북마크된 메시지가 없습니다", en: "No bookmarked messages", ja: "ブックマークはありません", zh: "没有书签消息", es: "No hay mensajes marcados") }
    private var doneLabel: String { loc(ko: "완료", en: "Done", ja: "完了", zh: "完成", es: "Listo") }

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
                                    ? loc(ko: "나", en: "Me", ja: "自分", zh: "我", es: "Yo")
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

    private func loc(ko: String, en: String, ja: String, zh: String, es: String) -> String {
        languageManager.localize(ko: ko, en: en, ja: ja, zh: zh, es: es)
    }

    private var options: [(label: String, seconds: Int)] {
        [
            (loc(ko: "끄기", en: "Off", ja: "オフ", zh: "关闭", es: "Desactivar"), 0),
            (loc(ko: "1분", en: "1 minute", ja: "1分", zh: "1分钟", es: "1 minuto"), 60),
            (loc(ko: "5분", en: "5 minutes", ja: "5分", zh: "5分钟", es: "5 minutos"), 300),
            (loc(ko: "1시간", en: "1 hour", ja: "1時間", zh: "1小时", es: "1 hora"), 3600),
            (loc(ko: "1일", en: "1 day", ja: "1日", zh: "1天", es: "1 día"), 86400)
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(loc(
                    ko: "새 메시지가 전송 후 자동으로 삭제됩니다",
                    en: "New messages will be deleted after being sent",
                    ja: "新しいメッセージは送信後に自動削除されます",
                    zh: "新消息发送后将自动删除",
                    es: "Los mensajes nuevos se eliminarán tras enviarse"
                ))) {
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
            .navigationTitle(loc(ko: "자폭 메시지", en: "Disappearing Messages", ja: "自動削除メッセージ", zh: "阅后即焚", es: "Mensajes temporales"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(loc(ko: "완료", en: "Done", ja: "完了", zh: "完成", es: "Listo")) { onDismiss() }
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

    private func loc(ko: String, en: String, ja: String, zh: String, es: String) -> String {
        languageManager.localize(ko: ko, en: en, ja: ja, zh: zh, es: es)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundColor(.appPrimary)

                Text(loc(
                    ko: "메시지를 보낼 시간을 선택하세요",
                    en: "Choose when to send this message",
                    ja: "送信する時間を選択してください",
                    zh: "选择发送消息的时间",
                    es: "Elige cuándo enviar este mensaje"
                ))
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
            .navigationTitle(loc(ko: "예약 발송", en: "Schedule Send", ja: "予約送信", zh: "定时发送", es: "Envío programado"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(loc(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")) { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(loc(ko: "예약", en: "Schedule", ja: "予約", zh: "定时", es: "Programar")) {
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
