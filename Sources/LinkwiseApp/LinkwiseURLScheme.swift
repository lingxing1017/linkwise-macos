import Foundation
import LinkwiseCore

enum LinkwiseURLScheme {
    static func savePage(from url: URL) throws -> CurrentPage {
        guard url.scheme?.lowercased() == "linkwise",
              isSaveAction(url)
        else {
            throw LinkwiseError.invalidBookmarkURL(url.absoluteString)
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let pageURL = value(for: "url", in: items)
        let title = value(for: "title", in: items) ?? ""
        let folder = value(for: "folder", in: items) ?? ""

        guard let pageURL,
              CurrentPage.isSavableURL(pageURL)
        else {
            throw LinkwiseError.invalidBookmarkURL(pageURL ?? url.absoluteString)
        }

        return CurrentPage(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: pageURL.trimmingCharacters(in: .whitespacesAndNewlines),
            folder: folder.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func isSaveAction(_ url: URL) -> Bool {
        if url.host?.lowercased() == "save" {
            return true
        }

        return url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased() == "save"
    }

    private static func value(for name: String, in items: [URLQueryItem]) -> String? {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
