//
//  FriendSearchService.swift
//  TalkMVP
//
//  Friend search service and helper functions following Single Responsibility Principle
//

import Foundation

// MARK: - Email Validation Helper
func isValidEmail(_ email: String) -> Bool {
    let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
    return email.range(of: pattern, options: .regularExpression) != nil
}

// MARK: - Friend Search Service
class FriendSearchService {
    static func searchUsers(by email: String) async throws -> [UserSearchResult] {
        // Performance improvement: reduced wait time to 0.3 seconds
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 second wait

        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidEmail(trimmed) else {
            return []
        }

        print("FriendSearchService: Searching for \(trimmed)...")

        let mockResults = [
            UserSearchResult(
                id: UUID().uuidString,
                username: trimmed.components(separatedBy: "@").first ?? "user",
                displayName: trimmed.components(separatedBy: "@").first?.capitalized ?? "User",
                email: trimmed
            )
        ]

        if trimmed.contains("@") && trimmed.contains(".") {
            print("FriendSearchService: Returning search results")
            return mockResults
        } else {
            print("FriendSearchService: Invalid email format")
            return []
        }
    }

    static func sendFriendRequest(from senderId: String, to receiverId: String) async throws -> Bool {
        print("FriendSearchService: Sending friend request...")
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 second wait
        print("FriendSearchService: Friend request sent successfully")
        return true
    }
}

// MARK: - User Search Result Data Model
struct UserSearchResult: Identifiable {
    let id: String
    let username: String
    let displayName: String
    let email: String
}
