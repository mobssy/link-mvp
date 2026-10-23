//
//  MeetingNotes.swift
//  TalkMVP
//
//  Structured notes pulled out of a conversation
//

import Foundation

/// What a conversation settled: decisions, who does what, when things happen, and what is
/// still open.
nonisolated struct MeetingNotes: Equatable, Sendable {
    struct ActionItem: Equatable, Sendable {
        var task: String
        var owner: String?
        var due: String?
    }

    struct ScheduleItem: Equatable, Sendable {
        /// The date or time as the chat wrote it, such as "Friday at 7".
        var when: String
        /// The message it came from, so the reader knows what it is for.
        var context: String
    }

    /// A task the on-device model proposed, before it is checked against the chat.
    struct ProposedTask: Equatable, Sendable {
        /// What the quoted message does, as the model read it.
        enum Kind: String, CaseIterable, Sendable {
            /// The sender says they, or someone they name, will do something.
            case commitment
            /// The sender asks someone else to do something.
            case request
            case question
            /// Anything else: greetings, news, what someone already did.
            case statement
        }

        /// The message the task comes from, as the model copied it.
        var quote: String
        var kind: Kind
        var task: String
        var owner: String?
        var due: String?
    }

    /// Notes as the on-device model wrote them, before they are checked against the chat.
    struct Proposal: Sendable {
        var summary: String
        var decisions: [String]
        var openQuestions: [String]
        var tasks: [ProposedTask]
    }

    var summary: String
    var decisions: [String]
    var actionItems: [ActionItem]
    var schedule: [ScheduleItem]
    var openQuestions: [String]
    /// Written by the on-device model; otherwise picked out by the rule-based extractor.
    var generatedByModel: Bool

    var isEmpty: Bool {
        decisions.isEmpty && actionItems.isEmpty && schedule.isEmpty && openQuestions.isEmpty
    }

    struct Labels {
        var title: String
        var decisions: String
        var actionItems: String
        var schedule: String
        var openQuestions: String
    }

    /// Plain text for sharing or pasting elsewhere; empty sections are left out.
    func shareText(labels: Labels) -> String {
        var lines = [labels.title]
        if !summary.isEmpty { lines += ["", summary] }
        func section(_ header: String, _ items: [String]) {
            guard !items.isEmpty else { return }
            lines += ["", header] + items.map { "• \($0)" }
        }
        section(labels.decisions, decisions)
        section(labels.actionItems, actionItems.map { item in
            [item.owner.map { "\($0): " } ?? "", item.task, item.due.map { " (\($0))" } ?? ""].joined()
        })
        section(labels.schedule, schedule.map { "\($0.when) — \($0.context)" })
        section(labels.openQuestions, openQuestions)
        return lines.joined(separator: "\n")
    }
}

/// Rule-based meeting notes, for when the on-device model is unavailable, and the schedule
/// for every set of notes: a date detector reads dates and times exactly, where a language
/// model can only paraphrase them.
nonisolated enum MeetingNotesExtractor {
    static func extract(from messages: [SummaryMessage], meLabel: String) -> MeetingNotes {
        let texts = messages.compactMap(\.asText)
        return MeetingNotes(
            summary: "",
            decisions: unique(texts.filter { matches($0.text, decisionCues) }.map(\.text)).suffix(5).map { $0 },
            actionItems: unique(texts.filter { matches($0.text, commitmentCues) }.map(\.text)).suffix(6).map { text in
                let speaker = texts.last { $0.text == text }
                return MeetingNotes.ActionItem(task: text, owner: speaker.map { $0.isFromCurrentUser ? meLabel : $0.sender }, due: nil)
            },
            schedule: schedule(in: messages),
            openQuestions: unique(texts.map(\.text).filter(isQuestion)).suffix(4).map { $0 },
            generatedByModel: false
        )
    }

    /// The dates and times the messages spell out, typed or said, in the order they were sent. Only a
    /// match with a digit in it counts: a bare "today" or "Friday" is usually small talk
    /// ("Have a good day today!"), and the detector would pin it to noon, a time nobody said.
    static func schedule(in messages: [SummaryMessage]) -> [MeetingNotes.ScheduleItem] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return [] }
        var seen = Set<Date>()
        var items: [MeetingNotes.ScheduleItem] = []
        for message in messages.compactMap(\.asText) {
            let text = message.text
            for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let date = match.date, let range = Range(match.range, in: text) else { continue }
                let when = String(text[range])
                guard when.contains(where: \.isNumber), seen.insert(date).inserted else { continue }
                items.append(.init(when: when, context: text))
            }
        }
        return items
    }

    static func isQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("?") || trimmed.hasSuffix("？")
    }

    // Phrases that usually mean someone took something on, or that something was settled.
    // Lowercased; checked as substrings.
    static let commitmentCues = [
        "i'll ", "i will ", "i can ", "let me ", "i'm going to ",
        "할게", "할께", "하겠", "드릴게", "보낼게", "챙길게", "가져갈게", "준비할게", "알아볼게", "예약할게",
        "します", "しておきます", "我会", "我来", "voy a ", "lo haré",
    ]
    static let decisionCues = [
        "let's ", "lets ", "we'll go with", "decided", "agreed", "settled on",
        "하기로", "결정", "확정", "로 하자", "으로 하자",
        "にしよう", "決定", "决定", "decidimos",
    ]

    private static func matches(_ text: String, _ cues: [String]) -> Bool {
        let lowered = text.lowercased() + " "
        return cues.contains { lowered.contains($0) }
    }

    private static func unique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }
}

