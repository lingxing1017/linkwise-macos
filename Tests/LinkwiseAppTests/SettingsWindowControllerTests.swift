import XCTest
@testable import LinkwiseCore
@testable import LinkwiseApp

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testTokenStatusIsDisplayedBesideTokenTitle() {
        let controller = SettingsWindowController(model: makeModel(token: "lwapp_secret"))

        XCTAssertTrue(controller.tokenStatusIsInTitleRowForTesting)
    }

    func testTokenFieldUsesSingleLineDisplay() {
        let controller = SettingsWindowController(model: makeModel(token: "lwapp_secret"))

        XCTAssertTrue(controller.tokenFieldUsesSingleLineModeForTesting)
        XCTAssertFalse(controller.tokenFieldWrapsForTesting)
    }

    private func makeModel(token: String?) -> AppModel {
        let defaults = MemorySettings()
        defaults.set("https://links.example.test", forKey: SettingsStore.serverURLKey)
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("cache.json")
        return AppModel(
            settingsStore: SettingsStore(defaults: defaults),
            cache: LocalCache(fileURL: cacheURL),
            appTokenStore: MemoryAppTokenStore(token: token),
            alertPresenter: { _, _ in }
        )
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
