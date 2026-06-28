import Foundation
import Security

public protocol AppTokenStore: Sendable {
    func loadToken() throws -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

public struct KeychainAppTokenStore: AppTokenStore {
    private let service: String
    private let account: String
    private let usesDataProtectionKeychain: Bool

    public init(
        service: String = "com.linkwise.app",
        account: String = "app-token",
        usesDataProtectionKeychain: Bool = false
    ) {
        self.service = service
        self.account = account
        self.usesDataProtectionKeychain = usesDataProtectionKeychain
    }

    public func loadToken() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw keychainError(status)
        }

        guard let data = item as? Data,
              let token = String(data: data, encoding: .utf8)
        else {
            throw LinkwiseError.secureStorage("App token data is invalid.")
        }

        return token
    }

    public func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                baseQuery() as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )

            guard updateStatus == errSecSuccess else {
                throw keychainError(updateStatus)
            }

            return
        }

        guard addStatus == errSecSuccess else {
            throw keychainError(addStatus)
        }
    }

    public func deleteToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if usesDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }

        return query
    }

    private func keychainError(_ status: OSStatus) -> LinkwiseError {
        let message = SecCopyErrorMessageString(status, nil) as String?
        return .secureStorage(message ?? "Keychain operation failed with status \(status).")
    }
}

public final class MemoryAppTokenStore: AppTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    public init(token: String? = nil) {
        self.token = token
    }

    public func loadToken() throws -> String? {
        lock.withLock {
            token
        }
    }

    public func saveToken(_ token: String) throws {
        lock.withLock {
            self.token = token
        }
    }

    public func deleteToken() throws {
        lock.withLock {
            token = nil
        }
    }
}
