import Foundation
import Security

enum KeychainKey: String {
    case accessToken
    case refreshToken
    case expirationDate
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
}

final class KeychainManager {
    private let service: String
    private let accessGroup: String?

    init(
        service: String = SpotifyConfig.keychainService,
        accessGroup: String? = SpotifyConfig.keychainAccessGroup
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    func save(_ value: String, for key: KeychainKey) throws {
        let data = Data(value.utf8)
        var query = baseQuery(for: key.rawValue, accessGroup: accessGroup)

        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func read(_ key: KeychainKey) throws -> String? {
        if let value = try readValue(for: key.rawValue, accessGroup: accessGroup) {
            return value
        }

        if accessGroup != nil {
            return try readValue(for: key.rawValue, accessGroup: nil)
        }

        return nil
    }

    func delete(_ key: KeychainKey) throws {
        let status = SecItemDelete(baseQuery(for: key.rawValue, accessGroup: accessGroup) as CFDictionary)
        if accessGroup != nil {
            _ = SecItemDelete(baseQuery(for: key.rawValue, accessGroup: nil) as CFDictionary)
        }
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func clearAll() {
        for key in [KeychainKey.accessToken, .refreshToken, .expirationDate] {
            try? delete(key)
        }
    }

    private func baseQuery(for account: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private func readValue(for account: String, accessGroup: String?) throws -> String? {
        var query = baseQuery(for: account, accessGroup: accessGroup)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.readFailed(status)
        }

        guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return string
    }
}
