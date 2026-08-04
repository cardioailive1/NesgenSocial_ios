import Foundation
import Security

/// Keychain wrapper for the auth token.
///
/// UserDefaults would be simpler, but it's stored in plain text inside the
/// app container and survives in unencrypted backups. An auth token is a
/// credential; it belongs in the Keychain.
enum KeychainStore {
    private static let service = "com.corverxis.nexgensocial"

    static func save(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        // Delete first: SecItemAdd fails with errSecDuplicateItem rather
        // than overwriting, which would silently keep a stale token.
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        // Not synced to iCloud, and unavailable until the device has been
        // unlocked once after boot -- appropriate for a session credential.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
