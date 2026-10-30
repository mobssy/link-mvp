import SwiftUI

struct AccessibilitySettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @AppStorage(AccessibilityPreferences.boldTextKey) private var boldText = false
    @AppStorage(AccessibilityPreferences.reduceMotionKey) private var inAppReducesMotion = false
    @AppStorage(AccessibilityPreferences.highContrastKey) private var inAppHighContrast = false
    // What applies: the switches below or the matching iOS settings. The preview shows these.
    @Environment(\.prefersReducedMotion) private var reduceMotion
    @Environment(\.prefersHighContrast) private var highContrast
    @AppStorage(InAppTextSize.stepKey) private var textSizeStep = InAppTextSize.defaultStep
    @AppStorage(InAppTextSize.overridesKey) private var overridesSystemTextSize = false

    // MARK: - Text Size Helpers

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
                Toggle(isOn: $overridesSystemTextSize.animation(reduceMotion ? nil : .default)) {
                    Label(
                        languageManager.localize(ko: "앱에서 글자 크기 정하기", en: "Custom Text Size", ja: "アプリで文字サイズを設定", zh: "在应用中设置文字大小", es: "Tamaño de texto propio"),
                        systemImage: "textformat.size"
                    )
                }
                .accessibilityIdentifier("customTextSizeToggle")

                if overridesSystemTextSize {
                    VStack(spacing: 14) {
                        // Aa size indicator
                        HStack(alignment: .bottom, spacing: 0) {
                            Text("Aa")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                            Spacer()
                            ForEach(0..<5) { i in
                                Capsule()
                                    .fill(i <= textSizeStep ? Color.appPrimaryText : Color.secondary.opacity(0.3))
                                    .frame(width: 6, height: CGFloat(10 + i * 5))
                                    .padding(.horizontal, 2)
                            }
                            Spacer()
                            Text("Aa")
                                .font(.title2)
                                .foregroundStyle(Color.secondary)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(textSizeStep) },
                                set: { textSizeStep = Int($0.rounded()) }
                            ),
                            in: Double(InAppTextSize.steps.lowerBound)...Double(InAppTextSize.steps.upperBound),
                            step: 1
                        )
                        .tint(.appPrimaryText)
                        .accessibilityLabel(languageManager.localize(ko: "글자 크기", en: "Text Size", ja: "テキストサイズ", zh: "文字大小", es: "Tamaño de texto"))
                        .accessibilityValue(textSizeLabel)

                        Text(textSizeLabel)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: textSizeStep)
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Text(languageManager.localize(ko: "글자 크기", en: "Text Size", ja: "テキストサイズ", zh: "文字大小", es: "Tamaño de texto"))
            } footer: {
                if overridesSystemTextSize {
                    Text(languageManager.localize(
                        ko: "iOS 설정 대신 이 크기를 앱의 모든 글자에 바로 적용합니다.",
                        en: "Applies this size to all text in the app right away, instead of the iOS setting.",
                        ja: "iOSの設定の代わりに、このサイズをアプリ内のすべての文字にすぐ適用します。",
                        zh: "立即将此大小应用于应用中的所有文字，而不是使用 iOS 设置。",
                        es: "Aplica este tamaño a todo el texto de la app al instante, en lugar del ajuste de iOS."
                    ))
                } else {
                    Text(languageManager.localize(
                        ko: "iOS 설정 → 손쉬운 사용 → 디스플레이 및 텍스트 크기의 글자 크기를 따릅니다.",
                        en: "Follows the text size in iOS Settings → Accessibility → Display & Text Size.",
                        ja: "iOSの設定 → アクセシビリティ → 画面表示とテキストサイズの文字サイズに従います。",
                        zh: "跟随 iOS 设置 → 辅助功能 → 显示与文字大小 中的文字大小。",
                        es: "Sigue el tamaño de texto de Ajustes de iOS → Accesibilidad → Pantalla y tamaño del texto."
                    ))
                }
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

                Toggle(isOn: $inAppReducesMotion) {
                    Label(
                        languageManager.localize(ko: "모션 줄이기", en: "Reduce Motion", ja: "モーションを減らす", zh: "减少动效", es: "Reducir movimiento"),
                        systemImage: "circle.dotted"
                    )
                }
                .accessibilityIdentifier("reduceMotionToggle")

                Toggle(isOn: $inAppHighContrast) {
                    Label(
                        languageManager.localize(ko: "고대비 메시지 버블", en: "High Contrast Bubbles", ja: "高コントラストバブル", zh: "高对比度气泡", es: "Burbujas de alto contraste"),
                        systemImage: "circle.lefthalf.filled"
                    )
                }
                .accessibilityIdentifier("highContrastToggle")
            } header: {
                Text(languageManager.localize(ko: "앱 내 설정", en: "In-App Settings", ja: "アプリ内設定", zh: "应用内设置", es: "Configuración en la aplicación"))
            } footer: {
                // The iOS features themselves are set in iOS; the app follows them without a row each.
                Text(languageManager.localize(
                    ko: "바로 적용됩니다. 앱은 VoiceOver, 큰 글자, 동작 줄이기 같은 iOS 손쉬운 사용 설정도 그대로 따릅니다.",
                    en: "These apply right away. The app also follows your iOS accessibility settings, such as VoiceOver, larger text and Reduce Motion.",
                    ja: "すぐに適用されます。アプリはVoiceOver、文字の拡大、視差効果を減らすなど、iOSのアクセシビリティ設定にも従います。",
                    zh: "设置会立即生效。应用也会遵循你的 iOS 辅助功能设置，例如旁白、更大字体和减弱动态效果。",
                    es: "Se aplican al instante. La app también sigue tus ajustes de accesibilidad de iOS, como VoiceOver, el texto más grande y Reducir movimiento."
                ))
            }

            // MARK: - Preview Section
            Section {
                previewBubbles
            } header: {
                Text(languageManager.localize(ko: "미리보기", en: "Preview", ja: "プレビュー", zh: "预览", es: "Vista previa"))
            }
        }
        .navigationTitle(languageManager.localize(ko: "손쉬운 사용", en: "Accessibility", ja: "アクセシビリティ", zh: "辅助功能", es: "Accesibilidad"))
        .navigationBarTitleDisplayMode(.inline)
        // Apply bold and size in this view so Preview section reflects changes live
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
                            .fill(Color.ownBubble(highContrast: highContrast))
                    )
                    .foregroundStyle(Color.onOwnBubble(highContrast: highContrast))
            }
            HStack {
                Text(languageManager.localize(ko: "반갑습니다! 잘 보이시나요?", en: "Nice to meet you! Can you see this?", ja: "はじめまして！見えますか？", zh: "很高兴认识你！看得清楚吗？", es: "¡Mucho gusto! ¿Puedes ver esto?"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(highContrast ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                    )
                    .foregroundStyle(Color.primary)
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
            .environment(LanguageManager())
    }
}
