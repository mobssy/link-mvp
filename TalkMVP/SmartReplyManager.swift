//
//  SmartReplyManager.swift
//  TalkMVP
//
//  Created by David Song on 10/3/25.
//

import Foundation
import SwiftUI
import Combine

class SmartReplyManager: ObservableObject {
    @Published var suggestedReplies: [SmartReply] = []
    @Published var isLoading = false
    
    // 대화 패턴 학습을 위한 히스토리
    private var conversationHistory: [String] = []
    private let maxHistorySize = 50
    
    // 미리 정의된 답변 템플릿
    private let replyTemplates: [String: [ReplyTemplate]] = [
        "korean": [
            // 긍정적 응답
            ReplyTemplate(text: "좋아요! 👍", triggers: ["어때", "좋을까", "괜찮", "생각해"], category: .positive),
            ReplyTemplate(text: "그렇네요!", triggers: ["맞아", "그래", "확실히"], category: .agreement),
            ReplyTemplate(text: "네, 알겠습니다", triggers: ["해줘", "부탁", "도움"], category: .acknowledgment),
            
            // 질문 응답
            ReplyTemplate(text: "언제 시간 되세요?", triggers: ["만나", "시간", "일정"], category: .question),
            ReplyTemplate(text: "어디서 만날까요?", triggers: ["만나", "장소", "위치"], category: .question),
            ReplyTemplate(text: "몇 시에 하실래요?", triggers: ["시간", "몇 시", "언제"], category: .question),
            
            // 감사 표현
            ReplyTemplate(text: "감사합니다! 😊", triggers: ["고마워", "감사", "도움"], category: .gratitude),
            ReplyTemplate(text: "정말 고마워요!", triggers: ["도와줘", "해줘서", "덕분에"], category: .gratitude),
            
            // 일반적인 응답
            ReplyTemplate(text: "오케이!", triggers: ["알겠어", "확인", "됐어"], category: .casual),
            ReplyTemplate(text: "잠깐만요", triggers: ["기다려", "잠시", "시간"], category: .casual),
            ReplyTemplate(text: "나중에 얘기해요", triggers: ["바빠", "시간없어", "급해"], category: .casual)
        ],
        "english": [
            // Positive responses
            ReplyTemplate(text: "Sounds good! 👍", triggers: ["how about", "good idea", "sounds"], category: .positive),
            ReplyTemplate(text: "That's right!", triggers: ["correct", "exactly", "indeed"], category: .agreement),
            ReplyTemplate(text: "Got it, thanks!", triggers: ["please", "help", "could you"], category: .acknowledgment),
            
            // Questions
            ReplyTemplate(text: "When are you free?", triggers: ["meet", "time", "schedule"], category: .question),
            ReplyTemplate(text: "Where should we meet?", triggers: ["meet", "location", "place"], category: .question),
            ReplyTemplate(text: "What time works?", triggers: ["time", "when", "schedule"], category: .question),
            
            // Gratitude
            ReplyTemplate(text: "Thank you! 😊", triggers: ["thanks", "thank you", "appreciate"], category: .gratitude),
            ReplyTemplate(text: "Really appreciate it!", triggers: ["help", "thanks", "grateful"], category: .gratitude),
            
            // Casual
            ReplyTemplate(text: "Okay!", triggers: ["alright", "sure", "fine"], category: .casual),
            ReplyTemplate(text: "Give me a moment", triggers: ["wait", "hold on", "second"], category: .casual),
            ReplyTemplate(text: "Talk later!", triggers: ["busy", "gotta go", "later"], category: .casual)
        ]
    ]
    
    func generateReplies(for message: String, language: String = "korean") -> [SmartReply] {
        isLoading = true
        
        // 실제로는 비동기 작업이지만 시뮬레이션을 위해 약간의 지연 추가
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.suggestedReplies = self.analyzeAndSuggest(message: message, language: language)
            self.isLoading = false
        }
        
        // 대화 히스토리에 추가
        addToHistory(message)
        
