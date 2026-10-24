import SwiftUI
import UIKit

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let content: Content

    /// Leave out the title for a group that needs no heading, like the first one in Settings.
    init(title: String = "", @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 16)
            }

            VStack {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
            .padding(.horizontal, 4)
        }
    }
}

struct SettingsLinkRow: View {
    let systemImage: String
    let tint: Color
    let title: String

    init(systemImage: String, tint: Color, title: String) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
    }

    var body: some View {
        HStack(spacing: 16) {
            SettingsIconBadge(systemImage: systemImage, tint: tint)
            Text(title)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 10)
    }
}

struct SettingsToggleRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    @Binding var isOn: Bool

    init(systemImage: String, tint: Color, title: String, isOn: Binding<Bool>) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 16) {
            SettingsIconBadge(systemImage: systemImage, tint: tint)
            Text(title)
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 10)
    }
}

struct ProfileCardView: View {
    let title: String
    let subtitle: String
    let imageData: Data?
    let action: () -> Void

    init(title: String, subtitle: String, imageData: Data? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.imageData = imageData
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.appPrimary)
                            .frame(width: 48, height: 48)
                        Image(systemName: "person.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.onAppPrimary)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                        .font(.headline)
                    Text(subtitle)
                        .foregroundStyle(Color.secondary)
                        .font(.subheadline)
                }
                .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 40) {
        SettingsSectionCard(title: "Section Title") {
            VStack {
                SettingsLinkRow(systemImage: "gearshape.fill", tint: .purple, title: "Settings")
                Divider()
                SettingsToggleRow(systemImage: "bell.fill", tint: .orange, title: "Notifications", isOn: .constant(true))
            }
        }
        ProfileCardView(title: "John Doe", subtitle: "Premium User") {}
            .padding(.horizontal)
    }
    .padding()
}

/// The tinted square behind a settings row's symbol. It grows with the text size, so the row
/// keeps its proportions at larger sizes.
struct SettingsIconBadge: View {
    let systemImage: String
    let tint: Color
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemImage)
            .font(.callout.weight(.medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.2), in: .rect(cornerRadius: 6, style: .continuous))
            .accessibilityHidden(true)
    }
}
