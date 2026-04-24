//
//  ProfileEditView.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject var authManager: AuthManager

    @State private var displayName: String
    @State private var statusMessage: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var didRemovePhoto = false

    init(authManager: AuthManager) {
        self.authManager = authManager
        self._displayName = State(initialValue: authManager.currentUser?.displayName ?? "")
        self._statusMessage = State(initialValue: authManager.currentUser?.statusMessage ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    // 프로필 이미지
                    HStack {
                        Spacer()

                        let currentUserImageData = authManager.currentUser?.profileImageData

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                Group {
                                    if let profileImage = profileImage {
                                        Image(uiImage: profileImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else if !didRemovePhoto, let imageData = currentUserImageData,
                                              let uiImage = UIImage(data: imageData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else {
                                        ZStack {
                                            Circle()
                                                .fill(Color.appPrimary.opacity(0.1))
                                                .frame(width: 100, height: 100)
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 48))
                                                .foregroundColor(.appPrimary)
                                        }
                                    }
                                }

                                // Camera badge overlay
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 28, height: 28)
                                    Circle()
                                        .fill(Color.appPrimary)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                        )
                                }
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                                .offset(x: -3, y: -3)
                                .accessibilityHidden(true)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 20)

                    if profileImage != nil || (authManager.currentUser?.profileImageData != nil && !didRemovePhoto) {
                        Button(role: .destructive) {
                            profileImage = nil
                            didRemovePhoto = true
                        } label: {
                            Text(localizedText("remove_photo"))
                        }
                    }
                } header: {
                    Text(localizedText("profile_photo"))
                }

                Section {
                    HStack {
                        Text(localizedText("username"))
                        Spacer()
                        Text(authManager.currentUser?.username ?? "")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(localizedText("display_name"))
                        TextField(localizedText("display_name"), text: $displayName)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text(localizedText("email"))
                        Spacer()
                        Text(authManager.currentUser?.email ?? "")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(localizedText("account_info"))
                }

                Section {
                    TextField(localizedText("status_message"), text: $statusMessage, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text(localizedText("status_message"))
                }

                Section {
                    Button(localizedText("logout")) {
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle(localizedText("edit_profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizedText("cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedText("save")) {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            if let newValue {
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            profileImage = uiImage
                            didRemovePhoto = false
                        }
                    }
                }
            }
        }
    }

    private func saveProfile() {
        let imageData: Data?
        if didRemovePhoto {
            imageData = nil
        } else if let profileImage = profileImage {
            imageData = profileImage.jpegData(compressionQuality: 0.7)
        } else {
            imageData = authManager.currentUser?.profileImageData
        }
        authManager.updateProfile(displayName: displayName, statusMessage: statusMessage, profileImageData: imageData)
    }

    private func localizedText(_ key: String) -> String {
        switch key {
        case "profile_photo": return languageManager.localize(ko: "프로필 사진", en: "Profile Photo", ja: "プロフィール写真", zh: "个人头像", es: "Foto de perfil")
        case "remove_photo": return languageManager.localize(ko: "사진 삭제", en: "Remove Photo", ja: "写真を削除", zh: "删除照片", es: "Eliminar foto")
        case "account_info": return languageManager.localize(ko: "계정 정보", en: "Account Information", ja: "アカウント情報", zh: "账户信息", es: "Información de cuenta")
        case "edit_profile": return languageManager.localize(ko: "프로필 편집", en: "Edit Profile", ja: "プロフィール編集", zh: "编辑资料", es: "Editar perfil")
        case "cancel": return languageManager.localize(ko: "취소", en: "Cancel", ja: "キャンセル", zh: "取消", es: "Cancelar")
        case "save": return languageManager.localize(ko: "저장", en: "Save", ja: "保存", zh: "保存", es: "Guardar")
        case "display_name": return languageManager.localize(ko: "표시 이름", en: "Display Name", ja: "表示名", zh: "显示名称", es: "Nombre visible")
        case "status_message": return languageManager.localize(ko: "상태 메시지", en: "Status Message", ja: "ステータスメッセージ", zh: "状态消息", es: "Mensaje de estado")
        case "email": return languageManager.localize(ko: "이메일", en: "Email", ja: "メール", zh: "邮箱", es: "Correo electrónico")
        case "username": return languageManager.localize(ko: "사용자명", en: "Username", ja: "ユーザー名", zh: "用户名", es: "Nombre de usuario")
        case "logout": return languageManager.localize(ko: "로그아웃", en: "Sign Out", ja: "サインアウト", zh: "退出登录", es: "Cerrar sesión")
        default:
            // 디버깅을 위해 키가 정의되지 않은 경우를 확인
            print("⚠️ ProfileEditView: 키 '\(key)'가 정의되지 않음")
            return key
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self)
    let context = ModelContext(container)
    return ProfileEditView(authManager: AuthManager(modelContext: context))
        .environmentObject(LanguageManager())
}
