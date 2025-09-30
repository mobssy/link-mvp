//
//  TypingIndicatorView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI

struct TypingIndicatorView: View {
    let senderName: String
    @State private var animationAmount = 0.5
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(senderName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("타이핑 중")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 6, height: 6)
                                .scaleEffect(animationAmount)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: animationAmount
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.2))
                )
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .onAppear {
            animationAmount = 1.0
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

#Preview {
    VStack {
        TypingIndicatorView(senderName: "친구")
        Spacer()
    }
    .padding()
}