//
//  ChatRoomBackgroundSettings.swift
//  TalkMVP
//
//  Chat room background customization view
//

import SwiftUI
import SwiftData
import PhotosUI

struct ChatRoomBackgroundSettings: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageManager: LanguageManager

    let chatRoom: ChatRoom

    @State private var selectedBackgroundType: BackgroundType
    @State private var selectedColor: Color
    @State private var gradientStart: Color
    @State private var gradientEnd: Color
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var showingResetConfirmation = false

    enum BackgroundType: String, CaseIterable {
        case `default`
        case color
        case gradient
        case image

        func title(isKorean: Bool) -> String {
            switch self {
            case .default: return isKorean ? "기본" : "Default"
            case .color: return isKorean ? "단색" : "Solid Color"
            case .gradient: return isKorean ? "그라디언트" : "Gradient"
            case .image: return isKorean ? "이미지" : "Image"
            }
        }

        func icon() -> String {
            switch self {
            case .default: return "circle"
            case .color: return "paintpalette.fill"
            case .gradient: return "circle.lefthalf.filled"
            case .image: return "photo.fill"
            }
        }
    }

    init(chatRoom: ChatRoom) {
        self.chatRoom = chatRoom

        // Initialize state based on current settings
        let bgType = BackgroundType(rawValue: chatRoom.backgroundType) ?? .default
        _selectedBackgroundType = State(initialValue: bgType)

        let color = Color(hex: chatRoom.backgroundColor ?? "#FFFFFF") ?? .white
        _selectedColor = State(initialValue: color)

        let gradStart = Color(hex: chatRoom.gradientStartColor ?? "#4A90E2") ?? .blue
        _gradientStart = State(initialValue: gradStart)

        let gradEnd = Color(hex: chatRoom.gradientEndColor ?? "#50E3C2") ?? .green
        _gradientEnd = State(initialValue: gradEnd)

        if let imageData = chatRoom.backgroundImageData,
           let image = UIImage(data: imageData) {
            _previewImage = State(initialValue: image)
        }
    }

    private func localizedText(_ key: String) -> String {
        let isKorean = languageManager.currentLanguage == .korean
        switch key {
        case "chat_background": return isKorean ? "채팅 배경" : "Chat Background"
        case "background_type": return isKorean ? "배경 타입" : "Background Type"
        case "choose_color": return isKorean ? "색상 선택" : "Choose Color"
        case "gradient_start": return isKorean ? "그라디언트 시작" : "Gradient Start"
        case "gradient_end": return isKorean ? "그라디언트 끝" : "Gradient End"
        case "choose_image": return isKorean ? "이미지 선택" : "Choose Image"
        case "preview": return isKorean ? "미리보기" : "Preview"
        case "save": return isKorean ? "저장" : "Save"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "reset": return isKorean ? "초기화" : "Reset"
        case "reset_confirm": return isKorean ? "배경을 기본값으로 초기화하시겠습니까?" : "Reset background to default?"
        case "sample_message": return isKorean ? "안녕하세요! 이것은 샘플 메시지입니다." : "Hello! This is a sample message."
        default: return key
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview Section
                    previewSection

                    // Background Type Selection
                    backgroundTypeSection

                    // Type-specific settings
                    switch selectedBackgroundType {
                    case .default:
                        defaultBackgroundInfo
                    case .color:
                        colorPickerSection
                    case .gradient:
                        gradientPickerSection
                    case .image:
                        imagePickerSection
                    }

                    // Reset Button
                    resetButton
                }
                .padding()
            }
            .navigationTitle(localizedText("chat_background"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedText("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedText("save")) {
                        saveSettings()
                    }
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newValue in
                loadImage(from: newValue)
            }
        }
    }

    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedText("preview"))
                .font(.headline)
                .padding(.horizontal, 4)

            ZStack {
                // Background
                backgroundPreview

                // Sample messages
                VStack(spacing: 12) {
                    Spacer()

                    // Received message
                    HStack {
                        messageBubble(text: localizedText("sample_message"), isFromCurrentUser: false)
                        Spacer()
                    }

                    // Sent message
                    HStack {
                        Spacer()
                        messageBubble(text: localizedText("sample_message"), isFromCurrentUser: true)
                    }
                }
                .padding()
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var backgroundPreview: some View {
        switch selectedBackgroundType {
        case .default:
            Color(UIColor.systemGroupedBackground)
        case .color:
            selectedColor
        case .gradient:
            LinearGradient(
                colors: [gradientStart, gradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .image:
            if let image = previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(UIColor.systemGroupedBackground)
            }
        }
    }

    private func messageBubble(text: String, isFromCurrentUser: Bool) -> some View {
        Text(text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isFromCurrentUser ? Color.appPrimary : Color(UIColor.secondarySystemGroupedBackground))
            .foregroundColor(isFromCurrentUser ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Background Type Section
    private var backgroundTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedText("background_type"))
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(BackgroundType.allCases, id: \.self) { type in
                    Button {
                        selectedBackgroundType = type
                    } label: {
                        HStack {
                            Image(systemName: type.icon())
                                .foregroundColor(.appPrimary)
                                .frame(width: 24)

                            Text(type.title(isKorean: languageManager.currentLanguage == .korean))
                                .foregroundColor(.primary)

                            Spacer()

                            if selectedBackgroundType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appPrimary)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(selectedBackgroundType == type ? Color.appPrimary.opacity(0.1) : Color.clear)
                    }

                    if type != BackgroundType.allCases.last {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Default Background Info
    private var defaultBackgroundInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text(languageManager.currentLanguage == .korean ?
                     "시스템 기본 배경을 사용합니다" :
                     "Using system default background")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Color Picker Section
    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedText("choose_color"))
                .font(.headline)
                .padding(.horizontal, 4)

            ColorPicker(localizedText("choose_color"), selection: $selectedColor, supportsOpacity: false)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Gradient Picker Section
    private var gradientPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedText("gradient_start"))
                .font(.headline)
                .padding(.horizontal, 4)

            ColorPicker(localizedText("gradient_start"), selection: $gradientStart, supportsOpacity: false)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(localizedText("gradient_end"))
                .font(.headline)
                .padding(.horizontal, 4)

            ColorPicker(localizedText("gradient_end"), selection: $gradientEnd, supportsOpacity: false)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Image Picker Section
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedText("choose_image"))
                .font(.headline)
                .padding(.horizontal, 4)

            Button {
                showingPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "photo")
                        .foregroundColor(.appPrimary)
                    Text(localizedText("choose_image"))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Reset Button
    private var resetButton: some View {
        Button(role: .destructive) {
            showingResetConfirmation = true
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text(localizedText("reset"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .alert(localizedText("reset"), isPresented: $showingResetConfirmation) {
            Button(localizedText("cancel"), role: .cancel) {}
            Button(localizedText("reset"), role: .destructive) {
                resetToDefault()
            }
        } message: {
            Text(localizedText("reset_confirm"))
        }
    }

    // MARK: - Helper Functions
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.previewImage = image
                    }
                }
            case .failure(let error):
                print("❌ Failed to load image: \(error)")
            }
        }
    }

    private func saveSettings() {
        chatRoom.backgroundType = selectedBackgroundType.rawValue

        switch selectedBackgroundType {
        case .default:
            chatRoom.backgroundColor = nil
            chatRoom.backgroundImageData = nil
            chatRoom.gradientStartColor = nil
            chatRoom.gradientEndColor = nil

        case .color:
            chatRoom.backgroundColor = selectedColor.toHex()
            chatRoom.backgroundImageData = nil
            chatRoom.gradientStartColor = nil
            chatRoom.gradientEndColor = nil

        case .gradient:
            chatRoom.gradientStartColor = gradientStart.toHex()
            chatRoom.gradientEndColor = gradientEnd.toHex()
            chatRoom.backgroundColor = nil
            chatRoom.backgroundImageData = nil

        case .image:
            if let image = previewImage,
               let imageData = image.jpegData(compressionQuality: 0.7) {
                chatRoom.backgroundImageData = imageData
            }
            chatRoom.backgroundColor = nil
            chatRoom.gradientStartColor = nil
            chatRoom.gradientEndColor = nil
        }

        do {
            try modelContext.save()
            print("✅ Chat room background saved")
            dismiss()
        } catch {
            print("❌ Failed to save background settings: \(error)")
        }
    }

    private func resetToDefault() {
        selectedBackgroundType = .default
        selectedColor = .white
        gradientStart = .blue
        gradientEnd = .green
        previewImage = nil
        selectedPhotoItem = nil
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#FFFFFF" }
        let r = components[0]
        let g = components[1]
        let b = components[2]
        return String(format: "#%02X%02X%02X",
                     Int(r * 255),
                     Int(g * 255),
                     Int(b * 255))
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ChatRoom.self, configurations: config)
    let chatRoom = ChatRoom(name: "테스트 채팅방")
    container.mainContext.insert(chatRoom)

    return NavigationStack {
        ChatRoomBackgroundSettings(chatRoom: chatRoom)
            .environmentObject(LanguageManager())
            .modelContainer(container)
    }
}