/// Checks the notes the on-device model proposes against the chat. A small model fills lists
/// with things nobody said: it turned "Should we invite Jordan?" into a task for the person who
/// asked, and small talk about a hike into a task to share the hike. So every task quotes the
/// message it comes from and says what that message does, and the rules here decide what
/// survives and who owns it.
nonisolated enum MeetingNotesGrounding {
    /// - A task survives only when its quote is a message in the chat that commits to something,
    ///   or asks someone to do something; a question that asks for nothing is not a task.
    /// - The owner the model names is kept when the chat names them too: a participant, or
    ///   someone the quoted message mentions ("Jordan will bring the wine"). Otherwise a
    ///   commitment belongs to whoever sent it, and a request to the person asked, which in a
    ///   two-person chat is the other one. Nobody owns their own request.
    /// - The same task proposed twice, or a decision that only restates a task, is left out.
    static func ground(_ proposal: MeetingNotes.Proposal, in messages: [SummaryMessage], meLabel: String) -> MeetingNotes {
        let texts = messages.compactMap(\.asText)
        let speakers = Set(texts.map { $0.isFromCurrentUser ? meLabel : $0.sender })
        var actionItems: [MeetingNotes.ActionItem] = []
        for task in proposal.tasks {
            guard let source = source(of: task.quote, in: texts) else { continue }
            let sender = source.isFromCurrentUser ? meLabel : source.sender
            let owner: String?
            switch task.kind {
            case .commitment where !MeetingNotesExtractor.isQuestion(source.text):
                owner = person(task.owner, among: speakers, orIn: source.text, meLabel: meLabel) ?? sender
            case .request:
                let others = speakers.subtracting([sender])
                owner = person(task.owner, among: others, orIn: source.text, meLabel: meLabel) ?? (others.count == 1 ? others.first : nil)
            case .commitment, .question, .statement:
                continue
            }
            guard !actionItems.contains(where: { sameText($0.task, task.task) }) else { continue }
            actionItems.append(.init(task: task.task, owner: owner, due: nonEmpty(task.due)))
        }
        return MeetingNotes(
            summary: proposal.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            decisions: proposal.decisions.filter { decision in !actionItems.contains { sameText($0.task, decision) } },
            actionItems: actionItems,
            schedule: MeetingNotesExtractor.schedule(in: messages),
            openQuestions: proposal.openQuestions,
            generatedByModel: true
        )
    }

    /// The message a quote was copied from, most recent first. The model may drop punctuation
    /// or add the sender's name, so letters and digits are compared, not exact strings.
    private static func source(of quote: String, in messages: [SummaryMessage]) -> SummaryMessage? {
        let quoted = normalized(quote)
        guard !quoted.isEmpty else { return nil }
        let candidates = messages.reversed().map { ($0, normalized($0.text)) }.filter { !$0.1.isEmpty }
        return candidates.first { $0.1 == quoted }?.0
            ?? candidates.first { $0.1.contains(quoted) }?.0
            ?? candidates.first { quoted.contains($0.1) && $0.1.count * 2 >= quoted.count }?.0
    }

    /// `name` as the chat spells it, when it is one of `people` or appears in `text`. Any other
    /// name is a guess.
    private static func person(_ name: String?, among people: Set<String>, orIn text: String, meLabel: String) -> String? {
        guard let name = nonEmpty(name) else { return nil }
        if let match = people.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { return match }
        // The reader's label ("Me") is not a name anyone types, and "me" is in half the sentences.
        return name.caseInsensitiveCompare(meLabel) != .orderedSame && text.contains(name) ? name : nil
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func sameText(_ a: String, _ b: String) -> Bool {
        let (x, y) = (normalized(a), normalized(b))
        return !x.isEmpty && !y.isEmpty && (x.contains(y) || y.contains(x))
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
