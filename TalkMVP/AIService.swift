//  AIService.swift
//  TalkMVP
//
//  Conversation summaries and message translation using on-device models,
//  with offline fallbacks when Apple Intelligence or a language pack is unavailable.

import Foundation
import NaturalLanguage

import FoundationModels
import os

nonisolated private let aiLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TalkMVP", category: "AIService")

/// What a summary needs from a message, copied out on the main actor. `Message` is a
/// SwiftData model bound to the main context; reading it from `AIService`'s own executor
/// races with the main thread editing or deleting the same message.
nonisolated struct SummaryMessage: Sendable, Equatable {
    let text: String
    let sender: String
    let isFromCurrentUser: Bool
    let messageType: MessageType
    /// What was said in a voice message, once transcribed.
    var transcript: String? = nil
    /// What a photo shows, once described.
    var imageDescription: String? = nil

    /// The message as words: a text message as it is, or a transcribed voice message as the
    /// text message it amounts to. Nil for anything without words, so notes and summaries can
    /// read what was said aloud the same way as what was typed.
    var asText: SummaryMessage? {
        switch messageType {
        case .text: self
        case .audio: transcript.map { SummaryMessage(text: $0, sender: sender, isFromCurrentUser: isFromCurrentUser, messageType: .text) }
        default: nil
        }
    }
}

extension SummaryMessage {
    @MainActor
    init(_ message: Message) {
        self.init(
            text: message.text,
            sender: message.sender,
            isFromCurrentUser: message.isFromCurrentUser,
            messageType: message.messageType,
            transcript: message.transcript,
            imageDescription: message.imageDescription
        )
    }
}

/// The shape the on-device model fills in for meeting notes (guided generation), so the
/// result arrives as fields rather than prose to be parsed.
@Generable
nonisolated struct MeetingNotesDraft {
    @Guide(description: "One sentence on what the conversation was about")
    var summary: String
    @Guide(description: "Things the participants clearly agreed on. Empty if nothing was settled.", .maximumCount(5))
    var decisions: [String]
    @Guide(description: "Questions nobody answered, such as \"Who is bringing the cake?\". Empty if there are none.", .maximumCount(4))
    var openQuestions: [String]
    @Guide(description: "Tasks someone took on or was asked to do, such as \"I'll book the table\". Empty if there are none.", .maximumCount(6))
    var actionItems: [ActionItemDraft]
}

@Generable
nonisolated struct ActionItemDraft {
    // Generated in this order, so the task is read from a real message rather than made up first.
    @Guide(description: "The chat message the task comes from, copied exactly, in its original language")
    var quote: String
    @Guide(
        description: """
        What the quoted message does. commitment: the sender promises to do something, or says someone named will \
        ("I'll book it", "내가 할게", "Jordan will bring the wine"). request: the sender asks someone to do something \
        ("Could you send the slides?"). question: any other question. statement: anything else, such as a greeting, \
        news, or what someone already did ("went hiking").
        """,
        .anyOf(MeetingNotes.ProposedTask.Kind.allCases.map(\.rawValue))
    )
    var kind: String
    @Guide(description: "What needs doing, written so it makes sense without the chat (\"Ask Minsu whether he is coming\", not \"I'll ask\")")
    var task: String
    @Guide(description: "The person who will do it, as their name appears in the chat")
    var owner: String?
    @Guide(description: "When it is due, as said in the chat; omit if not mentioned")
    var due: String?
}

/// The shape the on-device model fills in for a summary (guided generation). The layout is the
/// app's, so no template line can end up in the text, as "[Write 2–3 sentences…]" once did.
@Generable
nonisolated struct ConversationSummaryDraft {
    @Guide(description: "Two or three sentences on what the whole conversation was about, from its start to its end")
    var overview: String
    @Guide(description: "The main topics, each a short phrase", .maximumCount(5))
    var keyTopics: [String]
    @Guide(description: "Decisions made and tasks people took on, saying who and when where the chat does. Empty if there were none.", .maximumCount(6))
    var decisions: [String]
}

/// Notes on one part of a long chat (guided generation). Asked for "at most four bullet points",
/// the model copied the part's first few lines, small talk included, and stopped before the
/// plans further down, so the notes ask for what the part settles, not for what it says first.
@Generable
nonisolated struct PartNotesDraft {
    @Guide(description: "What this part settles or plans: decisions, bookings, who does what, dates, times, places and amounts, each a short sentence. Leave out small talk. Empty if the part is only small talk.", .maximumCount(6))
    var points: [String]
}

/// How far a summary of a long chat has got, for the screen to show while it waits.
nonisolated enum SummaryProgress: Sendable, Equatable {
    /// Taking notes on part `index` (from 1) of `count`.
    case readingPart(Int, of: Int)
    /// Writing the summary from the notes.
    case writing
}

