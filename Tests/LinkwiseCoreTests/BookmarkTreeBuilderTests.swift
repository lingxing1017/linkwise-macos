import XCTest
@testable import LinkwiseCore

final class BookmarkTreeBuilderTests: XCTestCase {
    func testBuildsNestedFolders() {
        let bookmarks = [
            Bookmark(id: "1", title: "Flask", url: "https://flask.test", folder: "Dev / Python", sortOrder: 1),
            Bookmark(id: "2", title: "Python", url: "https://python.test", folder: " Dev/Python ", sortOrder: 0),
            Bookmark(id: "3", title: "Loose", url: "https://loose.test", folder: "")
        ]

        let tree = BookmarkTreeBuilder.build(from: bookmarks)

        XCTAssertEqual(tree.bookmarks.map(\.title), ["Loose"])
        XCTAssertEqual(tree.folders.map(\.name), ["Dev"])
        XCTAssertEqual(tree.folders[0].folders.map(\.name), ["Python"])
        XCTAssertEqual(tree.folders[0].folders[0].bookmarks.map(\.title), ["Python", "Flask"])
    }

    func testFolderPartsIgnoreEmptySegments() {
        XCTAssertEqual(BookmarkTreeBuilder.folderParts(" A / / B/C "), ["A", "B", "C"])
    }
}

