//
//  ConversationChunker.swift
//  TalkMVP
//
//  Cuts a long chat into parts the on-device model can read at once
//

import Foundation

/// The on-device model reads about 4,000 tokens at a time, instructions and answer included, so
/// a long chat is summarized a part at a time. Parts are sized by a token estimate rather than
/// the model's own count, which is only available from iOS 26.4 and costs a call per line.
nonisolated enum ConversationChunker {
    /// A deliberately high token count: one per non-ASCII character (Korean, Japanese, Chinese
    /// count about one each or less) and one per three ASCII characters, plus a few for the line.
    /// Against the model's own count it came out a fifth to two-fifths high (Korean 411 for 342,
    /// English 371 for 262), which is the safe side.
    static func estimatedTokens(in text: String) -> Int {
        var ascii = 0
        var other = 0
        for scalar in text.unicodeScalars {
            if scalar.isASCII { ascii += 1 } else { other += 1 }
        }
        return other + (ascii + 2) / 3 + 4
    }

    /// The lines in order, in consecutive groups of at most `budget` estimated tokens each. A
    /// line too long for any group on its own is cut short to fit one.
    static func chunks(of lines: [String], budget: Int) -> [[String]] {
        var chunks: [[String]] = []
        var current: [String] = []
        var used = 0
        for line in lines {
            var line = line
            var cost = estimatedTokens(in: line)
            if cost > budget {
                // Every character costs at most one token, so this many always fits.
                line = String(line.prefix(max(budget - 4, 1)))
                cost = estimatedTokens(in: line)
            }
            if used + cost > budget, !current.isEmpty {
                chunks.append(current)
                current = []
                used = 0
            }
            current.append(line)
            used += cost
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
