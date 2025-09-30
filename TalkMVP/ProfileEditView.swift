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
                    Text("프로필 사진")
                }
                
                Section {
                    HStack {
                        Text("사용자명")
                        Spacer()
                        Text(authManager.currentUser?.username ?? "")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("표시 이름")
                        TextField("표시 이름", text: $displayName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("이메일")
                        Spacer()
                        Text(authManager.currentUser?.email ?? "")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("계정 정보")
                }
                
                Section {
                    TextField("상태메시지", text: $statusMessage, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("상태메시지")
                }
                
                Section {
                    Button("로그아웃") {
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("프로필 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
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
}

#Preview {
    let container = try! ModelContainer(for: User.self)
    let context = ModelContext(container)
    return ProfileEditView(authManager: AuthManager(modelContext: context))
}
