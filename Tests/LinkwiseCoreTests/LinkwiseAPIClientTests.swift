import Foundation
import XCTest
@testable import LinkwiseCore

final class LinkwiseAPIClientTests: XCTestCase {
    func testCreateBookmarkSendsBearerToken() async throws {
        let recorder = RequestRecorder()
        let httpClient = MockHTTPClient { request in
            await recorder.record(request)
            return (
                Data("""
                {"status":"ok","id":"1","title":"Example","url":"https://example.test","folder":"Inbox"}
                """.utf8),
                httpResponse(statusCode: 200)
            )
        }
        let client = LinkwiseAPIClient(
            serverURL: URL(string: "https://links.example.test")!,
            appToken: "lwapp_secret",
            httpClient: httpClient
        )

        _ = try await client.createBookmark(
            CreateBookmarkRequest(title: "Example", url: "https://example.test", folder: "Inbox")
        )

        let recordedRequest = await recorder.recordedRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer lwapp_secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testFetchBookmarksDoesNotSendBearerToken() async throws {
        let recorder = RequestRecorder()
        let httpClient = MockHTTPClient { request in
            await recorder.record(request)
            return (Data("[]".utf8), httpResponse(statusCode: 200))
        }
        let client = LinkwiseAPIClient(
            serverURL: URL(string: "https://links.example.test")!,
            appToken: "lwapp_secret",
            httpClient: httpClient
        )

        _ = try await client.fetchBookmarks()

        let recordedRequest = await recorder.recordedRequest()
        let request = try XCTUnwrap(recordedRequest)
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testMapsAppSessionRequiredError() async throws {
        let client = LinkwiseAPIClient(
            serverURL: URL(string: "https://links.example.test")!,
            appToken: "lwapp_secret",
            httpClient: MockHTTPClient(statusCode: 401, error: "app_session_required")
        )

        do {
            _ = try await client.createBookmark(
                CreateBookmarkRequest(title: "Example", url: "https://example.test", folder: "Inbox")
            )
            XCTFail("Expected appSessionRequired")
        } catch {
            XCTAssertEqual(error as? LinkwiseError, .appSessionRequired)
        }
    }

    func testMapsAdminSessionRequiredError() async throws {
        let client = LinkwiseAPIClient(
            serverURL: URL(string: "https://links.example.test")!,
            appToken: "lwapp_secret",
            httpClient: MockHTTPClient(statusCode: 401, error: "admin_session_required")
        )

        do {
            _ = try await client.createBookmark(
                CreateBookmarkRequest(title: "Example", url: "https://example.test", folder: "Inbox")
            )
            XCTFail("Expected adminSessionRequired")
        } catch {
            XCTAssertEqual(error as? LinkwiseError, .adminSessionRequired)
        }
    }

    func testMapsMixedAuthNotAllowedError() async throws {
        let client = LinkwiseAPIClient(
            serverURL: URL(string: "https://links.example.test")!,
            appToken: "lwapp_secret",
            httpClient: MockHTTPClient(statusCode: 400, error: "mixed_auth_not_allowed")
        )

        do {
            _ = try await client.createBookmark(
                CreateBookmarkRequest(title: "Example", url: "https://example.test", folder: "Inbox")
            )
            XCTFail("Expected mixedAuthNotAllowed")
        } catch {
            XCTAssertEqual(error as? LinkwiseError, .mixedAuthNotAllowed)
        }
    }
}

private final class MockHTTPClient: LinkwiseHTTPClient, @unchecked Sendable {
    private let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
        self.handler = handler
    }

    convenience init(statusCode: Int, error: String) {
        self.init { _ in
            (
                Data(#"{"error":"\#(error)","message":"Request failed"}"#.utf8),
                httpResponse(statusCode: statusCode)
            )
        }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

private actor RequestRecorder {
    private var lastRequest: URLRequest?

    func record(_ request: URLRequest) {
        lastRequest = request
    }

    func recordedRequest() -> URLRequest? {
        lastRequest
    }
}

private func httpResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://links.example.test/api/bookmarks")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}
