import Foundation

public protocol LinkwiseHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: LinkwiseHTTPClient {}

public struct LinkwiseAPIClient: Sendable {
    private let serverURL: URL
    private let httpClient: LinkwiseHTTPClient
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(serverURL: URL, httpClient: LinkwiseHTTPClient = URLSession.shared) {
        self.serverURL = serverURL
        self.httpClient = httpClient
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    public init(serverURLString: String, httpClient: LinkwiseHTTPClient = URLSession.shared) throws {
        guard let url = URL(string: serverURLString.normalizedServerURLString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            throw LinkwiseError.invalidServerURL
        }

        self.init(serverURL: url, httpClient: httpClient)
    }

    public func health() async throws -> HealthResponse {
        try await send(path: "/api/health", method: "GET", body: Optional<Data>.none)
    }

    public func fetchBookmarks() async throws -> [Bookmark] {
        try await send(path: "/api/bookmarks", method: "GET", body: Optional<Data>.none)
    }

    public func createBookmark(_ request: CreateBookmarkRequest) async throws -> CreateBookmarkResponse {
        let body = try encoder.encode(request)
        return try await send(path: "/api/bookmarks", method: "POST", body: body)
    }

    public func recordOpen(bookmarkID: String) async throws {
        let encodedID = bookmarkID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bookmarkID
        let _: EmptyResponse = try await send(path: "/api/bookmarks/\(encodedID)/open", method: "POST", body: Data())
    }

    private func send<Response: Decodable>(path: String, method: String, body: Data?) async throws -> Response {
        let url = serverURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await httpClient.data(for: request)
        } catch let error as LinkwiseError {
            throw error
        } catch {
            throw LinkwiseError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinkwiseError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? decoder.decode(APIErrorResponse.self, from: data)

            if httpResponse.statusCode == 409 || apiError?.status == "duplicate" || apiError?.error == "duplicate_url" {
                throw LinkwiseError.duplicateURL(
                    message: apiError?.message ?? "该 URL 已存在于 Linkwise。",
                    bookmark: apiError?.bookmark
                )
            }

            throw LinkwiseError.httpStatus(
                httpResponse.statusCode,
                message: apiError?.message,
                code: apiError?.error ?? apiError?.status
            )
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw LinkwiseError.decoding(error.localizedDescription)
        }
    }
}

public struct EmptyResponse: Codable, Equatable, Sendable {
    public init() {}
}

public extension String {
    var normalizedServerURLString: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix("/") else {
            return trimmed
        }

        return String(trimmed.dropLast())
    }
}

