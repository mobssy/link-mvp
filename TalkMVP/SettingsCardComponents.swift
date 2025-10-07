import SwiftUI
import UIKit

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)
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
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(tint)
            }
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
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
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(tint)
            }
            Text(title)
                .foregroundColor(.primary)
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
                            .fill(Color.blue)
                            .frame(width: 48, height: 48)
                        Image(systemName: "person.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.primary)
                        .font(.headline)
                    Text(subtitle)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.secondary)
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

struct SettingsSectionCard_Previews: PreviewProvider {
    static var previews: some View {
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
        .previewLayout(.sizeThatFits)
    }
}
