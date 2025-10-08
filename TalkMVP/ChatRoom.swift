//
//  ChatRoom.swift
//  TalkMVP
//
//  Created by David Song on 9/26/25.
//

import Foundation
import SwiftData

// 조직 역할 정의
enum OrgRole: String, Codable, CaseIterable {
    case admin
    case manager
    case oncall
    case member
}

@Model
class ChatRoom {
    @Attribute(.unique) var id: UUID
    var name: String
    var lastMessage: String
    var timestamp: Date
    var unreadCount: Int
    var profileImage: String
    @Relationship(deleteRule: .cascade) var messages: [Message] = [Message]()

    // MARK: - 상대방 정보 (1:1 채팅용)
    var otherUserId: String?  // 상대방 User ID
    var otherUserEmail: String?  // 상대방 이메일

    // MARK: - 알림 설정
    var notificationsEnabled: Bool = true  // 채팅방 알림 활성화 여부

    // MARK: - 조직방 확장 속성들
    var isOrganizationRoom: Bool = false

    // 브랜드 커스텀
    var orgName: String?
    var orgLogoData: Data?
    var brandColorHex: String?

    // 역할 관리: userId -> role(rawValue)
    var roles: [String: String] = [:]
    // 공지 고정
    var pinnedAnnouncementId: UUID?

    // 타임락(근무 시간) 설정 - 간단 버전 (별도 구조체 없이 저장)
    var workingDays: [Int] = []

    // 근무 시간 외 허용 역할 (긴급 메시지)
    var emergencyAllowedRoles: [String] = []

    // 근무 시간 설정
    var workStartHour: Int
    var workStartMinute: Int
    var workEndHour: Int
    var workEndMinute: Int
    var timeZoneIdentifier: String

    init(name: String, profileImage: String = "person.circle.fill") {
          self.id = UUID()
          self.name = name
          self.lastMessage = ""
          self.timestamp = Date()
          self.unreadCount = 0
          self.profileImage = profileImage

          // 조직방 확장 기본값 설정
          self.isOrganizationRoom = false
          self.roles = [:]
          self.workingDays = [2, 3, 4, 5, 6]
          self.workStartHour = 9
          self.workStartMinute = 0
          self.workEndHour = 18
          self.workEndMinute = 0
          self.timeZoneIdentifier = TimeZone.current.identifier
          self.emergencyAllowedRoles = ["admin", "oncall"]  // 직접 문자열 사용
      }

    func updateLastMessage() {
        if let lastMsg = messages.sorted(by: { $0.timestamp > $1.timestamp }).first {
            self.lastMessage = lastMsg.text
            self.timestamp = lastMsg.timestamp
        }
    }

    func role(for userId: String) -> OrgRole {
        if let raw = roles[userId], let role = OrgRole(rawValue: raw) {
            return role
        }
        return .member
    }
}
