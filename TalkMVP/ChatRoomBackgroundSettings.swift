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

        func title(languageManager: LanguageManager) -> String {
            switch self {
            case .default: return languageManager.localize(ko: "기본", en: "Default", ja: "デフォルト", zh: "默认", es: "Predeterminado")
            case .color: return languageManager.localize(ko: "단색", en: "Solid Color", ja: "単色", zh: "纯色", es: "Color sólido")
            case .gradient: return languageManager.localize(ko: "그라디언트", en: "Gradient", ja: "グラデーション", zh: "渐变", es: "Degradado")
            case .image: return languageManager.localize(ko: "이미지", en: "Image", ja: "画像", zh: "图片", es: "Imagen")
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
        switch key {
        case "chat_background": return languageManager.localize(ko: "채팅 배경", en: "Chat Background", ja: "チャット背景", zh: "聊天背景", es: "Fondo del chat")
        case "background_type": return languageManager.localize(ko: "배경 타입", en: "Background Type", ja: "背景タイプ", zh: "背景类型", es: "Tipo de fondo")
        case "choose_color": return languageManager.localize(ko: "색상 선택", en: "Choose Color", ja: "色を選択", zh: "选择颜色", es: "Elegir color")
        case "gradient_start": return languageManager.localize(ko: "그라디언트 시작", en: "Gradient Start", ja: "グラデーション開始", zh: "渐变起始", es: "Inicio del degradado")
        case "gradient_end": return languageManager.localize(ko: "그라디언트 끝", en: "Gradient End", ja: "グラデーション終了", zh: "渐变结束", es: "Fin del degradado")
        case "choose_image": return languageManager.localize(ko: "이미지 선택", en: "Choose Image", ja: "画像を選択", zh: "选择图片", es: "Elegir imagen")
        case "preview": return languageManager.localize(ko: "미리보기", en: "Preview", ja: "プレビュー", zh: "预览", es: "Vista previa")
        case "save": return languageManager.localize(ko: "저장", en: "Save", ja: "保存", zh: "保存", es: "Guardar")
        case "cancel": return languageManager.localize(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")
        case "reset": return languageManager.localize(ko: "초기화", en: "Reset", ja: "リセット", zh: "重置", es: "Restablecer")
        case "reset_confirm": return languageManager.localize(ko: "배경을 기본값으로 초기화하시겠습니까?", en: "Reset background to default?", ja: "背景をデフォルトにリセットしますか？", zh: "将背景重置为默认值？", es: "¿Restablecer el fondo a los valores predeterminados?")
        case "sample_message": return languageManager.localize(ko: "안녕하세요! 이것은 샘플 메시지입니다.", en: "Hello! This is a sample message.", ja: "こんにちは！これはサンプルメッセージです。", zh: "你好！这是一条示例消息。", es: "¡Hola! Este es un mensaje de muestra.")
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

                            Text(type.title(languageManager: languageManager))
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
                Text(languageManager.localize(ko: "시스템 기본 배경을 사용합니다", en: "Using system default background", ja: "システムのデフォルト背景を使用します", zh: "使用系统默认背景", es: "Usando el fondo predeterminado del sistema"))
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
