import Foundation

public struct BookmarkTree: Equatable, Sendable {
    public var folders: [FolderNode]
    public var bookmarks: [Bookmark]

    public init(folders: [FolderNode] = [], bookmarks: [Bookmark] = []) {
        self.folders = folders
        self.bookmarks = bookmarks
    }
}

public final class FolderNode: Equatable, Sendable {
    public let name: String
    public let folders: [FolderNode]
    public let bookmarks: [Bookmark]

    public init(name: String, folders: [FolderNode] = [], bookmarks: [Bookmark] = []) {
        self.name = name
        self.folders = folders
        self.bookmarks = bookmarks
    }

    public static func == (lhs: FolderNode, rhs: FolderNode) -> Bool {
        lhs.name == rhs.name &&
            lhs.folders == rhs.folders &&
            lhs.bookmarks == rhs.bookmarks
    }
}

public enum BookmarkTreeBuilder {
    public static func build(from bookmarks: [Bookmark]) -> BookmarkTree {
        let root = MutableFolderNode(name: "")

        for bookmark in bookmarks {
            let parts = folderParts(bookmark.folder)

            guard !parts.isEmpty else {
                root.bookmarks.append(bookmark)
                continue
            }

            var current = root

            for part in parts {
                current = current.child(named: part)
            }

            current.bookmarks.append(bookmark)
        }

        return BookmarkTree(
            folders: root.children.values.map(freeze).sorted(by: folderSort),
            bookmarks: root.bookmarks.sorted(by: bookmarkSort)
        )
    }

    public static func folderParts(_ folder: String) -> [String] {
        folder
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func freeze(_ node: MutableFolderNode) -> FolderNode {
        FolderNode(
            name: node.name,
            folders: node.children.values.map(freeze).sorted(by: folderSort),
            bookmarks: node.bookmarks.sorted(by: bookmarkSort)
        )
    }

    private static func folderSort(_ lhs: FolderNode, _ rhs: FolderNode) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func bookmarkSort(_ lhs: Bookmark, _ rhs: Bookmark) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

private final class MutableFolderNode {
    let name: String
    var children: [String: MutableFolderNode] = [:]
    var bookmarks: [Bookmark] = []

    init(name: String) {
        self.name = name
    }

    func child(named name: String) -> MutableFolderNode {
        if let existing = children[name] {
            return existing
        }

        let node = MutableFolderNode(name: name)
        children[name] = node
        return node
    }
}
