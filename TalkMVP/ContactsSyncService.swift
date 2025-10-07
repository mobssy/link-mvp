// ContactsSyncService.swift
// TalkMVP
//
// Handles iOS Contacts access, normalization, hashing, and server-side matching.

import Foundation
import Contacts
import CryptoKit
import Combine

struct ContactIdentifier: Hashable {
   let name: String
   let phones: [String]
   let emails: [String]
}

struct MatchedUser: Identifiable, Hashable, Codable {
   let id: String
   let displayName: String
   let matchedBy: String // e.g., phone or email that matched
}

protocol ContactsMatchingBackend {
   func matchContacts(identifierHashes: [String]) async throws -> [MatchedUser]
}

// Default dummy backend. Replace with your real server integration.
final class DummyMatchingBackend: ContactsMatchingBackend {
   func matchContacts(identifierHashes: [String]) async throws -> [MatchedUser] {
       // TODO: Integrate with your server endpoint, e.g. POST /contacts/match
       // Return matched users from server.
       return []
   }
}

final class ContactsSyncService: ObservableObject {
   let objectWillChange = ObservableObjectPublisher()

   enum AccessStatus { case notDetermined, authorized, denied }

   private let store = CNContactStore()
   private let backend: ContactsMatchingBackend

   init(backend: ContactsMatchingBackend = DummyMatchingBackend()) {
       self.backend = backend
   }

   // MARK: - Authorization
   func checkAuthorizationStatus() -> AccessStatus {
       switch CNContactStore.authorizationStatus(for: .contacts) {
       case .authorized:
           return .authorized
       case .denied, .restricted:
           return .denied
       case .notDetermined:
           return .notDetermined
       case .limited:
           return .authorized
       @unknown default:
           return .denied
       }
   }

   func requestAccess() async -> Bool {
       await withCheckedContinuation { continuation in
           store.requestAccess(for: .contacts) { granted, _ in
               continuation.resume(returning: granted)
           }
       }
   }

   // MARK: - Fetch & Normalize
   func loadContactIdentifiers() async throws -> [ContactIdentifier] {
       try await withCheckedThrowingContinuation { continuation in
           DispatchQueue.global(qos: .userInitiated).async {
               do {
                   let keys: [CNKeyDescriptor] = [
                       CNContactGivenNameKey as CNKeyDescriptor,
                       CNContactFamilyNameKey as CNKeyDescriptor,
                       CNContactPhoneNumbersKey as CNKeyDescriptor,
                       CNContactEmailAddressesKey as CNKeyDescriptor
                   ]
                   let request = CNContactFetchRequest(keysToFetch: keys)

                   var identifiers: [ContactIdentifier] = []
                   try self.store.enumerateContacts(with: request) { contact, _ in
                       let fullName = [contact.familyName, contact.givenName].joined()
                       let phones = contact.phoneNumbers
                           .compactMap { $0.value.stringValue }
                           .map { Self.normalizePhone($0) }
                           .filter { !$0.isEmpty }
                       let emails = contact.emailAddresses
                           .compactMap { $0.value as String }
                           .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                           .filter { !$0.isEmpty }

                       if !phones.isEmpty || !emails.isEmpty {
                           identifiers.append(
                               ContactIdentifier(
                                   name: fullName,
                                   phones: Array(Set(phones)),
                                   emails: Array(Set(emails))
                               )
                           )
                       }
                   }
                   continuation.resume(returning: identifiers)
               } catch {
                   continuation.resume(throwing: error)
               }
           }
       }
   }

   // MARK: - Sync & Match
   func syncAndMatch() async throws -> [MatchedUser] {
       let contacts = try await loadContactIdentifiers()
       var rawIdentifiers: Set<String> = []
       for contact in contacts {
           rawIdentifiers.formUnion(contact.phones)
           rawIdentifiers.formUnion(contact.emails)
       }
       let hashes = rawIdentifiers.map { Self.sha256($0) }
       let matched = try await backend.matchContacts(identifierHashes: hashes)
       return matched
   }

   // MARK: - Helpers
   private static func normalizePhone(_ input: String) -> String {
       // Keep leading '+' if present, and digits only.
       var result = ""
       var hasPlus = false
       for ch in input {
           if ch == "+" && !hasPlus && result.isEmpty {
               hasPlus = true
               result.append(ch)
           } else if ch.isNumber {
               result.append(ch)
           }
       }
       return result
   }

   private static func sha256(_ input: String) -> String {
       let data = Data(input.utf8)
       let digest = SHA256.hash(data: data)
       return digest.compactMap { String(format: "%02x", $0) }.joined()
   }
}
