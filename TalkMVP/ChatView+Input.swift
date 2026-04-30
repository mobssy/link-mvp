//
//  ChatView+Input.swift
//  TalkMVP
//

import SwiftUI
import UIKit

extension ChatView {
    @ViewBuilder
    func messageInputView(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            if let replyingTo = replyingToMessage {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: localizedText("replying_to"), replyingTo.isFromCurrentUser ? localizedText("me") : chatRoom.name))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(replyingTo.text)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(localizedText("cancel")) {
                        replyingToMessage = nil
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }

            HStack(spacing: 12) {
                Menu {
                    Button {
                        openPhotosAttachment()
                    } label: {
                        Label(localizedText("photos_videos"), systemImage: "photo.on.rectangle")
                    }

                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label(localizedText("file"), systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.appPrimary)
                        .font(.system(size: 28))
                }
                .accessibilityLabel(localizedText("attach_file"))

                TextField(localizedText("message_input_placeholder"), text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage(viewModel: viewModel)
                    }

                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        scheduledSendDate = Date().addingTimeInterval(3600)
                        showingSchedulePicker = true
                    } label: {
                        Image(systemName: "clock")
                            .foregroundColor(.appPrimary)
                            .font(.system(size: 22))
                    }
                    .accessibilityLabel(languageManager.localize(ko: "예약 발송", en: "Schedule send", ja: "予約送信", zh: "定时发送", es: "Envío programado"))
                    .transition(.scale.combined(with: .opacity))
                }

                Button {
                    sendMessage(viewModel: viewModel)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.appPrimary)
                        .clipShape(Circle())
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel(localizedText("send_message"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    func sendMessage(viewModel: ChatViewModel) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        viewModel.newMessageText = text
        if let replying = replyingToMessage {
            viewModel.setReplyMessage(replying)
        }
        viewModel.sendMessage()

        inputText = ""
        replyingToMessage = nil
        isTextFieldFocused = false
    }
}
