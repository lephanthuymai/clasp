import Foundation
import Security

public final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "com.clasp.app.notion",
        account: String = "integration-token"
    ) {
        self.service = service
        self.account = account
    }

    public func readToken() async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            throw ClaspError.keychainFailure(status)
        }
        return token
    }

    public func saveToken(_ token: String) async throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClaspError.credentialNotFound
        }

        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw ClaspError.keychainFailure(updateStatus)
        }

        var insert = query
        attributes.forEach { insert[$0.key] = $0.value }
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw ClaspError.keychainFailure(addStatus)
        }
    }

    public func deleteToken() async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ClaspError.keychainFailure(status)
        }
    }
}