        return suggestedReplies
    }
    
    private func analyzeAndSuggest(message: String, language: String) -> [SmartReply] {
        let normalizedMessage = message.lowercased()
        let templates = replyTemplates[language] ?? replyTemplates["korean"]!
        
        var suggestions: [SmartReply] = []
        var scores: [(ReplyTemplate, Double)] = []
        
        // 각 템플릿에 대해 점수 계산
        for template in templates {
            let score = calculateRelevanceScore(message: normalizedMessage, template: template)
            if score > 0.3 { // 임계값 이상만 포함
                scores.append((template, score))
            }
        }
        
        // 점수순으로 정렬
        scores.sort { $0.1 > $1.1 }
        
        // 상위 3개까지만 선택하되, 카테고리 다양성 고려
        var usedCategories: Set<ReplyCategory> = []
        for (template, score) in scores {
            if suggestions.count >= 3 { break }
            
            // 같은 카테고리가 너무 많이 선택되지 않도록 제한
            if usedCategories.count < 2 || !usedCategories.contains(template.category) {
                suggestions.append(SmartReply(
                    text: template.text,
                    confidence: score,
                    category: template.category
                ))
                usedCategories.insert(template.category)
            }
        }
        
        // 충분한 제안이 없으면 일반적인 답변 추가
        if suggestions.count < 2 {
            suggestions.append(contentsOf: getDefaultReplies(for: language, excluding: usedCategories))
        }
        
        return Array(suggestions.prefix(3))
    }
    
    private func calculateRelevanceScore(message: String, template: ReplyTemplate) -> Double {
        var score: Double = 0.0
        
        // 트리거 단어 매칭
        for trigger in template.triggers {
            if message.contains(trigger.lowercased()) {
                score += 0.4
            }
        }
        
        // 감정 분석 (간단한 키워드 기반)
        let emotionKeywords = getEmotionKeywords(for: template.category)
        for keyword in emotionKeywords {
            if message.contains(keyword) {
                score += 0.2
            }
        }
        
        // 대화 히스토리 기반 점수 (자주 사용된 답변 우선)
        let historyBonus = getHistoryBonus(for: template.text)
        score += historyBonus
        
        // 길이 기반 보정 (너무 짧은 메시지는 점수 감점)
        if message.count < 5 {
            score *= 0.8
        }
        
        return min(score, 1.0) // 최대 1.0으로 제한
    }
    
    private func getEmotionKeywords(for category: ReplyCategory) -> [String] {
        switch category {
        case .positive:
            return ["좋", "great", "awesome", "nice", "좋아", "멋져"]
        case .agreement:
            return ["맞", "right", "correct", "exactly", "그래", "정말"]
        case .question:
            return ["?", "언제", "어디", "when", "where", "how", "what"]
        case .gratitude:
            return ["고마", "thank", "appreciate", "감사"]
        case .acknowledgment:
            return ["알겠", "확인", "got it", "understand", "okay"]
        case .casual:
            return ["ㅋㅋ", "ㅎㅎ", "lol", "haha", "ok", "오케이"]
        }
    }
    
    private func getHistoryBonus(for reply: String) -> Double {
        let usage = conversationHistory.filter { $0 == reply }.count
        return min(Double(usage) * 0.1, 0.3) // 최대 0.3 보너스
    }
    
    private func getDefaultReplies(for language: String, excluding categories: Set<ReplyCategory>) -> [SmartReply] {
        let defaults: [SmartReply]
        
        if language == "korean" {
            defaults = [
                SmartReply(text: "네", confidence: 0.5, category: .acknowledgment),
                SmartReply(text: "ㅋㅋ", confidence: 0.4, category: .casual),
                SmartReply(text: "좋아요", confidence: 0.6, category: .positive)
            ]
        } else {
            defaults = [
                SmartReply(text: "Yes", confidence: 0.5, category: .acknowledgment),
                SmartReply(text: "Haha", confidence: 0.4, category: .casual),
                SmartReply(text: "Nice", confidence: 0.6, category: .positive)
            ]
        }
        
        return defaults.filter { !categories.contains($0.category) }
    }
    
    private func addToHistory(_ message: String) {
        conversationHistory.append(message)
        
        // 히스토리 크기 제한
        if conversationHistory.count > maxHistorySize {
            conversationHistory.removeFirst()
        }
    }
    
    func recordReplyUsage(_ reply: String) {
        // 사용된 답변을 히스토리에 기록하여 학습에 활용
        addToHistory(reply)
    }
    
    func clearSuggestions() {
        suggestedReplies.removeAll()
    }
}

// MARK: - 데이터 모델들

struct SmartReply: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let confidence: Double // 0.0 ~ 1.0
    let category: ReplyCategory
    
    var confidenceLevel: String {
        switch confidence {
        case 0.8...1.0: return "high"
        case 0.5...0.8: return "medium"
        default: return "low"
        }
    }
}

struct ReplyTemplate {
    let text: String
    let triggers: [String] // 트리거 키워드들
    let category: ReplyCategory
}

enum ReplyCategory: CaseIterable {
    case positive    // 긍정적 응답
    case agreement   // 동의
    case question    // 질문
    case gratitude   // 감사
    case acknowledgment // 확인
    case casual      // 일반적/캐주얼
    
    var emoji: String {
        switch self {
        case .positive: return "👍"
        case .agreement: return "✅"
        case .question: return "❓"
        case .gratitude: return "🙏"
        case .acknowledgment: return "📝"
        case .casual: return "💬"
        }
    }
}