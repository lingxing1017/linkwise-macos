import Foundation
import XCTest
@testable import LinkwiseCore
@testable import LinkwiseApp

@MainActor
final class AppModelTests: XCTestCase {
    func testWriteAuthStateReflectsMissingToken() {
        let model = makeModel(tokenStore: MemoryAppTokenStore())

        XCTAssertFalse(model.hasAppToken)
        XCTAssertEqual(model.writeAuthState, .unpaired)
    }

    func testWriteAuthStateReflectsStoredToken() {
        let model = makeModel(tokenStore: MemoryAppTokenStore(token: "lwapp_secret"))

        XCTAssertTrue(model.hasAppToken)
        XCTAssertEqual(model.writeAuthState, .paired)
    }

    func testRefreshBookmarksUsesPublicClientEvenWhenTokenExists() async {
        let records = ClientFactoryRecords()
        let model = makeModel(
            tokenStore: MemoryAppTokenStore(token: "lwapp_secret"),
            clientFactory: records.factory(client: StubLinkwiseClient(bookmarks: [
                Bookmark(id: "1", title: "Example", url: "https://example.test")
            ]))
        )

        await model.refreshBookmarks()

        XCTAssertEqual(records.tokens, [nil])
        XCTAssertEqual(model.bookmarks.count, 1)
        XCTAssertEqual(model.readConnectionState, .available)
    }

    func testCreateAuthorizedClientUsesStoredToken() throws {
        let records = ClientFactoryRecords()
        let model = makeModel(
            tokenStore: MemoryAppTokenStore(token: "lwapp_secret"),
            clientFactory: records.factory(client: StubLinkwiseClient())
        )

        _ = try model.createAuthorizedClient()

        XCTAssertEqual(records.tokens, ["lwapp_secret"])
        XCTAssertEqual(model.writeAuthState, .paired)
    }

    func testCreateAuthorizedClientWithoutTokenMarksUnpaired() {
        let model = makeModel(tokenStore: MemoryAppTokenStore())

        XCTAssertThrowsError(try model.createAuthorizedClient()) { error in
            XCTAssertEqual(error as? LinkwiseError, .appSessionRequired)
        }
        XCTAssertEqual(model.writeAuthState, .unpaired)
    }

    func testAppSessionRequiredMarksWriteAuthNeedsRepairing() {
        let model = makeModel(tokenStore: MemoryAppTokenStore(token: "lwapp_secret"))

        model.handleWriteFailure(LinkwiseError.appSessionRequired)

        XCTAssertEqual(model.writeAuthState, .needsRepairing)
    }

    func testSaveAppTokenTrimsAndUpdatesAuthState() throws {
        let tokenStore = MemoryAppTokenStore()
        let model = makeModel(tokenStore: tokenStore)

        let saved = try model.saveAppTokenIfPresent("  lwapp_secret  ")

        XCTAssertTrue(saved)
        XCTAssertEqual(try tokenStore.loadToken(), "lwapp_secret")
        XCTAssertEqual(model.appTokenPrefix, "lwapp_secret")
        XCTAssertEqual(model.writeAuthState, .paired)
    }

    func testBlankAppTokenInputDoesNotOverwriteExistingToken() throws {
        let tokenStore = MemoryAppTokenStore(token: "lwapp_existing")
        let model = makeModel(tokenStore: tokenStore)

        let saved = try model.saveAppTokenIfPresent("   ")

        XCTAssertFalse(saved)
        XCTAssertEqual(try tokenStore.loadToken(), "lwapp_existing")
        XCTAssertEqual(model.writeAuthState, .paired)
    }

    func testRejectsInvalidAppTokenPrefix() {
        let model = makeModel(tokenStore: MemoryAppTokenStore())

        XCTAssertThrowsError(try model.saveAppTokenIfPresent("not-a-token")) { error in
            XCTAssertEqual(error as? LinkwiseError, .invalidAppToken)
        }
        XCTAssertEqual(model.writeAuthState, .unpaired)
    }

