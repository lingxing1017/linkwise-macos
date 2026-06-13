import XCTest
@testable import LinkwiseCore

final class LocalCacheTests: XCTestCase {
    func testSavesAndLoadsCache() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("cache.json")
        let cache = LocalCache(fileURL: url)
        let payload = BookmarkCache(
            serverURL: "http://localhost:7500",
            lastSyncAt: Date(timeIntervalSince1970: 1_800_000_000),
            bookmarks: [
                Bookmark(id: "1", title: "Example", url: "https://example.test")
            ]
        )

        try cache.save(payload)

        XCTAssertEqual(try cache.load(), payload)
    }
}