actor AIService {
    static let shared = AIService()
    private let translators: [any MessageTranslating] = [OnDeviceModelTranslator(), SystemTranslator()]

    /// Meeting notes for the conversation. The on-device model writes the decisions, tasks and
    /// open questions when Apple Intelligence is available, and its tasks are checked against
    /// the chat; otherwise the rule-based extractor writes them. Dates and times always come
    /// from the date detector, which reads them exactly.
    func meetingNotes(messages: [SummaryMessage], limit: Int = 60, targetLanguage: String, meLabel: String) async -> MeetingNotes {
        let recent = Array(messages.suffix(limit))
        let transcript = recent
            .compactMap(\.asText)
            .map { "\($0.isFromCurrentUser ? meLabel : $0.sender): \($0.text)" }
            .joined(separator: "\n")
        guard let draft = await generateMeetingNotesDraft(transcript: transcript, language: targetLanguage, meLabel: meLabel) else {
            return MeetingNotesExtractor.extract(from: recent, meLabel: meLabel)
        }
        let proposal = MeetingNotes.Proposal(
            summary: draft.summary,
            decisions: draft.decisions,
            openQuestions: draft.openQuestions,
            tasks: draft.actionItems.map {
                .init(quote: $0.quote, kind: .init(rawValue: $0.kind) ?? .statement, task: $0.task, owner: $0.owner, due: $0.due)
            }
        )
        return MeetingNotesGrounding.ground(proposal, in: recent, meLabel: meLabel)
    }

    private func generateMeetingNotesDraft(transcript: String, language: String, meLabel: String) async -> MeetingNotesDraft? {
        guard case .available = SystemLanguageModel.default.availability, !transcript.isEmpty else { return nil }
        let instructions = """
        You write short meeting notes from a chat. Always write in \(languageName(for: language)).
        Use only what the messages say; an empty list is better than a guess.
        An action item is a task someone said they would do or was asked to do. A question that only
        asks for information is never an action item: if nobody answered it, it is an open question.
        Give a due date only when the chat states one.
        "\(meLabel)" is the person reading the notes. Name everyone else as they appear before their messages.
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            return try await session.respond(
                to: "Write meeting notes for this chat:\n\n\(transcript)",
                generating: MeetingNotesDraft.self,
                // Extraction wants the most likely reading, not variety.
                options: GenerationOptions(samplingMode: .greedy)
            ).content
        } catch {
            aiLogger.notice("Meeting notes generation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The most a summary reads, oldest dropped first. A chat longer than the model reads at once
    /// is summarized a part at a time.
    nonisolated static let summaryMessageLimit = 300
    /// Estimated transcript tokens the model reads in one go, leaving room in its 4,096 for the
    /// instructions and the answer.
    nonisolated static let summaryTranscriptBudget = 2_400

    func summarize(
        messages: [SummaryMessage], limit: Int = AIService.summaryMessageLimit, targetLanguage: String = "en",
        onProgress: (@Sendable (SummaryProgress) -> Void)? = nil
    ) async -> String {
        let last = Array(messages.suffix(limit))
        let labels = summaryLabels(for: targetLanguage)
        guard !last.isEmpty else { return labels.noMessages }

        let textMessages = last.compactMap(\.asText)
        let participants = Set(last.map { $0.isFromCurrentUser ? labels.me : $0.sender })
        let participantList = participants.sorted().joined(separator: ", ")
        let fromMe = last.filter { $0.isFromCurrentUser }.count
        let fromOther = last.count - fromMe
        let dateStr = Self.summaryDate(Date(), language: targetLanguage)

        let transcriptLines = textMessages.map { "\($0.isFromCurrentUser ? labels.me : $0.sender): \($0.text)" }

        if let aiResult = await generateAISummary(
            lines: transcriptLines, labels: labels, language: targetLanguage,
            participants: participantList, messageCount: last.count, dateStr: dateStr, onProgress: onProgress
        ) { return aiResult }

        return generateFallbackSummary(
            messages: last, textMessages: textMessages, labels: labels,
            participantList: participantList, fromMe: fromMe, fromOther: fromOther, dateStr: dateStr
        )
    }

    private func generateAISummary(
        lines: [String], labels: SummaryLabels, language: String,
        participants: String, messageCount: Int, dateStr: String,
        onProgress: (@Sendable (SummaryProgress) -> Void)?
    ) async -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability, !lines.isEmpty else { return nil }

        let parts = ConversationChunker.chunks(of: lines, budget: Self.summaryTranscriptBudget)
        let prompt: String
        if parts.count == 1 {
            prompt = "Summarize this chat (\(messageCount) messages, participants: \(participants)):\n\n\(lines.joined(separator: "\n"))"
        } else {
            // Too long to read at once: take notes on each part, then summarize the notes.
            var notes: [String] = []
            for (index, part) in parts.enumerated() {
                onProgress?(.readingPart(index + 1, of: parts.count))
                if let note = await notesOnPart(part, language: language) { notes.append("Part \(index + 1):\n\(note)") }
            }
            guard !notes.isEmpty else { return nil }
            onProgress?(.writing)
            prompt = """
            Summarize this chat (\(messageCount) messages, participants: \(participants)). It was too long to \
            read at once, so these are notes on its consecutive parts, oldest first:

            \(notes.joined(separator: "\n\n"))
            """
        }

        // Asked for one summary of a long chat, the model dwelt on how it began and dropped the
        // plans made at the end, hence the reminder.
        let instructions = """
        You are an expert conversation analyst. Summarize chat conversations clearly and insightfully.
        Always write in \(languageName(for: language)). Cover the whole conversation, from the first message
        to the last: plans made near the end matter as much as those made at the start.
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let draft = try await session.respond(to: prompt, generating: ConversationSummaryDraft.self).content
            guard let body = Self.summaryBody(
                overview: draft.overview, keyTopics: draft.keyTopics, decisions: draft.decisions,
                keyTopicsHeader: labels.keyTopics, decisionsHeader: labels.decisions
            ) else { return nil }
            return "✨ **\(labels.header)**\n\(dateStr) · \(String(format: labels.coverage, messageCount))\n\n\(body)"
        } catch {
            aiLogger.notice("Summary generation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// When the summary was made, written the way the app's language writes dates; the device's
    /// own region gave a Korean summary an English date ("Oct 14, 2026 at 2:01 PM").
    nonisolated static func summaryDate(_ date: Date, language: String) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Locale(identifier: language)))
    }

    /// The summary laid out the way the summary sheet shows it: the overview, then a paragraph
    /// per section, each a bold header over bullet lines. Empty sections are left out; nil when
    /// there is nothing at all.
    nonisolated static func summaryBody(
        overview: String, keyTopics: [String], decisions: [String],
        keyTopicsHeader: String, decisionsHeader: String
    ) -> String? {
        func section(_ header: String, _ items: [String]) -> String? {
            let items = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return items.isEmpty ? nil : (["**\(header)**"] + items.map { "• \($0)" }).joined(separator: "\n")
        }
        let overview = overview.trimmingCharacters(in: .whitespacesAndNewlines)
        let paragraphs = [overview.isEmpty ? nil : overview, section(keyTopicsHeader, keyTopics), section(decisionsHeader, decisions)].compactMap { $0 }
        return paragraphs.isEmpty ? nil : paragraphs.joined(separator: "\n\n")
    }

    /// Notes on one part of a long chat, for the summary of the whole; nil if the model couldn't
    /// write them, in which case the summary goes on without that part.
    private func notesOnPart(_ lines: [String], language: String) async -> String? {
        let instructions = """
        You take notes on one part of a long chat, for a summary of the whole chat. Write in \(languageName(for: language)). \
        Keep names, dates, times, places and amounts as the chat gives them.
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let draft = try await session.respond(
                to: lines.joined(separator: "\n"),
                generating: PartNotesDraft.self,
                options: GenerationOptions(samplingMode: .greedy)
            ).content
            let points = draft.points.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            // An empty part still tells the summary that this stretch was small talk.
            return points.isEmpty ? "- (small talk only)" : points.map { "- \($0)" }.joined(separator: "\n")
        } catch {
            aiLogger.notice("Notes on part of a long chat failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func generateFallbackSummary(
        messages: [SummaryMessage], textMessages: [SummaryMessage], labels: SummaryLabels,
        participantList: String, fromMe: Int, fromOther: Int, dateStr: String
    ) -> String {
        var parts: [String] = []

        parts.append("📊 **\(labels.header)**")
        parts.append(dateStr)
        parts.append("")

        parts.append("**\(labels.statsHeader)**")
        parts.append("• \(labels.participants): \(participantList)")
        parts.append("• \(labels.totalMessages): \(messages.count) (\(labels.me): \(fromMe), \(labels.other): \(fromOther))")

        let imageCount = messages.filter { $0.messageType == .image }.count
        let fileCount  = messages.filter { $0.messageType == .file }.count
        let audioCount = messages.filter { $0.messageType == .audio }.count
        if imageCount > 0 { parts.append("• 🖼️ \(labels.image): \(imageCount)") }
        if fileCount  > 0 { parts.append("• 📄 \(labels.file): \(fileCount)") }
        if audioCount > 0 { parts.append("• 🎤 \(labels.audio): \(audioCount)") }

        let keywords = extractKeywords(from: textMessages.map { $0.text }.joined(separator: " "), limit: 6)
        if !keywords.isEmpty {
            parts.append("")
            parts.append("**\(labels.keywordsHeader)**")
            parts.append(keywords.map { "• \($0)" }.joined(separator: "\n"))
        }

        let recent = textMessages.suffix(3)
        if !recent.isEmpty {
            parts.append("")
            parts.append("**\(labels.recentHeader)**")
            for msg in recent {
                let sender = msg.isFromCurrentUser ? labels.me : msg.sender
                let preview = msg.text.count > 60 ? String(msg.text.prefix(60)) + "…" : msg.text
                parts.append("• [\(sender)] \(preview)")
            }
        }

        return parts.joined(separator: "\n")
    }

    private func extractKeywords(from text: String, limit: Int) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var wordFreq: [String: Int] = [:]
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            guard let tag, tag == .noun || tag == .verb || tag == .adjective else { return true }
            let word = String(text[range])
            if word.count > 1 { wordFreq[word, default: 0] += 1 }
            return true
        }

        return wordFreq.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    private struct SummaryLabels {
        let me, image, file, audio, header: String
        let noMessages, statsHeader, participants, totalMessages: String
        let other, keywordsHeader, recentHeader, keyTopics, decisions: String
        /// How many messages the summary covers, with a %d for the count.
        let coverage: String
    }

    private func summaryLabels(for language: String) -> SummaryLabels {
        switch language.lowercased() {
        case "ko":
            return SummaryLabels(
                me: "나", image: "이미지", file: "파일", audio: "음성 메시지",
                header: "대화 요약", noMessages: "요약할 메시지가 없습니다.",
                statsHeader: "대화 통계", participants: "참여자", totalMessages: "총 메시지",
                other: "상대방", keywordsHeader: "주요 키워드", recentHeader: "최근 대화",
                keyTopics: "주요 내용", decisions: "결정 사항", coverage: "메시지 %d개"
            )
        case "ja":
            return SummaryLabels(
                me: "自分", image: "画像", file: "ファイル", audio: "音声メッセージ",
                header: "会話まとめ", noMessages: "要約するメッセージがありません。",
                statsHeader: "会話統計", participants: "参加者", totalMessages: "合計メッセージ",
                other: "相手", keywordsHeader: "キーワード", recentHeader: "最近の会話",
                keyTopics: "主なトピック", decisions: "決定事項", coverage: "%d件のメッセージ"
            )
        case "zh-hans":
            return SummaryLabels(
                me: "我", image: "图片", file: "文件", audio: "语音消息",
                header: "对话摘要", noMessages: "没有可摘要的消息。",
                statsHeader: "对话统计", participants: "参与者", totalMessages: "消息总数",
                other: "对方", keywordsHeader: "关键词", recentHeader: "最近对话",
                keyTopics: "主要话题", decisions: "决定事项", coverage: "%d 条消息"
            )
        case "es":
            return SummaryLabels(
                me: "Yo", image: "Imagen", file: "Archivo", audio: "Mensaje de voz",
                header: "Resumen de conversación", noMessages: "No hay mensajes para resumir.",
                statsHeader: "Estadísticas", participants: "Participantes", totalMessages: "Total de mensajes",
                other: "Otro", keywordsHeader: "Palabras clave", recentHeader: "Mensajes recientes",
                keyTopics: "Temas principales", decisions: "Decisiones", coverage: "%d mensajes"
            )
        default:
            return SummaryLabels(
                // "You", not "Me": the model takes the label for a name, and "Me will send the
                // slides" isn't English. The other languages' labels work as subjects.
                me: "You", image: "Image", file: "File", audio: "Voice message",
                header: "Conversation Summary", noMessages: "No messages to summarize.",
                statsHeader: "Statistics", participants: "Participants", totalMessages: "Total messages",
                other: "Other", keywordsHeader: "Keywords", recentHeader: "Recent messages",
                keyTopics: "Key Topics", decisions: "Decisions", coverage: "%d messages"
            )
        }
    }

    /// Translation pipeline: Apple Intelligence's on-device model, then the Translation
    /// framework. nil when neither can translate.
    func translate(_ text: String, autoDetect: Bool, target: String) async -> String? {
        await Self.firstTranslation(of: text, into: target, autoDetect: autoDetect, using: translators)
    }

    /// The first translation any of `translators` comes up with, in order. Nothing is made up
    /// when none can translate: the chat says it couldn't, rather than showing a guess (a
    /// phrasebook entry or swapped words) as if it were the translation.
    nonisolated static func firstTranslation(
        of text: String, into target: String, autoDetect: Bool, using translators: [any MessageTranslating]
    ) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for translator in translators {
            guard let result = await translator.translate(trimmed, into: target.lowercased(), autoDetect: autoDetect) else { continue }
            let output = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !output.isEmpty { return output }
        }
        return nil
    }

    private func languageName(for code: String) -> String {
        TranslationLanguage.name(for: code)
    }
}
