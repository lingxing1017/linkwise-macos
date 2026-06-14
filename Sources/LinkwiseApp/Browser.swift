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
    static let builtIn: [BrowserDefinition] = [
        BrowserDefinition(name: "Safari", bundleIdentifier: "com.apple.Safari"),
        BrowserDefinition(name: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
        BrowserDefinition(name: "Microsoft Edge", bundleIdentifier: "com.microsoft.edgemac"),
        BrowserDefinition(name: "Firefox", bundleIdentifier: "org.mozilla.firefox"),
        BrowserDefinition(name: "Brave Browser", bundleIdentifier: "com.brave.Browser"),
        BrowserDefinition(name: "Arc", bundleIdentifier: "company.thebrowser.Browser"),
        BrowserDefinition(name: "Opera", bundleIdentifier: "com.operasoftware.Opera"),
        BrowserDefinition(name: "Helium", bundleIdentifier: "net.imput.helium"),
        BrowserDefinition(name: "Vivaldi", bundleIdentifier: "com.vivaldi.Vivaldi"),
        BrowserDefinition(name: "Chromium", bundleIdentifier: "org.chromium.Chromium"),
        BrowserDefinition(name: "Tor Browser", bundleIdentifier: "org.torproject.torbrowser"),
        BrowserDefinition(name: "Orion", bundleIdentifier: "com.kagi.kagimacOS"),
        BrowserDefinition(name: "Dia", bundleIdentifier: "company.thebrowser.dia"),
        BrowserDefinition(name: "Comet", bundleIdentifier: "com.perplexity.comet")
    ]

    static var builtInIDs: Set<String> {
        Set(builtIn.map(\.bundleIdentifier))
    }

    static func displayName(for bundleIdentifier: String, fallback: String) -> String {
        if let definition = builtIn.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return definition.name
        }

        return fallback
    }
}

struct CustomBrowserRecord: Codable, Equatable, Sendable {
    let name: String
    let bundleIdentifier: String
    let path: String
}

struct CustomBrowserStore: Sendable {
    private static let key = "customBrowsers"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [CustomBrowserRecord] {
        guard let data = defaults.data(forKey: Self.key),
              let records = try? JSONDecoder().decode([CustomBrowserRecord].self, from: data)
        else {
            return []
        }

        return records
    }

    func add(_ browser: InstalledBrowser) {
        var records = load()
        records.removeAll { $0.bundleIdentifier == browser.bundleIdentifier }
        records.append(CustomBrowserRecord(
            name: browser.name,
            bundleIdentifier: browser.bundleIdentifier,
            path: browser.appURL.path
        ))

        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

struct BrowserDetector: @unchecked Sendable {
    private let applicationDirectories: [URL]
    private let customBrowsers: [CustomBrowserRecord]
    private let fileManager: FileManager

    init(
        applicationDirectories: [URL]? = nil,
        customBrowsers: [CustomBrowserRecord] = [],
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.customBrowsers = customBrowsers

        if let applicationDirectories {
            self.applicationDirectories = applicationDirectories
        } else {
            self.applicationDirectories = [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Applications", isDirectory: true)
            ]
        }
    }

    func installedBrowsers() -> [InstalledBrowser] {
        let workspace = NSWorkspace.shared
        var found: [InstalledBrowser] = []
        var seen = Set<String>()

        for definition in BrowserCatalog.builtIn {
            guard !seen.contains(definition.bundleIdentifier) else {
                continue
            }

            if let appURL = workspace.urlForApplication(withBundleIdentifier: definition.bundleIdentifier) {
                found.append(InstalledBrowser(
                    name: definition.name,
                    bundleIdentifier: definition.bundleIdentifier,
                    appURL: appURL
                ))
                seen.insert(definition.bundleIdentifier)
            }
        }

        for browser in scannedBrowserApps() where !seen.contains(browser.bundleIdentifier) {
            found.append(browser)
            seen.insert(browser.bundleIdentifier)
        }

        for browser in installedCustomBrowsers() where !seen.contains(browser.bundleIdentifier) {
            found.append(browser)
            seen.insert(browser.bundleIdentifier)
        }

        return found
    }

    func scannedBrowserApps() -> [InstalledBrowser] {
        var browsers: [InstalledBrowser] = []

        for directory in applicationDirectories {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let appURL as URL in enumerator where appURL.pathExtension == "app" {
                guard let browser = browserFromAppBundle(appURL) else {
                    continue
                }

                browsers.append(browser)
            }
        }

        return browsers.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func customBrowser(from appURL: URL) -> InstalledBrowser? {
        browserFromAppBundle(appURL)
    }

    private func installedCustomBrowsers() -> [InstalledBrowser] {
        customBrowsers.compactMap { record in
            let appURL = URL(fileURLWithPath: record.path, isDirectory: true)
            guard let browser = customBrowser(from: appURL),
                  browser.bundleIdentifier == record.bundleIdentifier
            else {
                return nil
            }

            return InstalledBrowser(
                name: record.name,
                bundleIdentifier: record.bundleIdentifier,
                appURL: browser.appURL
            )
        }
    }

    private func browserFromAppBundle(_ appURL: URL) -> InstalledBrowser? {
        let infoURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")

        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any],
              let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
              supportsWebURLSchemes(plist),
              supportsHTMLDocuments(plist)
        else {
            return nil
        }

        let fallbackName = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        return InstalledBrowser(
            name: BrowserCatalog.displayName(for: bundleIdentifier, fallback: fallbackName),
            bundleIdentifier: bundleIdentifier,
            appURL: appURL
        )
    }

    private func supportsWebURLSchemes(_ plist: [String: Any]) -> Bool {
        guard let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]] else {
            return false
        }

        return urlTypes.contains { type in
            guard let schemes = type["CFBundleURLSchemes"] as? [String] else {
                return false
            }

            let normalizedSchemes = Set(schemes.map { $0.lowercased() })
            return normalizedSchemes.contains("http") || normalizedSchemes.contains("https")
        }
    }

    private func supportsHTMLDocuments(_ plist: [String: Any]) -> Bool {
        guard let documentTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]] else {
            return false
        }

        return documentTypes.contains { type in
            let extensions = (type["CFBundleTypeExtensions"] as? [String] ?? [])
                .map { $0.lowercased() }
            let contentTypes = (type["LSItemContentTypes"] as? [String] ?? [])
                .map { $0.lowercased() }

            return extensions.contains("html") ||
                extensions.contains("htm") ||
                contentTypes.contains("public.html") ||
                contentTypes.contains("public.xhtml")
        }
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
