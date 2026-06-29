import XCTest
@testable import LinkwiseCore

final class AppTokenStoreTests: XCTestCase {
    func testMemoryStoreSavesOverwritesAndDeletesToken() throws {
        let store = MemoryAppTokenStore()

        XCTAssertNil(try store.loadToken())

        try store.saveToken("lwapp_first")
        XCTAssertEqual(try store.loadToken(), "lwapp_first")

        try store.saveToken("lwapp_second")
        XCTAssertEqual(try store.loadToken(), "lwapp_second")

        try store.deleteToken()
        XCTAssertNil(try store.loadToken())
    }

    func testKeychainStoreSavesOverwritesAndDeletesToken() throws {
        let store = KeychainAppTokenStore(
            service: "com.linkwise.tests.\(UUID().uuidString)",
            account: "app-token",
            usesDataProtectionKeychain: true
        )
        do {
            try store.deleteToken()
            defer { try? store.deleteToken() }

            XCTAssertNil(try store.loadToken())

            try store.saveToken("lwapp_keychain_first")
            XCTAssertEqual(try store.loadToken(), "lwapp_keychain_first")

            try store.saveToken("lwapp_keychain_second")
            XCTAssertEqual(try store.loadToken(), "lwapp_keychain_second")

            try store.deleteToken()
            XCTAssertNil(try store.loadToken())
        } catch {
            try skipIfKeychainUnavailable(error)
            throw error
        }
    }

    private func skipIfKeychainUnavailable(_ error: Error) throws {
        guard case let LinkwiseError.secureStorage(message) = error else {
            return
        }

        if message.localizedCaseInsensitiveContains("keychain") ||
            message.localizedCaseInsensitiveContains("entitlement") ||
            message.localizedCaseInsensitiveContains("authorization") ||
            message.localizedCaseInsensitiveContains("not authorized") ||
            message.contains("钥匙串") ||
            message.contains("授权") {
            throw XCTSkip("Keychain is unavailable in this test environment: \(message)")
        }
    }
}
