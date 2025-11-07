//
//  ChatViewSupportingViews.swift
//  L!nkMVP
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import Combine
import PhotosUI
import UniformTypeIdentifiers
import LinkPresentation
import CoreLocation

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .plainText, .image, .audio, .video, .data
        ])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDocumentPicked: (URL) -> Void

        init(onDocumentPicked: @escaping (URL) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onDocumentPicked(url)
        }
    }
}

// MARK: - Photo Picker

struct PhotoPickerView: UIViewControllerRepresentable {
    let onComplete: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            parent.onComplete(results)
        }
    }
}

// MARK: - Reaction Picker View

struct ReactionPickerView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let message: Message?
    let onReactionSelected: (String) -> Void

    private let reactions = ["👍", "❤️", "😂", "😮", "😢", "😡", "👏", "🎉"]

    var body: some View {
        VStack(spacing: 16) {
            Text(LocalizationService.shared.text(for: .addReaction, language: currentLanguage))
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(reactions, id: \.self) { emoji in
                    Button(action: {
                        onReactionSelected(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 60, height: 60)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(reactionLabel(emoji))
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .padding()
    }

    private var currentLanguage: Language {
        languageManager.currentLanguage == .korean ? .korean : .english
    }

    private func reactionLabel(_ emoji: String) -> String {
        let prefix = currentLanguage == .korean ? "반응: " : "Reaction: "
        return prefix + emoji
    }
}

// MARK: - Link Preview View

struct LinkPreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LPLinkView {
        LPLinkView(url: url)
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {}
}

// MARK: - Translated Text View

struct TranslatedTextView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let text: String
    let autoDetect: Bool
    let target: String
    let showOriginal: Bool

    @State private var translated: String = ""
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(isLoading ? LocalizationService.shared.text(for: .translatingEllipsis, language: currentLanguage) : translated)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showOriginal {
                Text(text)
                    .font(.footnote)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .onAppear(perform: translate)
        .onChange(of: text) { _, _ in translate() }
    }

    private var currentLanguage: Language {
        languageManager.currentLanguage == .korean ? .korean : .english
    }

    private func translate() {
        isLoading = true
        Task {
            let result = await AIService.shared.translate(text, autoDetect: autoDetect, target: target)
            await MainActor.run {
                self.translated = result
                self.isLoading = false
            }
        }
    }
}

// MARK: - Organization Room Settings View

struct OrgRoomSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var room: ChatRoom

    @State private var isOrgRoom: Bool = false
    @State private var orgName: String = ""

    enum WeekdayMode: String, CaseIterable {
        case weekdays = "평일"
        case daily = "매일"
    }

    @State private var weekdayMode: WeekdayMode = .weekdays
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(LocalizationService.shared.text(for: .organizationRoom, language: currentLanguage))) {
                    Toggle(LocalizationService.shared.text(for: .enableOrgRoom, language: currentLanguage), isOn: $isOrgRoom)
                    TextField(LocalizationService.shared.text(for: .orgNameOptional, language: currentLanguage), text: $orgName)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }

                if isOrgRoom {
                    Section(
                        header: Text(LocalizationService.shared.text(for: .workingHours, language: currentLanguage)),
                        footer: Text(LocalizationService.shared.text(for: .workingHoursFooter, language: currentLanguage))
                    ) {
                        Picker("근무 요일", selection: $weekdayMode) {
                            ForEach(WeekdayMode.allCases, id: \.self) { mode in
                                Text(modeText(mode)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        DatePicker(LocalizationService.shared.text(for: .start, language: currentLanguage), selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker(LocalizationService.shared.text(for: .end, language: currentLanguage), selection: $endTime, displayedComponents: .hourAndMinute)

                        HStack {
                            Text(LocalizationService.shared.text(for: .channelTimezone, language: currentLanguage))
                            Spacer()
                            Text(room.timeZoneIdentifier)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(LocalizationService.shared.text(for: .channelSettings, language: currentLanguage))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationService.shared.text(for: .cancel, language: currentLanguage)) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationService.shared.text(for: .save, language: currentLanguage)) { saveAndDismiss() }
                        .bold()
                }
            }
            .onAppear(perform: loadFromRoom)
            .onChange(of: startTime) { _, _ in syncTimesToRoom() }
            .onChange(of: endTime) { _, _ in syncTimesToRoom() }
            .onChange(of: weekdayMode) { _, newValue in syncWeekdaysToRoom(mode: newValue) }
            .onChange(of: isOrgRoom) { _, newValue in room.isOrganizationRoom = newValue }
            .onChange(of: orgName) { _, newValue in room.orgName = newValue.isEmpty ? nil : newValue }
        }
    }

    private var currentLanguage: Language {
        languageManager.currentLanguage == .korean ? .korean : .english
    }

    private func modeText(_ mode: WeekdayMode) -> String {
        switch mode {
        case .weekdays:
            return LocalizationService.shared.text(for: .weekdays, language: currentLanguage)
        case .daily:
            return LocalizationService.shared.text(for: .daily, language: currentLanguage)
        }
    }

    private func loadFromRoom() {
        isOrgRoom = room.isOrganizationRoom
        orgName = room.orgName ?? ""

        // Weekday mode 추정
        let set = Set(room.workingDays)
        if set == Set([2, 3, 4, 5, 6]) {
            weekdayMode = .weekdays
        } else if set == Set([1, 2, 3, 4, 5, 6, 7]) {
            weekdayMode = .daily
        } else {
            weekdayMode = .weekdays
        }

        // 시간 초기화
        var cal = Calendar.current
        if let tz = TimeZone(identifier: room.timeZoneIdentifier) {
            cal.timeZone = tz
        }
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = room.workStartHour
        comps.minute = room.workStartMinute
        startTime = cal.date(from: comps) ?? Date()
        comps.hour = room.workEndHour
        comps.minute = room.workEndMinute
        endTime = cal.date(from: comps) ?? Date()
    }

    private func syncTimesToRoom() {
        let cal = Calendar.current
        let startComponents = cal.dateComponents([.hour, .minute], from: startTime)
        let endComponents = cal.dateComponents([.hour, .minute], from: endTime)
        room.workStartHour = startComponents.hour ?? 9
        room.workStartMinute = startComponents.minute ?? 0
        room.workEndHour = endComponents.hour ?? 18
        room.workEndMinute = endComponents.minute ?? 0
    }

    private func syncWeekdaysToRoom(mode: WeekdayMode) {
        switch mode {
        case .weekdays:
            room.workingDays = [2, 3, 4, 5, 6]
        case .daily:
            room.workingDays = [1, 2, 3, 4, 5, 6, 7]
        }
    }

    private func saveAndDismiss() {
        do {
            try modelContext.save()
        } catch {
            print("채널 설정 저장 실패: \(error)")
        }
        dismiss()
    }
}

// MARK: - Mini Profile Sheet

struct MiniProfileSheet: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    let name: String
    let symbol: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 64))
                    .foregroundColor(.appPrimary)
                    .padding(.top, 20)
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(LocalizationService.shared.text(for: .profileInfoUnavailable, language: currentLanguage))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle(LocalizationService.shared.text(for: .profile, language: currentLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationService.shared.text(for: .close, language: currentLanguage)) { dismiss() }
                }
            }
        }
    }

    private var currentLanguage: Language {
        languageManager.currentLanguage == .korean ? .korean : .english
    }
}

