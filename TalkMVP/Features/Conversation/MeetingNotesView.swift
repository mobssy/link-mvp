//
//  MeetingNotesView.swift
//  TalkMVP
//
//  Meeting notes for a chat, grouped by kind
//

import SwiftUI

struct MeetingNotesView: View {
    let notes: MeetingNotes?
    let isLoading: Bool
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        if isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text(text(ko: "회의 노트 정리 중...", en: "Writing meeting notes...", ja: "会議メモを作成中...", zh: "正在整理会议记录...", es: "Preparando notas..."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let notes, !notes.isEmpty {
            List {
                if !notes.summary.isEmpty {
                    Section { Text(notes.summary) }
                }
                if !notes.decisions.isEmpty {
                    Section(Self.labels(languageManager).decisions) {
                        ForEach(notes.decisions, id: \.self) { Label($0, systemImage: "checkmark.seal") }
                    }
                }
                if !notes.actionItems.isEmpty {
                    Section(Self.labels(languageManager).actionItems) {
                        ForEach(Array(notes.actionItems.enumerated()), id: \.offset) { _, item in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.task)
                                    let detail = [item.owner, item.due].compactMap { $0 }.joined(separator: " · ")
                                    if !detail.isEmpty {
                                        Text(detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: "circle")
                            }
                        }
                    }
                }
                if !notes.schedule.isEmpty {
                    Section(Self.labels(languageManager).schedule) {
                        ForEach(Array(notes.schedule.enumerated()), id: \.offset) { _, item in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.when)
                                    Text(item.context).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            } icon: {
                                Image(systemName: "calendar")
                            }
                        }
                    }
                }
                if !notes.openQuestions.isEmpty {
                    Section(Self.labels(languageManager).openQuestions) {
                        ForEach(notes.openQuestions, id: \.self) { Label($0, systemImage: "questionmark.circle") }
                    }
                }
                Section {
                } footer: {
                    Text(notes.generatedByModel
                        ? text(ko: "기기 안의 Apple Intelligence로 정리했어요.", en: "Written on device by Apple Intelligence.", ja: "デバイス上のApple Intelligenceで作成しました。", zh: "由设备上的 Apple Intelligence 整理。", es: "Redactado en el dispositivo con Apple Intelligence.")
                        : text(ko: "Apple Intelligence로 정리하지 못해 규칙으로 뽑았어요.", en: "Apple Intelligence couldn't write these notes, so they were picked out by rules.", ja: "Apple Intelligenceで作成できなかったため、ルールで抽出しました。", zh: "Apple Intelligence 无法整理，因此按规则提取。", es: "Apple Intelligence no pudo redactarlas, así que se extrajeron con reglas."))
                }
            }
        } else {
            ContentUnavailableView(
                text(ko: "정리할 내용이 아직 없어요", en: "Nothing to note yet", ja: "まだメモする内容がありません", zh: "暂时没有可整理的内容", es: "Aún no hay nada que anotar"),
                systemImage: "note.text",
                description: Text(text(ko: "대화에 결정 사항, 할 일, 일정이 나오면 여기에 정리돼요.", en: "Decisions, tasks and dates from the chat will show up here.", ja: "決定事項、タスク、日程が会話に出るとここにまとまります。", zh: "聊天中出现决定、任务和日程时会整理在这里。", es: "Aquí aparecerán las decisiones, tareas y fechas del chat."))
            )
        }
    }

    static func labels(_ languageManager: LanguageManager) -> MeetingNotes.Labels {
        MeetingNotes.Labels(
            title: languageManager.localize(ko: "회의 노트", en: "Meeting Notes", ja: "会議メモ", zh: "会议记录", es: "Notas de reunión"),
            decisions: languageManager.localize(ko: "결정 사항", en: "Decisions", ja: "決定事項", zh: "决定", es: "Decisiones"),
            actionItems: languageManager.localize(ko: "할 일", en: "Action Items", ja: "タスク", zh: "待办事项", es: "Tareas"),
            schedule: languageManager.localize(ko: "일정", en: "Schedule", ja: "日程", zh: "日程", es: "Fechas"),
            openQuestions: languageManager.localize(ko: "남은 질문", en: "Open Questions", ja: "未解決の質問", zh: "待解决的问题", es: "Preguntas abiertas")
        )
    }

    private func text(ko: String, en: String, ja: String, zh: String, es: String) -> String {
        languageManager.localize(ko: ko, en: en, ja: ja, zh: zh, es: es)
    }
}
