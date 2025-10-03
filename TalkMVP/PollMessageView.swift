//
//  PollMessageView.swift
//  TalkMVP
//
//  Created by David Song on 10/3/25.
//

import SwiftUI
import SwiftData

struct PollMessageView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    
    let poll: Poll
    let currentUserId: String
    
    @State private var selectedOptions: Set<UUID> = []
    @State private var showingVoteDetails = false
    @State private var hasVoted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 투표 헤더
            pollHeader
            
            // 질문
            Text(poll.question)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            // 선택지들
            VStack(spacing: 8) {
                ForEach(poll.options, id: \.id) { option in
                    PollOptionRow(
                        option: option,
                        totalVotes: poll.totalVotes,
                        isSelected: selectedOptions.contains(option.id),
                        hasVoted: hasVoted,
                        canVote: !poll.isExpired && !hasVoted,
                        isAnonymous: poll.isAnonymous,
                        languageManager: languageManager
                    ) {
                        toggleOption(option)
                    }
                }
            }
            
            // 투표 액션 버튼
            if !poll.isExpired && !hasVoted {
                HStack {
                    Button(localizedText("vote")) {
                        submitVote()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedOptions.isEmpty)
                    
                    Spacer()
                }
            }
            
            // 투표 상태 정보
            pollFooter
        }
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
        )
        .onAppear {
            updateVoteStatus()
        }
        .sheet(isPresented: $showingVoteDetails) {
            PollVoteDetailsView(poll: poll)
                .environmentObject(languageManager)
        }
    }
    
    private var pollHeader: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .foregroundColor(.blue)
                .font(.system(size: 16))
            
            Text(localizedText("poll"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            if poll.isAnonymous {
                Image(systemName: "eye.slash")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            
            Spacer()
            
            if poll.isExpired {
                Text(localizedText("expired"))
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    private var pollFooter: some View {
        HStack {
            if poll.totalVotes > 0 {
                Button {
                    showingVoteDetails = true
                } label: {
                    Text(localizedText("total_votes", count: poll.totalVotes))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(localizedText("no_votes_yet"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let expiresAt = poll.expiresAt, !poll.isExpired {
                Text(localizedText("expires") + " " + expiresAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func toggleOption(_ option: PollOption) {
        if poll.allowMultipleChoice {
            if selectedOptions.contains(option.id) {
                selectedOptions.remove(option.id)
            } else {
                selectedOptions.insert(option.id)
            }
        } else {
            // 단일 선택
            if selectedOptions.contains(option.id) {
                selectedOptions.removeAll()
            } else {
                selectedOptions = [option.id]
            }
        }
    }
    
    private func submitVote() {
        for optionId in selectedOptions {
            if let optionIndex = poll.options.firstIndex(where: { $0.id == optionId }) {
                let vote = PollVote(userId: currentUserId, optionId: optionId)
                poll.options[optionIndex].votes.append(vote)
            }
        }
        
        do {
            try modelContext.save()
            hasVoted = true
            selectedOptions.removeAll()
            
            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } catch {
            print("Failed to save vote: \(error)")
        }
    }
    
    private func updateVoteStatus() {
        hasVoted = poll.hasUserVoted(userId: currentUserId)
        if hasVoted {
            selectedOptions = Set(poll.getUserVotes(userId: currentUserId).map { $0.id })
        }
    }
    
    private func localizedText(_ key: String, count: Int = 0) -> String {
        switch key {
        case "poll":
            return languageManager.currentLanguage == .korean ? "투표" : "Poll"
        case "expired":
            return languageManager.currentLanguage == .korean ? "만료됨" : "Expired"
        case "vote":
            return languageManager.currentLanguage == .korean ? "투표하기" : "Vote"
        case "total_votes":
            return languageManager.currentLanguage == .korean ? 
                "총 \(count)표" : "\(count) vote\(count == 1 ? "" : "s")"
        case "no_votes_yet":
            return languageManager.currentLanguage == .korean ? "아직 투표가 없습니다" : "No votes yet"
        case "expires":
            return languageManager.currentLanguage == .korean ? "만료:" : "Expires:"
        default:
            return key
        }
    }
}

struct PollOptionRow: View {
    let option: PollOption
    let totalVotes: Int
    let isSelected: Bool
    let hasVoted: Bool
    let canVote: Bool
    let isAnonymous: Bool
    let languageManager: LanguageManager
    let onTap: () -> Void
    
    private var percentage: Double {
        option.votePercentage(totalVotes: totalVotes)
    }
    
    var body: some View {
        Button(action: canVote ? onTap : {}) {
            HStack {
                // 선택 상태 표시
                if canVote {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .font(.system(size: 20))
                } else if hasVoted && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(option.text)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        if hasVoted || !canVote {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(option.voteCount)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(String(format: "%.1f%%", percentage))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 투표 결과 진행 바
                    if hasVoted || !canVote {
                        ProgressView(value: percentage, total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: isSelected ? .blue : .gray))
                            .scaleEffect(y: 0.8)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected && canVote ? Color.blue.opacity(0.1) : Color(UIColor.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected && canVote ? Color.blue : Color.clear, lineWidth: 2)
        )
        .disabled(!canVote)
    }
}