import SwiftUI

struct AccessibilitySettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("inAppBoldText") private var boldText = false
    @AppStorage("inAppReduceMotion") private var reduceMotion = false
    @AppStorage("inAppHighContrast") private var highContrast = false
    @AppStorage("inAppTextSizeStep") private var textSizeStep = 2

    private var isKorean: Bool { languageManager.currentLanguage == .korean }

    // MARK: - Text Size Helpers

    private func dynamicTypeSizeForStep(_ step: Int) -> DynamicTypeSize {
        switch step {
        case 0: return .small
        case 1: return .medium
        case 3: return .xLarge
        case 4: return .xxLarge
        case 5: return .xxxLarge
        default: return .large
        }
    }

    private var textSizeLabel: String {
        let labels: [String] = isKorean
            ? ["작게", "중간", "기본", "크게", "더 크게"]
            : ["Small", "Medium", "Default", "Large", "Extra Large"]
        guard textSizeStep >= 0 && textSizeStep < labels.count else { return labels[2] }
        return labels[textSizeStep]
    }

    var body: some View {
        Form {
            // MARK: - Text Size Section
            Section {
                VStack(spacing: 14) {
                    // Aa size indicator
                    HStack(alignment: .bottom, spacing: 0) {
                        Text("Aa")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        ForEach(0..<5) { i in
                            Capsule()
                                .fill(i <= textSizeStep ? Color.appPrimary : Color.secondary.opacity(0.3))
                                .frame(width: 6, height: CGFloat(10 + i * 5))
                                .padding(.horizontal, 2)
                        }
                        Spacer()
                        Text("Aa")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(textSizeStep) },
                            set: { textSizeStep = Int($0.rounded()) }
                        ),
                        in: 0...4,
                        step: 1
                    )
                    .tint(.appPrimary)
                    .accessibilityLabel(isKorean ? "글자 크기" : "Text Size")
                    .accessibilityValue(textSizeLabel)

                    Text(textSizeLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: textSizeStep)
                }
                .padding(.vertical, 6)
            } header: {
                Text(isKorean ? "글자 크기" : "Text Size")
            } footer: {
                Text(isKorean
                    ? "앱 내 모든 텍스트 크기에 즉시 적용됩니다."
                    : "Applies immediately to all text in the app.")
            }

            // MARK: - Visual Settings Section
            Section {
                Toggle(isOn: $boldText) {
                    Label(
                        isKorean ? "굵은 텍스트" : "Bold Text",
                        systemImage: "bold"
                    )
                }
                .accessibilityIdentifier("boldTextToggle")

                Toggle(isOn: $reduceMotion) {
                    Label(
                        isKorean ? "모션 줄이기" : "Reduce Motion",
                        systemImage: "circle.dotted"
                    )
                }
                .accessibilityIdentifier("reduceMotionToggle")

                Toggle(isOn: $highContrast) {
                    Label(
                        isKorean ? "고대비 메시지 버블" : "High Contrast Bubbles",
                        systemImage: "circle.lefthalf.filled"
                    )
                }
                .accessibilityIdentifier("highContrastToggle")
            } header: {
                Text(isKorean ? "앱 내 설정" : "In-App Settings")
            } footer: {
                Text(isKorean
                    ? "이 설정은 앱 내에서 즉시 적용됩니다. 시스템 손쉬운 사용 설정도 자동으로 반영됩니다."
                    : "These settings apply immediately. System Accessibility settings are also automatically respected.")
            }

            // MARK: - Preview Section
            Section {
                previewBubbles
            } header: {
                Text(isKorean ? "미리보기" : "Preview")
            }

            // MARK: - System Settings Guide Section
            Section {
                HStack {
                    Label("VoiceOver", systemImage: "speaker.wave.2.bubble")
                    Spacer()
                    Text(isKorean ? "설정 → 손쉬운 사용" : "Settings → Accessibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Label(isKorean ? "스위치 제어" : "Switch Control", systemImage: "accessibility")
                    Spacer()
                    Text(isKorean ? "설정 → 손쉬운 사용" : "Settings → Accessibility")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(isKorean ? "시스템 기능 안내" : "System Accessibility Features")
            } footer: {
                Text(isKorean
                    ? "위 기능들은 iOS 설정에서 변경할 수 있으며, 앱에 자동으로 적용됩니다."
                    : "These features are managed in iOS Settings and automatically apply to this app.")
            }
        }
        .navigationTitle(isKorean ? "손쉬운 사용" : "Accessibility")
        .navigationBarTitleDisplayMode(.inline)
        // Apply bold and size in this view so Preview section reflects changes live
        .fontWeight(boldText ? .bold : .regular)
        .dynamicTypeSize(dynamicTypeSizeForStep(textSizeStep))
    }

    // MARK: - Live Preview Bubbles
    private var previewBubbles: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Text(isKorean ? "안녕하세요! 메시지 미리보기입니다." : "Hello! This is a preview message.")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(highContrast ? Color(UIColor.label) : Color.appPrimary)
                    )
                    .foregroundColor(highContrast ? Color(UIColor.systemBackground) : .white)
            }
            HStack {
                Text(isKorean ? "반갑습니다! 잘 보이시나요?" : "Nice to meet you! Can you see this?")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(highContrast ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                    )
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: highContrast)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: boldText)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: textSizeStep)
    }
}

#Preview {
    NavigationStack {
        AccessibilitySettingsView()
            .environmentObject(LanguageManager())
    }
}
