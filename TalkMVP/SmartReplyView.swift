//
//  SmartReplyView.swift
//  TalkMVP
//
//  Created by David Song on 10/3/25.
//

import SwiftUI

struct SmartReplyView: View {
    @ObservedObject var smartReplyManager: SmartReplyManager
    @EnvironmentObject private var languageManager: LanguageManager
    
    let onReplySelected: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var selectedReply: SmartReply?
    
    var body: some View {
        VStack(spacing: 0) {
            if !smartReplyManager.suggestedReplies.isEmpty {
                // 헤더
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(.appPrimary)
                        
                        Text(localizedText("smart_replies"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.appPrimary)
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            smartReplyManager.clearSuggestions()
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // 답변 목록
                if smartReplyManager.isLoading {
                    loadingView
                } else {
                    repliesScrollView
                }
            }
        }
        .background(Color(UIColor.systemGray6))
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 50)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                isVisible = true
            }
        }
        .onChange(of: smartReplyManager.suggestedReplies) { _, newReplies in
            if newReplies.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
    
    private var loadingView: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)
                    .shimmer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    private var repliesScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(smartReplyManager.suggestedReplies, id: \.id) { reply in
                    SmartReplyButton(
                        reply: reply,
                        isSelected: selectedReply?.id == reply.id,
                        languageManager: languageManager
                    ) {
                        selectReply(reply)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }
    
    private func selectReply(_ reply: SmartReply) {
        // 선택 애니메이션
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedReply = reply
        }
        
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 짧은 지연 후 답변 전송
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            smartReplyManager.recordReplyUsage(reply.text)
            onReplySelected(reply.text)
            
            // 제안 목록 숨기기
            withAnimation(.easeInOut(duration: 0.3)) {
                smartReplyManager.clearSuggestions()
            }
        }
    }
    
    private func localizedText(_ key: String) -> String {
        switch key {
        case "smart_replies":
            return languageManager.currentLanguage == .korean ? "스마트 답변" : "Smart Replies"
        default:
            return key
        }
    }
}

struct SmartReplyButton: View {
    let reply: SmartReply
    let isSelected: Bool
    let languageManager: LanguageManager
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // 카테고리 이모지 (신뢰도가 높은 경우만)
                if reply.confidence > 0.7 {
                    Text(reply.category.emoji)
                        .font(.system(size: 12))
                }
                
                Text(reply.text)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                
                // 신뢰도 표시 (개발 모드에서만)
                if ProcessInfo.processInfo.environment["SHOW_CONFIDENCE"] == "1" {
                    Text(String(format: "%.1f", reply.confidence))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .foregroundColor(textColor)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {
            onTap()
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.appPrimary.opacity(0.2)
        } else if reply.confidence > 0.8 {
            return Color.green.opacity(0.1)
        } else {
            return Color(UIColor.systemBackground)
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.appPrimary
        } else if reply.confidence > 0.8 {
            return Color.green.opacity(0.5)
        } else {
            return Color(UIColor.systemGray4)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .appPrimary
        } else {
            return .primary
        }
    }
}

// 로딩 애니메이션을 위한 Shimmer 효과
struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: isAnimating ? 300 : -300)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
            )
            .clipped()
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var smartReplyManager = SmartReplyManager()
        @StateObject private var languageManager = LanguageManager()
        
        var body: some View {
            VStack {
                Spacer()
                
                SmartReplyView(
                    smartReplyManager: smartReplyManager,
                    onReplySelected: { reply in
                        print("Selected: \(reply)")
                    },
                    onDismiss: {
                        print("Dismissed")
                    }
                )
                .environmentObject(languageManager)
            }
            .onAppear {
                // 샘플 답변 생성
                smartReplyManager.suggestedReplies = [
                    SmartReply(text: "좋아요! 👍", confidence: 0.9, category: .positive),
                    SmartReply(text: "언제 시간 되세요?", confidence: 0.8, category: .question),
                    SmartReply(text: "네, 알겠습니다", confidence: 0.7, category: .acknowledgment)
                ]
            }
        }
    }
    
    return PreviewWrapper()
}
