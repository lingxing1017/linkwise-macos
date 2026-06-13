import Foundation

public struct BookmarkCache: Codable, Equatable, Sendable {
    public var serverURL: String
    public var lastSyncAt: Date?
    public var bookmarks: [Bookmark]

    public init(serverURL: String, lastSyncAt: Date? = nil, bookmarks: [Bookmark] = []) {
        self.serverURL = serverURL
        self.lastSyncAt = lastSyncAt
        self.bookmarks = bookmarks
    }

    enum CodingKeys: String, CodingKey {
        case serverURL = "server_url"
        case lastSyncAt = "last_sync_at"
        case bookmarks
    }
}

public struct LocalCache: Sendable {
    public let fileURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(fileURL: URL? = nil) {
        let resolvedURL: URL

        if let fileURL {
            resolvedURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            resolvedURL = base
                .appendingPathComponent("Linkwise", isDirectory: true)
                .appendingPathComponent("cache.json")
        }

        self.fileURL = resolvedURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
    }

    public func load() throws -> BookmarkCache? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(BookmarkCache.self, from: data)
        } catch {
            throw LinkwiseError.cache(error.localizedDescription)
        }
    }

    public func save(_ cache: BookmarkCache) throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw LinkwiseError.cache(error.localizedDescription)
        }
    }
}

