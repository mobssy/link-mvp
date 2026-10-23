//
//  PasswordStore.swift
//  TalkMVP
//

import CommonCrypto
import Foundation
import Security

/// A salted PBKDF2-SHA256 hash of a password. The password itself is never kept.
nonisolated struct PasswordHash: Codable, Equatable, Sendable {
    let salt: Data
    let hash: Data
    let iterations: Int
}

/// Turns passwords into salted hashes and checks a password against one.
nonisolated struct PasswordHasher: Sendable {
    /// OWASP's recommendation for PBKDF2-HMAC-SHA256. Tests pass a small number to stay fast.
    var iterations = 600_000

    func hash(_ password: String) -> PasswordHash {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        precondition(status == errSecSuccess, "no random bytes for a password salt")
        return PasswordHash(salt: salt, hash: derive(password, salt: salt, iterations: iterations), iterations: iterations)
    }

    func verify(_ password: String, against stored: PasswordHash) -> Bool {
        let candidate = derive(password, salt: stored.salt, iterations: stored.iterations)
        return Self.constantTimeEqual(candidate, stored.hash)
    }

    private func derive(_ password: String, salt: Data, iterations: Int) -> Data {
        let passwordBytes = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { saltBytes in
            CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                passwordBytes.map { Int8(bitPattern: $0) }, passwordBytes.count,
                saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(iterations),
                &derived, derived.count
            )
        }
        precondition(status == kCCSuccess, "PBKDF2 failed")
        return Data(derived)
    }

    /// Looks at every byte whatever the first difference, so the time taken says nothing
    /// about how much of a guess was right.
    static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

/// Where local accounts' password hashes live, keyed by account.
nonisolated protocol PasswordStoring: Sendable {
    func setPassword(_ password: String, for accountID: UUID) throws
    /// False for a wrong password and for an account with no password stored.
    func verifyPassword(_ password: String, for accountID: UUID) -> Bool
    func removeAllPasswords()
}

nonisolated enum PasswordStoreError: Error {
    case keychain(OSStatus)
}

/// Keeps each hash in the Keychain, on this device only and only while it is unlocked.
nonisolated struct KeychainPasswordStore: PasswordStoring {
    private let service: String
    private let hasher: PasswordHasher

    /// Tests pass their own service so they never touch the app's real items.
    init(service: String = "com.cclab.TalkMVP.account-password", hasher: PasswordHasher = PasswordHasher()) {
        self.service = service
        self.hasher = hasher
    }

    func setPassword(_ password: String, for accountID: UUID) throws {
        let data = try PropertyListEncoder().encode(hasher.hash(password))
        let query = baseQuery(for: accountID)
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw PasswordStoreError.keychain(status) }
    }

    func verifyPassword(_ password: String, for accountID: UUID) -> Bool {
        var query = baseQuery(for: accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let stored = try? PropertyListDecoder().decode(PasswordHash.self, from: data)
        else { return false }
        return hasher.verify(password, against: stored)
    }

    func removeAllPasswords() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ] as CFDictionary)
    }

    private func baseQuery(for accountID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]
    }
}

/// Keeps hashes in memory: for tests and previews, which must not touch the real Keychain.
nonisolated final class InMemoryPasswordStore: PasswordStoring, @unchecked Sendable {
    private let hasher: PasswordHasher
    private let lock = NSLock()
    private var hashes: [UUID: PasswordHash] = [:]

    init(hasher: PasswordHasher = PasswordHasher(iterations: 1_000)) {
        self.hasher = hasher
    }

    func setPassword(_ password: String, for accountID: UUID) throws {
        let hash = hasher.hash(password)
        lock.withLock { hashes[accountID] = hash }
    }

    func verifyPassword(_ password: String, for accountID: UUID) -> Bool {
        guard let stored = lock.withLock({ hashes[accountID] }) else { return false }
        return hasher.verify(password, against: stored)
    }

    func removeAllPasswords() {
        lock.withLock { hashes.removeAll() }
    }
}
