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
                            if let profileImage = profileImage {
                                Image(uiImage: profileImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else if let imageData = currentUserImageData,
                                      let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 20)
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
                        }
                    }
                }
            }
        }
    }
    
    private func saveProfile() {
        let imageData = profileImage?.jpegData(compressionQuality: 0.7) ?? authManager.currentUser?.profileImageData
        authManager.updateProfile(displayName: displayName, statusMessage: statusMessage, profileImageData: imageData)
    }
    
    private func localizedText(_ key: String) -> String {
        switch key {
        case "profile_photo":
            return languageManager.currentLanguage == .korean ? "프로필 사진" : "Profile Photo"
        case "username":
            return languageManager.currentLanguage == .korean ? "사용자명" : "Username"
        case "display_name":
            return languageManager.currentLanguage == .korean ? "표시 이름" : "Display Name"
        case "email":
            return languageManager.currentLanguage == .korean ? "이메일" : "Email"
        case "account_info":
            return languageManager.currentLanguage == .korean ? "계정 정보" : "Account Information"
        case "status_message":
            return languageManager.currentLanguage == .korean ? "상태메시지" : "Status Message"
        case "logout":
            return languageManager.currentLanguage == .korean ? "로그아웃" : "Sign Out"
        case "edit_profile":
            return languageManager.currentLanguage == .korean ? "프로필 편집" : "Edit Profile"
        case "cancel":
            return languageManager.currentLanguage == .korean ? "취소" : "Cancel"
        case "save":
            return languageManager.currentLanguage == .korean ? "저장" : "Save"
        default:
            return key
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: User.self)
    let context = ModelContext(container)
    return ProfileEditView(authManager: AuthManager(modelContext: context))
}
