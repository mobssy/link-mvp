//
//  ChatAIResults.swift
//  TalkMVP
//
//  The summary and meeting notes a chat is writing, for the sheets that show them
//

import Observation

/// One chat's AI summary and meeting notes, from the moment they are asked for until they are
/// written.
///
/// Kept in an observable object rather than in ChatView's own @State. A sheet shows what its
/// content read the last time ChatView's body ran, and the body never reads these values itself,
/// so the sheets opened on the values from before the request ("Nothing to note yet" while the
/// notes were still being written, a blank summary) and caught up only when something else
/// redrew the chat. Read from this object, they follow every change.
@Observable
final class ChatAIResults {
    var summaryText = ""
    var isSummaryLoading = false
    /// Which part of a long chat the summary is reading; nil for a chat read in one go.
    var summaryProgress: SummaryProgress?
    var meetingNotes: MeetingNotes?
    var isMeetingNotesLoading = false
}