    func testDeleteAppTokenClearsStoredTokenAndAuthState() throws {
        let tokenStore = MemoryAppTokenStore(token: "lwapp_secret")
        let model = makeModel(tokenStore: tokenStore)

        try model.deleteAppToken()

        XCTAssertNil(try tokenStore.loadToken())
        XCTAssertNil(model.appTokenPrefix)
        XCTAssertEqual(model.writeAuthState, .unpaired)
    }

    func testCreateBookmarkWithoutTokenDoesNotCallClientFactory() async {
        let records = ClientFactoryRecords()
        let model = makeModel(
            tokenStore: MemoryAppTokenStore(),
            clientFactory: records.factory(client: StubLinkwiseClient())
        )

        let success = await model.createBookmark(title: "Example", url: "https://example.test", folder: "Inbox")

        XCTAssertFalse(success)
        XCTAssertTrue(records.tokens.isEmpty)
        XCTAssertEqual(model.writeAuthState, .unpaired)
    }

    func testCreateBookmarkUsesAuthorizedClientThenRefreshesPublicly() async {
        let records = ClientFactoryRecords()
        let model = makeModel(
            tokenStore: MemoryAppTokenStore(token: "lwapp_secret"),
            clientFactory: records.factory(client: StubLinkwiseClient(bookmarks: [
                Bookmark(id: "1", title: "Example", url: "https://example.test")
            ]))
        )

        let success = await model.createBookmark(title: "Example", url: "https://example.test", folder: "Inbox")

        XCTAssertTrue(success)
        XCTAssertEqual(records.tokens, ["lwapp_secret", nil])
        XCTAssertEqual(model.writeAuthState, .paired)
        XCTAssertEqual(model.bookmarks.count, 1)
    }

    func testCreateBookmarkAppSessionRequiredMarksNeedsRepairing() async {
        let model = makeModel(
            tokenStore: MemoryAppTokenStore(token: "lwapp_secret"),
            clientFactory: { _, _ in StubLinkwiseClient(createError: LinkwiseError.appSessionRequired) }
        )

        let success = await model.createBookmark(title: "Example", url: "https://example.test", folder: "Inbox")

        XCTAssertFalse(success)
        XCTAssertEqual(model.writeAuthState, .needsRepairing)
    }

    private func makeModel(
        tokenStore: AppTokenStore,
        clientFactory: @escaping LinkwiseAPIClientFactory = { _, _ in StubLinkwiseClient() }
    ) -> AppModel {
        let defaults = MemorySettings()
        defaults.set("https://links.example.test", forKey: SettingsStore.serverURLKey)
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("cache.json")
        return AppModel(
            settingsStore: SettingsStore(defaults: defaults),
            cache: LocalCache(fileURL: cacheURL),
            appTokenStore: tokenStore,
            apiClientFactory: clientFactory,
            alertPresenter: { _, _ in }
        )
    }
}

private final class ClientFactoryRecords: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedTokens: [String?] = []

    var tokens: [String?] {
        lock.withLock {
            recordedTokens
        }
    }

    func factory(client: any LinkwiseAPIClientProtocol) -> LinkwiseAPIClientFactory {
        { _, token in
            self.lock.withLock {
                self.recordedTokens.append(token)
            }
            return client
        }
    }
}

private final class StubLinkwiseClient: LinkwiseAPIClientProtocol, @unchecked Sendable {
    var bookmarks: [Bookmark]
    var createError: Error?

    init(bookmarks: [Bookmark] = [], createError: Error? = nil) {
        self.bookmarks = bookmarks
        self.createError = createError
    }

    func health() async throws -> HealthResponse {
        HealthResponse(status: "ok")
    }

    func fetchBookmarks() async throws -> [Bookmark] {
        bookmarks
    }

    func createBookmark(_ request: CreateBookmarkRequest) async throws -> CreateBookmarkResponse {
        if let createError {
            throw createError
        }

        return CreateBookmarkResponse(status: "ok", id: "1", title: request.title, url: request.url, folder: request.folder)
    }

    func recordOpen(bookmarkID: String) async throws {}
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
