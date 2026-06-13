import Foundation

public struct Bookmark: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var title: String
    public var url: String
    public var folder: String
    public var sortOrder: Int
    public var createdAt: String?
    public var updatedAt: String?
    public var lastOpenedAt: String?
    public var openCount: Int?

    public init(
        id: String,
        title: String,
        url: String,
        folder: String = "",
        sortOrder: Int = 0,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        lastOpenedAt: String? = nil,
        openCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.folder = folder
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.openCount = openCount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case folder
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastOpenedAt = "last_opened_at"
        case openCount = "open_count"
    }
}

public struct CreateBookmarkRequest: Codable, Equatable, Sendable {
    public var title: String
    public var url: String
    public var folder: String
    public var source: String

    public init(title: String, url: String, folder: String, source: String = "macos-app") {
        self.title = title
        self.url = url
        self.folder = folder
        self.source = source
    }
}

public struct CreateBookmarkResponse: Codable, Equatable, Sendable {
    public var status: String?
    public var id: String
    public var title: String
    public var url: String
    public var folder: String
    public var totalCount: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case id
        case title
        case url
        case folder
        case totalCount = "total_count"
    }
}

public struct HealthResponse: Codable, Equatable, Sendable {
    public var status: String
    public var app: String?
    public var version: String?
}

public struct APIErrorResponse: Codable, Equatable, Sendable {
    public var status: String?
    public var error: String?
    public var message: String?
    public var bookmark: Bookmark?
}

