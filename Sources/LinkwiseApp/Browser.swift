import AppKit
import Foundation
import LinkwiseCore

struct InstalledBrowser: Equatable, Sendable {
    let name: String
    let bundleIdentifier: String
    let appURL: URL
}

struct BrowserDefinition: Sendable {
    let name: String
    let bundleIdentifier: String
}

enum BrowserCatalog {
    static let supported: [BrowserDefinition] = [
        BrowserDefinition(name: "Safari", bundleIdentifier: "com.apple.Safari"),
        BrowserDefinition(name: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
        BrowserDefinition(name: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac"),
        BrowserDefinition(name: "Firefox", bundleIdentifier: "org.mozilla.firefox"),
        BrowserDefinition(name: "Brave Browser", bundleIdentifier: "com.brave.Browser"),
        BrowserDefinition(name: "Arc", bundleIdentifier: "company.thebrowser.Browser"),
        BrowserDefinition(name: "Opera", bundleIdentifier: "com.operasoftware.Opera")
    ]
}

struct BrowserDetector {
    func installedBrowsers() -> [InstalledBrowser] {
        let workspace = NSWorkspace.shared
        var found: [InstalledBrowser] = []
        var seen = Set<String>()

        for definition in BrowserCatalog.supported {
            guard let appURL = workspace.urlForApplication(withBundleIdentifier: definition.bundleIdentifier),
                  !seen.contains(definition.bundleIdentifier)
            else {
                continue
            }

            found.append(InstalledBrowser(
                name: definition.name,
                bundleIdentifier: definition.bundleIdentifier,
                appURL: appURL
            ))
            seen.insert(definition.bundleIdentifier)
        }

        return found
    }
}

@MainActor
enum BrowserLauncher {
    static func open(_ bookmark: BookmarkViewModel, using browser: InstalledBrowser? = nil) throws {
        guard let url = URL(string: bookmark.url),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else {
            throw AppActionError.invalidURL
        }

        if let browser {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([url], withApplicationAt: browser.appURL, configuration: configuration)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}

enum AppActionError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "当前书签 URL 无法打开。"
        }
    }
}

struct BookmarkViewModel {
    let id: String
    let title: String
    let url: String
    let folder: String

    init(_ bookmark: LinkwiseCore.Bookmark) {
        self.id = bookmark.id
        self.title = bookmark.title.isEmpty ? bookmark.url : bookmark.title
        self.url = bookmark.url
        self.folder = bookmark.folder
    }
}
