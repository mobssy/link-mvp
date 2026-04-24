import SwiftUI

struct AccessibilitySettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("inAppBoldText") private var boldText = false
    @AppStorage("inAppReduceMotion") private var reduceMotion = false
    @AppStorage("inAppHighContrast") private var highContrast = false
    @AppStorage("inAppTextSizeStep") private var textSizeStep = 2

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
        let labels: [String] = [
            languageManager.localize(ko: "작게", en: "Small", ja: "小さく", zh: "小", es: "Pequeño"),
            languageManager.localize(ko: "중간", en: "Medium", ja: "中", zh: "中等", es: "Mediano"),
            languageManager.localize(ko: "기본", en: "Default", ja: "デフォルト", zh: "默认", es: "Predeterminado"),
            languageManager.localize(ko: "크게", en: "Large", ja: "大きく", zh: "大", es: "Grande"),
            languageManager.localize(ko: "더 크게", en: "Extra Large", ja: "さらに大きく", zh: "特大", es: "Extra grande")
        ]
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
                    .accessibilityLabel(languageManager.localize(ko: "글자 크기", en: "Text Size", ja: "テキストサイズ", zh: "文字大小", es: "Tamaño de texto"))
                    .accessibilityValue(textSizeLabel)

                    Text(textSizeLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: textSizeStep)
                }
                .padding(.vertical, 6)
            } header: {
                Text(languageManager.localize(ko: "글자 크기", en: "Text Size", ja: "テキストサイズ", zh: "文字大小", es: "Tamaño de texto"))
            } footer: {
                Text(languageManager.localize(
                    ko: "앱 내 모든 텍스트 크기에 즉시 적용됩니다.",
                    en: "Applies immediately to all text in the app.",
                    ja: "アプリ内のすべてのテキストサイズに即座に適用されます。",
                    zh: "立即应用于应用程序中的所有文本大小。",
                    es: "Se aplica inmediatamente a todos los textos de la aplicación."
                ))
            }

            // MARK: - Visual Settings Section
            Section {
                Toggle(isOn: $boldText) {
                    Label(
                        languageManager.localize(ko: "굵은 텍스트", en: "Bold Text", ja: "太字テキスト", zh: "粗体文本", es: "Texto en negrita"),
                        systemImage: "bold"
                    )
                }
                .accessibilityIdentifier("boldTextToggle")

                Toggle(isOn: $reduceMotion) {
                    Label(
                        languageManager.localize(ko: "모션 줄이기", en: "Reduce Motion", ja: "モーションを減らす", zh: "减少动效", es: "Reducir movimiento"),
                        systemImage: "circle.dotted"
                    )
                }
                .accessibilityIdentifier("reduceMotionToggle")

                Toggle(isOn: $highContrast) {
                    Label(
                        languageManager.localize(ko: "고대비 메시지 버블", en: "High Contrast Bubbles", ja: "高コントラストバブル", zh: "高对比度气泡", es: "Burbujas de alto contraste"),
                        systemImage: "circle.lefthalf.filled"
                    )
                }
                .accessibilityIdentifier("highContrastToggle")
            } header: {
                Text(languageManager.localize(ko: "앱 내 설정", en: "In-App Settings", ja: "アプリ内設定", zh: "应用内设置", es: "Configuración en la aplicación"))
            } footer: {
                Text(languageManager.localize(
                    ko: "이 설정은 앱 내에서 즉시 적용됩니다. 시스템 손쉬운 사용 설정도 자동으로 반영됩니다.",
                    en: "These settings apply immediately. System Accessibility settings are also automatically respected.",
                    ja: "これらの設定はすぐに適用されます。システムのアクセシビリティ設定も自動的に反映されます。",
                    zh: "这些设置立即生效。系统辅助功能设置也会自动应用。",
                    es: "Estos ajustes se aplican de inmediato. La configuración de Accesibilidad del sistema también se respeta automáticamente."
                ))
            }

            // MARK: - Preview Section
            Section {
                previewBubbles
            } header: {
                Text(languageManager.localize(ko: "미리보기", en: "Preview", ja: "プレビュー", zh: "预览", es: "Vista previa"))
            }

            // MARK: - System Settings Guide Section
            Section {
                HStack {
                    Label("VoiceOver", systemImage: "speaker.wave.2.bubble")
                    Spacer()
                    Text(languageManager.localize(ko: "설정 → 손쉬운 사용", en: "Settings → Accessibility", ja: "設定 → アクセシビリティ", zh: "设置 → 辅助功能", es: "Ajustes → Accesibilidad"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Label(languageManager.localize(ko: "스위치 제어", en: "Switch Control", ja: "スイッチコントロール", zh: "开关控制", es: "Control por botón"), systemImage: "accessibility")
                    Spacer()
                    Text(languageManager.localize(ko: "설정 → 손쉬운 사용", en: "Settings → Accessibility", ja: "設定 → アクセシビリティ", zh: "设置 → 辅助功能", es: "Ajustes → Accesibilidad"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(languageManager.localize(ko: "시스템 기능 안내", en: "System Accessibility Features", ja: "システム機能のご案内", zh: "系统辅助功能说明", es: "Funciones de accesibilidad del sistema"))
            } footer: {
                Text(languageManager.localize(
                    ko: "위 기능들은 iOS 설정에서 변경할 수 있으며, 앱에 자동으로 적용됩니다.",
                    en: "These features are managed in iOS Settings and automatically apply to this app.",
                    ja: "これらの機能はiOS設定で変更でき、アプリに自動的に適用されます。",
                    zh: "这些功能可在iOS设置中更改，并自动应用于应用程序。",
                    es: "Estas funciones se gestionan en los Ajustes de iOS y se aplican automáticamente a esta aplicación."
                ))
            }
        }
        .navigationTitle(languageManager.localize(ko: "손쉬운 사용", en: "Accessibility", ja: "アクセシビリティ", zh: "辅助功能", es: "Accesibilidad"))
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
                Text(languageManager.localize(ko: "안녕하세요! 메시지 미리보기입니다.", en: "Hello! This is a preview message.", ja: "こんにちは！これはプレビューメッセージです。", zh: "你好！这是一条预览消息。", es: "¡Hola! Este es un mensaje de vista previa."))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(highContrast ? Color(UIColor.label) : Color.appPrimary)
                    )
                    .foregroundColor(highContrast ? Color(UIColor.systemBackground) : .white)
            }
            HStack {
                Text(languageManager.localize(ko: "반갑습니다! 잘 보이시나요?", en: "Nice to meet you! Can you see this?", ja: "はじめまして！見えますか？", zh: "很高兴认识你！看得清楚吗？", es: "¡Mucho gusto! ¿Puedes ver esto?"))
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
