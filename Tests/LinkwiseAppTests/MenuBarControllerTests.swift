import XCTest
@testable import LinkwiseCore
@testable import LinkwiseApp

@MainActor
final class MenuBarControllerTests: XCTestCase {
    func testHidesSaveCurrentPageWhenAppIsUnpaired() {
        let model = makeModel(tokenStore: MemoryAppTokenStore())
        let controller = MenuBarController(model: model, onOpenSettings: {}, onSaveCurrentPage: {})

        controller.rebuildMenu()

        XCTAssertFalse(controller.menuItemTitlesForTesting.contains("保存当前页面"))
    }

    func testShowsSaveCurrentPageWhenAppIsPaired() {
        let model = makeModel(tokenStore: MemoryAppTokenStore(token: "lwapp_secret"))
        let controller = MenuBarController(model: model, onOpenSettings: {}, onSaveCurrentPage: {})

        controller.rebuildMenu()

        XCTAssertTrue(controller.menuItemTitlesForTesting.contains("保存当前页面"))
    }

    private func makeModel(tokenStore: AppTokenStore) -> AppModel {
        let defaults = MemorySettings()
        defaults.set("https://links.example.test", forKey: SettingsStore.serverURLKey)
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("cache.json")
        return AppModel(
            settingsStore: SettingsStore(defaults: defaults),
            cache: LocalCache(fileURL: cacheURL),
            appTokenStore: tokenStore,
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