// MARK: - Attachment Preview View

struct AttachmentPreviewView: View {
    let attachment: PendingAttachment?
    let onSend: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var languageManager: LanguageManager
    @State private var captionText: String = ""
    @FocusState private var isCaptionFocused: Bool

    var body: some View {
        ZStack {
            // 배경 (검정색)
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 네비게이션
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // 중앙 컨텐츠 (사진/동영상/파일)
                if let attachment = attachment {
                    Spacer()

                    GeometryReader { geometry in
                        attachmentContentView(attachment, geometry: geometry)
                    }

                    Spacer()

                    // 하단 입력 영역
                    bottomInputView
                } else {
                    Spacer()
                    Text(LocalizationService.shared.text(for: .noAttachment, language: currentLanguage))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func attachmentContentView(_ attachment: PendingAttachment, geometry: GeometryProxy) -> some View {
        switch attachment {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()

        case .video:
            ZStack {
                Color.black.opacity(0.5)

                VStack(spacing: 20) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text(LocalizationService.shared.text(for: .video, language: currentLanguage))
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)

        case .document(_, let fileName, let fileSize, let ext):
            ZStack {
                Color.black.opacity(0.8)

                VStack(spacing: 24) {
                    Image(systemName: AttachmentHandler.fileIcon(for: ext ?? ""))
                        .font(.system(size: 100))
                        .foregroundColor(.white)

                    VStack(spacing: 12) {
                        Text(fileName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)

                        Text(AttachmentHandler.formatFileSize(fileSize))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var bottomInputView: some View {
        VStack(spacing: 0) {
            // 구분선
            Divider()
                .background(Color.white.opacity(0.2))

            HStack(alignment: .bottom, spacing: 12) {
                // 텍스트 입력 필드
                ZStack(alignment: .leading) {
                    if captionText.isEmpty {
                        Text(LocalizationService.shared.text(for: .addCaption, language: currentLanguage))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }

                    TextField("", text: $captionText)
                        .focused($isCaptionFocused)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.15))
                        )
                }

                // 보내기 버튼
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.appPrimary)
                }
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.9))
        }
    }

    private var currentLanguage: Language {
        languageManager.currentLanguage == .korean ? .korean : .english
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            print("위치 권한이 거부되었습니다")
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("위치 정보 가져오기 실패: \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }
}
