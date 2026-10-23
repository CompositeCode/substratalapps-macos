import Foundation
import Security

/// Where the refresh token lives. The app uses `KeychainStore`; tests use
/// `InMemorySecureStore`, because the data-protection Keychain needs a signed
/// entitlement a test runner doesn't have.
public protocol SecureStore: Sendable {
    func read(_ account: String) throws -> String?
    func write(_ value: String, for account: String) throws
    func delete(_ account: String) throws
}

/// Generic-password Keychain items for the refresh token. Device-only, never
/// synchronized, readable after first unlock (PLATFORM-SPEC §5).
public struct KeychainStore: SecureStore {
    public let service: String

    public init(service: String = "com.substratalapps.hub.session") {
        self.service = service
    }

    public func read(_ account: String) throws -> String? {
        // Without the entitlement, a data-protection read can report "not found"
        // rather than "missing entitlement", so a miss also checks the login keychain.
        if let value = try withFallback({ try read(account, dataProtection: $0) }) { return value }
        return try read(account, dataProtection: false)
    }

    public func write(_ value: String, for account: String) throws {
        try withFallback { try write(value, for: account, dataProtection: $0) }
    }

    public func delete(_ account: String) throws {
        try withFallback { try delete(account, dataProtection: $0) }
    }

    /// The data-protection Keychain (device-only, after-first-unlock) needs the
    /// application-identifier entitlement, which only a provisioning profile
    /// supplies. A local build signed without one gets `errSecMissingEntitlement`;
    /// it falls back to the login keychain so development still works. Release
    /// builds are provisioned, so they always use the data-protection Keychain.
    private func withFallback<T>(_ body: (Bool) throws -> T) throws -> T {
        do {
            return try body(true)
        } catch let error as KeychainError where error.status == errSecMissingEntitlement {
            return try body(false)
        }
    }

    private func read(_ account: String, dataProtection: Bool) throws -> String? {
        var query = baseQuery(account, dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    private func write(_ value: String, for account: String, dataProtection: Bool) throws {
        let data = Data(value.utf8)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(account, dataProtection: dataProtection) as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery(account, dataProtection: dataProtection)
            add[kSecValueData as String] = data
            if dataProtection {
                add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            }
            let added = SecItemAdd(add as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    private func delete(_ account: String, dataProtection: Bool) throws {
        let status = SecItemDelete(baseQuery(account, dataProtection: dataProtection) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private func baseQuery(_ account: String, dataProtection: Bool) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: dataProtection,
        ]
    }
}

public struct KeychainError: Error, CustomStringConvertible {
    public let status: OSStatus
    public var description: String {
        (SecCopyErrorMessageString(status, nil) as String?) ?? "Keychain error \(status)"
    }
}

/// Process-lifetime storage, for tests and previews.
public final class InMemorySecureStore: SecureStore, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: String] = [:]

    public init() {}

    public func read(_ account: String) throws -> String? { lock.withLock { items[account] } }
    public func write(_ value: String, for account: String) throws { lock.withLock { items[account] = value } }
    public func delete(_ account: String) throws { _ = lock.withLock { items.removeValue(forKey: account) } }
}
