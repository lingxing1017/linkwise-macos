import XCTest
@testable import LinkwiseCore

final class SettingsStoreTests: XCTestCase {
    func testDefaultsAndNormalization() {
        let defaults = MemorySettings()
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.serverURL, "http://localhost:7500")

        store.serverURL = " http://example.test/ "

        XCTAssertEqual(store.serverURL, "http://example.test")
    }
}

private final class MemorySettings: KeyValueSettings, @unchecked Sendable {
    private var values: [String: Any] = [:]

    func string(forKey defaultName: String) -> String? {
        values[defaultName] as? String
    }

    func bool(forKey defaultName: String) -> Bool {
        values[defaultName] as? Bool ?? false
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }
}
