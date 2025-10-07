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
    @State private var isPulsing = false

    var body: some View {
        Group {
            if isVisible {
                HStack {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.0 : 0.8)
                        .animation(isPulsing ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isPulsing)

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
        .onAppear {
            // Initialize visibility and pulsing based on current status
            let status = chatService.connectionStatus
            isPulsing = (status == .connecting || status == .reconnecting)
            // Show banner when not connected; if connected, start hidden
            isVisible = (status != .connected)
        }
        .onChange(of: chatService.connectionStatus) { _, newStatus in
            // Update pulsing based on status
            isPulsing = (newStatus == .connecting || newStatus == .reconnecting)

            if newStatus == .connected {
                // Show "연결됨" briefly, then hide after 3 seconds
                withAnimation(.spring()) {
                    isVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation {
                        isVisible = false
                    }
                }
            } else {
                // For disconnected/connecting/reconnecting, keep the banner visible
                withAnimation(.spring()) {
                    isVisible = true
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
