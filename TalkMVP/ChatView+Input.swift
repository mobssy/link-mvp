//
//  ChatView+Input.swift
//  TalkMVP
//

import SwiftUI
import UIKit
import CoreLocation

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

            if voiceService.isRecording {
                recordingBannerView
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

                    Button {
                        sendLocation()
                    } label: {
                        Label(languageManager.localize(ko: "위치 공유", en: "Share Location", ja: "位置情報を共有", zh: "共享位置", es: "Compartir ubicación"), systemImage: "location")
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

                let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                if hasText {
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

                    Button {
                        sendMessage(viewModel: viewModel)
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.appPrimary)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(localizedText("send_message"))
                    .transition(.scale.combined(with: .opacity))
                } else {
                    micButton(viewModel: viewModel)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: inputText.isEmpty)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var recordingBannerView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(voiceService.isRecording ? 1 : 0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: voiceService.isRecording)
            Text(languageManager.localize(ko: "녹음 중...", en: "Recording...", ja: "録音中...", zh: "录音中...", es: "Grabando..."))
                .font(.caption)
                .foregroundColor(.red)
            Spacer()
            Text(formatRecordingDuration(voiceService.recordingDuration))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
            Button(languageManager.localize(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")) {
                voiceService.cancelRecording()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.08))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func micButton(viewModel: ChatViewModel) -> some View {
        Image(systemName: voiceService.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(voiceService.isRecording ? Color.red : Color.appPrimary)
            .clipShape(Circle())
            .scaleEffect(voiceService.isRecording ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: voiceService.isRecording)
            .accessibilityLabel(languageManager.localize(ko: "음성 메시지 녹음 (길게 누르기)", en: "Hold to record voice message", ja: "長押しで録音", zh: "长按录音", es: "Mantén para grabar"))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !voiceService.isRecording else { return }
                        Task { _ = await voiceService.startRecording() }
                    }
                    .onEnded { _ in
                        guard voiceService.isRecording else { return }
                        if let (data, duration) = voiceService.stopRecording(), duration > 0.5 {
                            viewModel.sendVoiceMessage(audioData: data, duration: duration)
                        } else {
                            voiceService.cancelRecording()
                        }
                    }
            )
    }

    private func formatRecordingDuration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
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

    func sendLocation() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            showingLocationPermissionAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = locationManager.currentLocation {
                viewModel?.sendLocationMessage(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            } else {
                pendingLocationSend = true
                locationManager.requestLocation()
            }
        default:
            pendingLocationSend = true
            locationManager.requestLocation()
        }
    }
}
