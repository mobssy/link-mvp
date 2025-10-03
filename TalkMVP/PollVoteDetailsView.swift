//
//  PollVoteDetailsView.swift
//  TalkMVP
//
//  Created by David Song on 10/3/25.
//

import SwiftUI

struct PollVoteDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    
    let poll: Poll
    
    var body: some View {
        NavigationStack {
            List {
                // 투표 정보 요약
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(poll.question)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        
                        HStack {
                            Label(localizedText("total_votes", count: poll.totalVotes), systemImage: "chart.bar.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if poll.isAnonymous {
                                Label(localizedText("anonymous"), systemImage: "eye.slash")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let expiresAt = poll.expiresAt {
                            Label(
                                localizedText("expires_at") + " " + 
                                expiresAt.formatted(date: .abbreviated, time: .shortened),
                                systemImage: poll.isExpired ? "clock.fill" : "clock"
                            )
                            .font(.caption)
                            .foregroundColor(poll.isExpired ? .red : .secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 투표 결과
                Section(localizedText("results")) {
                    ForEach(poll.options, id: \.id) { option in
                        VoteResultRow(
                            option: option,
                            totalVotes: poll.totalVotes,
                            poll: poll,
                            languageManager: languageManager
                        )
                    }
                }
                
                // 투표한 사람들 (익명이 아닌 경우)
                if !poll.isAnonymous && poll.totalVotes > 0 {
                    Section(localizedText("voters")) {
                        ForEach(poll.options, id: \.id) { option in
                            if !option.votes.isEmpty {
                                VoterListRow(option: option, languageManager: languageManager)
                            }
                        }
                    }
                }
            }
            .navigationTitle(localizedText("poll_details"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText("close")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func localizedText(_ key: String, count: Int = 0) -> String {
        switch key {
        case "total_votes":
            return languageManager.currentLanguage == .korean ? 
                "총 \(count)표" : "\(count) vote\(count == 1 ? "" : "s")"
        case "anonymous":
            return languageManager.currentLanguage == .korean ? "익명 투표" : "Anonymous"
        case "expires_at":
            return languageManager.currentLanguage == .korean ? "만료:" : "Expires:"
        case "results":
            return languageManager.currentLanguage == .korean ? "결과" : "Results"
        case "voters":
            return languageManager.currentLanguage == .korean ? "투표자" : "Voters"
        case "poll_details":
            return languageManager.currentLanguage == .korean ? "투표 상세" : "Poll Details"
        case "close":
            return languageManager.currentLanguage == .korean ? "닫기" : "Close"
        default:
            return key
        }
    }
}

struct VoteResultRow: View {
    let option: PollOption
    let totalVotes: Int
    let poll: Poll
    let languageManager: LanguageManager
    
    private var percentage: Double {
        option.votePercentage(totalVotes: totalVotes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(option.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(option.voteCount)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(String(format: "%.1f%%", percentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 진행 바
            ProgressView(value: percentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 1.2)
        }
        .padding(.vertical, 4)
    }
}

struct VoterListRow: View {
    let option: PollOption
    let languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(option.text)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if option.votes.isEmpty {
                Text(localizedText("no_votes"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(option.votes, id: \.id) { vote in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            
                            Text(vote.userId) // 실제로는 사용자 이름으로 표시
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(vote.votedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func localizedText(_ key: String) -> String {
        switch key {
        case "no_votes":
            return languageManager.currentLanguage == .korean ? "투표 없음" : "No votes"
        default:
            return key
        }
    }
}

#Preview {
    let samplePoll = Poll(
        question: "어떤 음식을 주문할까요?",
        options: ["피자", "치킨", "중국집", "한식"],
        creatorId: "user1",
        chatRoomId: "room1"
    )
    
    return PollVoteDetailsView(poll: samplePoll)
        .environmentObject(LanguageManager())
}