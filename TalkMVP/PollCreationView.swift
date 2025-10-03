//
//  PollCreationView.swift
//  TalkMVP
//
//  Created by David Song on 10/3/25.
//

import SwiftUI
import SwiftData

struct PollCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager
    
    let chatRoomId: String
    let currentUserId: String
    let onPollCreated: (Poll) -> Void
    
    @State private var question = ""
    @State private var options = ["", ""]
    @State private var allowMultipleChoice = false
    @State private var isAnonymous = false
    @State private var hasExpiration = false
    @State private var expirationDate = Date().addingTimeInterval(86400) // 24시간 후
    @FocusState private var focusedField: Int?
    
    private let maxOptions = 10
    
    var body: some View {
        NavigationStack {
            Form {
                // 질문 섹션
                Section {
                    TextField(localizedText("poll_question_placeholder"), text: $question, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: -1)
                } header: {
                    Text(localizedText("poll_question"))
                }
                
                // 선택지 섹션
                Section {
                    ForEach(options.indices, id: \.self) { index in
                        HStack {
                            TextField(localizedText("option_placeholder", number: index + 1), text: $options[index])
                                .focused($focusedField, equals: index)
                            
                            // 선택지 삭제 버튼 (최소 2개는 유지)
                            if options.count > 2 {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        _ = options.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    // 선택지 추가 버튼
                    if options.count < maxOptions {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                options.append("")
                                focusedField = options.count - 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text(localizedText("add_option"))
                            }
                        }
                    }
                    
                } header: {
                    Text(localizedText("poll_options"))
                } footer: {
                    Text(localizedText("poll_options_footer", max: maxOptions))
                }
                
                // 설정 섹션
                Section {
                    Toggle(localizedText("allow_multiple_choice"), isOn: $allowMultipleChoice)
                    Toggle(localizedText("anonymous_voting"), isOn: $isAnonymous)
                    
                    Toggle(localizedText("set_expiration"), isOn: $hasExpiration)
                    
                    if hasExpiration {
                        DatePicker(
                            localizedText("expires_at"),
                            selection: $expirationDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                } header: {
                    Text(localizedText("poll_settings"))
                } footer: {
                    if hasExpiration {
                        Text(localizedText("expiration_footer"))
                    }
                }
            }
            .navigationTitle(localizedText("create_poll"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: toolbarContent)
        }
        .onAppear {
            focusedField = -1 // 질문 필드에 포커스
        }
    }
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(localizedText("cancel")) {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(localizedText("create")) {
                createPoll()
            }
            .fontWeight(.semibold)
            .disabled(!isValidPoll)
        }
    }
    
    private var isValidPoll: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        options.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count >= 2
    }
    
    private func createPoll() {
        let validOptions = options.compactMap { option in
            let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        
        let poll = Poll(
            question: question.trimmingCharacters(in: .whitespacesAndNewlines),
            options: validOptions,
            creatorId: currentUserId,
            chatRoomId: chatRoomId,
            expiresAt: hasExpiration ? expirationDate : nil,
            isAnonymous: isAnonymous,
            allowMultipleChoice: allowMultipleChoice
        )
        
        modelContext.insert(poll)
        
        do {
            try modelContext.save()
            onPollCreated(poll)
            
            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            dismiss()
        } catch {
            print("Failed to save poll: \(error)")
        }
    }
    
    private func localizedText(_ key: String, number: Int = 0, max: Int = 0) -> String {
        switch key {
        case "poll_question":
            return languageManager.currentLanguage == .korean ? "질문" : "Question"
        case "poll_question_placeholder":
            return languageManager.currentLanguage == .korean ? "투표 질문을 입력하세요" : "Enter your poll question"
        case "poll_options":
            return languageManager.currentLanguage == .korean ? "선택지" : "Options"
        case "option_placeholder":
            return languageManager.currentLanguage == .korean ? "선택지 \(number)" : "Option \(number)"
        case "add_option":
            return languageManager.currentLanguage == .korean ? "선택지 추가" : "Add Option"
        case "poll_options_footer":
            return languageManager.currentLanguage == .korean ? 
                "최대 \(max)개까지 선택지를 추가할 수 있습니다" : 
                "You can add up to \(max) options"
        case "poll_settings":
            return languageManager.currentLanguage == .korean ? "설정" : "Settings"
        case "allow_multiple_choice":
            return languageManager.currentLanguage == .korean ? "복수 선택 허용" : "Allow Multiple Choice"
        case "anonymous_voting":
            return languageManager.currentLanguage == .korean ? "익명 투표" : "Anonymous Voting"
        case "set_expiration":
            return languageManager.currentLanguage == .korean ? "만료 시간 설정" : "Set Expiration"
        case "expires_at":
            return languageManager.currentLanguage == .korean ? "만료 시간" : "Expires At"
        case "expiration_footer":
            return languageManager.currentLanguage == .korean ? 
                "설정된 시간 이후에는 투표할 수 없습니다" : 
                "Voting will be disabled after the expiration time"
        case "create_poll":
            return languageManager.currentLanguage == .korean ? "투표 만들기" : "Create Poll"
        case "cancel":
            return languageManager.currentLanguage == .korean ? "취소" : "Cancel"
        case "create":
            return languageManager.currentLanguage == .korean ? "만들기" : "Create"
        default:
            return key
        }
    }
}

#Preview {
    PollCreationView(
        chatRoomId: "test-room",
        currentUserId: "test-user"
    ) { poll in
        print("Poll created: \(poll.question)")
    }
    .environmentObject(LanguageManager())
}