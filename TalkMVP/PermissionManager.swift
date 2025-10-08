//
//  PermissionManager.swift
//  TalkMVP
//
//  Created by Claude Code
//

import Foundation
import Combine
import Photos
import Contacts
import CoreLocation
import UIKit

/// Single Responsibility: 권한 관리 전담
/// Dependency Inversion: 프로토콜로 추상화
protocol PermissionManagerProtocol {
    func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void)
    func requestContactsAccess(completion: @escaping (Bool) -> Void)
    func checkPhotoLibraryStatus() -> PermissionStatus
    func checkContactsStatus() -> PermissionStatus
}

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
    case limited // Photos only
}

/// Concrete implementation
class PermissionManager: PermissionManagerProtocol {
    static let shared = PermissionManager()

    private init() {}

    // MARK: - Photo Library Permissions

    func checkPhotoLibraryStatus() -> PermissionStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return mapPhotoStatus(status)
    }

    func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void) {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch currentStatus {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func mapPhotoStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    // MARK: - Contacts Permissions

    func checkContactsStatus() -> PermissionStatus {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        return mapContactsStatus(status)
    }

    func requestContactsAccess(completion: @escaping (Bool) -> Void) {
        let currentStatus = CNContactStore.authorizationStatus(for: .contacts)

        switch currentStatus {
        case .authorized:
            completion(true)
        case .notDetermined:
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        case .limited:
            completion(true)
        @unknown default:
            completion(false)
        }
    }

    private func mapContactsStatus(_ status: CNAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        case .limited:
            return .limited
        @unknown default:
            return .denied
        }
    }

    // MARK: - Utility Methods

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - SwiftUI-friendly ObservableObject wrapper

import SwiftUI

@MainActor
class PermissionManagerViewModel: ObservableObject {
    @Published var photoStatus: PermissionStatus = .notDetermined
    @Published var contactsStatus: PermissionStatus = .notDetermined
    @Published var showingPhotoPermissionAlert = false
    @Published var showingContactsPermissionAlert = false

    private let manager: PermissionManagerProtocol

    init(manager: PermissionManagerProtocol? = nil) {
        self.manager = manager ?? PermissionManager.shared
        updateStatuses()
    }

    func updateStatuses() {
        photoStatus = manager.checkPhotoLibraryStatus()
        contactsStatus = manager.checkContactsStatus()
    }

    func requestPhotoAccess() {
        manager.requestPhotoLibraryAccess { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.updateStatuses()
            } else {
                self.showingPhotoPermissionAlert = true
            }
        }
    }

    func requestContactsAccess() {
        manager.requestContactsAccess { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.updateStatuses()
            } else {
                self.showingContactsPermissionAlert = true
            }
        }
    }

    func openSettings() {
        if let manager = manager as? PermissionManager {
            manager.openAppSettings()
        }
    }
}

