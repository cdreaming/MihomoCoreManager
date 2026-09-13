import Foundation
import Security

enum KeychainStore {
    private static let service = "cc.kkr.MihomoManager.profile-secret"
    private static let controllerService = "cc.kkr.MihomoManager.controller-secret"
    private static let legacyService = "cc.kkr.MihomoCoreManager.profile-secret"
    private static let legacyControllerService = "cc.kkr.MihomoCoreManager.controller-secret"

    static func readSecret(profileID: UUID) -> String {
        readSecretWithMigration(profileID: profileID, service: service, legacyService: legacyService)
    }

    static func writeSecret(_ secret: String, profileID: UUID) throws {
        try writeSecret(secret, profileID: profileID, service: service)
    }

    static func deleteSecret(profileID: UUID) {
        deleteSecret(profileID: profileID, service: service)
        deleteSecret(profileID: profileID, service: legacyService)
    }

    static func readControllerSecret(profileID: UUID) -> String {
        readSecretWithMigration(profileID: profileID, service: controllerService, legacyService: legacyControllerService)
    }

    static func writeControllerSecret(_ secret: String, profileID: UUID) throws {
        try writeSecret(secret, profileID: profileID, service: controllerService)
    }

    static func deleteControllerSecret(profileID: UUID) {
        deleteSecret(profileID: profileID, service: controllerService)
        deleteSecret(profileID: profileID, service: legacyControllerService)
    }

    private static func readSecretWithMigration(profileID: UUID, service: String, legacyService: String) -> String {
        let current = readSecret(profileID: profileID, service: service)
        if !current.isEmpty { return current }
        let legacy = readSecret(profileID: profileID, service: legacyService)
        if !legacy.isEmpty {
            try? writeSecret(legacy, profileID: profileID, service: service)
        }
        return legacy
    }

    private static func readSecret(profileID: UUID, service: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    private static func writeSecret(_ secret: String, profileID: UUID, service: String) throws {
        let account = profileID.uuidString
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if secret.isEmpty {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }

        let data = Data(secret.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus), userInfo: nil)
        }

        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus), userInfo: nil)
        }
    }

    private static func deleteSecret(profileID: UUID, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
