import AppKit
import XCTest
@testable import LinkwiseApp

@MainActor
final class AppMainMenuTests: XCTestCase {
    func testBuildsEditMenuWithTextEditingCommands() throws {
        let menu = AppMainMenu.build()
        let editItem = try XCTUnwrap(menu.items.first { $0.title == "Edit" })
        let editMenu = try XCTUnwrap(editItem.submenu)

        XCTAssertMenuItem(
            in: editMenu,
            titled: "Cut",
            keyEquivalent: "x",
            action: #selector(NSText.cut(_:))
        )
        XCTAssertMenuItem(
            in: editMenu,
            titled: "Copy",
            keyEquivalent: "c",
            action: #selector(NSText.copy(_:))
        )
        XCTAssertMenuItem(
            in: editMenu,
            titled: "Paste",
            keyEquivalent: "v",
            action: #selector(NSText.paste(_:))
        )
        XCTAssertMenuItem(
            in: editMenu,
            titled: "Select All",
            keyEquivalent: "a",
            action: #selector(NSText.selectAll(_:))
        )
    }

    private func XCTAssertMenuItem(
        in menu: NSMenu,
        titled title: String,
        keyEquivalent: String,
        action: Selector,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let item = menu.items.first(where: { $0.title == title }) else {
            XCTFail("Missing menu item \(title)", file: file, line: line)
            return
        }

        XCTAssertEqual(item.keyEquivalent, keyEquivalent, file: file, line: line)
        XCTAssertEqual(item.action, action, file: file, line: line)
        XCTAssertNil(item.target, file: file, line: line)
    }
}
