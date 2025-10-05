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
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.appPrimary)
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
        let isKorean = languageManager.isKorean
        
        switch key {
        case "profile_photo": return isKorean ? "프로필 사진" : "Profile Photo"
        case "remove_photo": return isKorean ? "사진 삭제" : "Remove Photo"
        case "account_info": return isKorean ? "계정 정보" : "Account Information"
        case "edit_profile": return isKorean ? "프로필 편집" : "Edit Profile"
        case "cancel": return isKorean ? "취소" : "Cancel"
        case "save": return isKorean ? "저장" : "Save"
        case "display_name": return isKorean ? "표시 이름" : "Display Name"
        case "status_message": return isKorean ? "상태 메시지" : "Status Message"
        case "email": return isKorean ? "이메일" : "Email"
        case "username": return isKorean ? "사용자명" : "Username"
        case "logout": return isKorean ? "로그아웃" : "Sign Out"
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
}
