import XCTest
@testable import LinkwiseApp

final class LinkwiseURLSchemeTests: XCTestCase {
    func testParsesSaveURL() throws {
        let page = try LinkwiseURLScheme.savePage(
            from: try XCTUnwrap(URL(string: "linkwise://save?url=https%3A%2F%2Fexample.com%2Fpost&title=Example%20Post&folder=Read%20Later"))
        )

        XCTAssertEqual(page, CurrentPage(
            title: "Example Post",
            url: "https://example.com/post",
            folder: "Read Later"
        ))
    }

    func testParsesPathStyleSaveURL() throws {
        let page = try LinkwiseURLScheme.savePage(
            from: try XCTUnwrap(URL(string: "linkwise://action/save?url=https%3A%2F%2Fexample.com"))
        )

        XCTAssertEqual(page, CurrentPage(title: "", url: "https://example.com"))
    }

    func testRejectsNonWebURL() throws {
        XCTAssertThrowsError(
            try LinkwiseURLScheme.savePage(
                from: try XCTUnwrap(URL(string: "linkwise://save?url=about%3Ablank"))
            )
        )
    }

    func testRejectsDifferentAction() throws {
        XCTAssertThrowsError(
            try LinkwiseURLScheme.savePage(
                from: try XCTUnwrap(URL(string: "linkwise://open?url=https%3A%2F%2Fexample.com"))
            )
        )
    }

    func testSavableURLRequiresHTTPHost() {
        XCTAssertTrue(CurrentPage.isSavableURL("https://example.com/path"))
        XCTAssertTrue(CurrentPage.isSavableURL("http://example.com"))
        XCTAssertFalse(CurrentPage.isSavableURL("about:blank"))
        XCTAssertFalse(CurrentPage.isSavableURL("https://"))
    }
}
