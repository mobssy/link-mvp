//
//  ConnectionStatusView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import SwiftData

struct ConnectionStatusView: View {
    @ObservedObject var chatService: ChatService
    @State private var isVisible = false
    
    var body: some View {
        Group {
            if chatService.connectionStatus != .connected || !isVisible {
                HStack {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .scaleEffect(chatService.connectionStatus == .connecting || chatService.connectionStatus == .reconnecting ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: chatService.connectionStatus == .connecting || chatService.connectionStatus == .reconnecting)
                    
                    Text(chatService.connectionStatus.displayText)
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if chatService.connectionStatus == .disconnected {
                        Button("재연결") {
                            chatService.reconnect()
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture {
                    if chatService.connectionStatus == .connected {
                        withAnimation {
                            isVisible = false
                        }
                    }
                }
            }
        }
        .onChange(of: chatService.connectionStatus) { _, newStatus in
            withAnimation(.spring()) {
                isVisible = newStatus != .connected
            }
            
            // 연결됨 상태일 때 3초 후 자동 숨김
            if newStatus == .connected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
        }
    }
    
    private var color: Color {
        switch chatService.connectionStatus {
        case .disconnected: return .red
        case .connecting: return .orange
        case .connected: return .green
        case .reconnecting: return .orange
        }
    }
    
    private var backgroundColor: Color {
        switch chatService.connectionStatus {
        case .disconnected: return Color.red
        case .connecting: return Color.orange
        case .connected: return Color.green
        case .reconnecting: return Color.orange
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Message.self)
    let context = ModelContext(container)
    return ConnectionStatusView(chatService: ChatService(modelContext: context))
}