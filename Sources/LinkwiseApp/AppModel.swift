import AppKit
import Foundation
import LinkwiseCore

@MainActor
final class AppModel {
    let settingsStore: SettingsStore
    let cache: LocalCache
    private let customBrowserStore = CustomBrowserStore()
    private(set) var bookmarks: [Bookmark] = []
    private(set) var lastSyncAt: Date?
    private(set) var lastError: String?
    private(set) var isRefreshing = false
    private(set) var browsers: [InstalledBrowser] = []
    var onChange: (() -> Void)?

    init(settingsStore: SettingsStore, cache: LocalCache) {
        self.settingsStore = settingsStore
        self.cache = cache
        self.browsers = BrowserDetector(customBrowsers: customBrowserStore.load()).installedBrowsers()
    }

    var serverURL: String {
        settingsStore.serverURL
    }

    func loadCachedBookmarks() {
        do {
            if let cached = try cache.load() {
                bookmarks = cached.bookmarks
                lastSyncAt = cached.lastSyncAt
                lastError = nil
                notifyChange()
            }
        } catch {
            lastError = error.localizedDescription
            notifyChange()
        }
    }

    func refreshBookmarks(showSuccess: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        notifyChange()

        defer {
            isRefreshing = false
            notifyChange()
        }

        do {
            let client = try LinkwiseAPIClient(serverURLString: settingsStore.serverURL)
            let fetched = try await client.fetchBookmarks()
            bookmarks = fetched
            lastSyncAt = Date()
            lastError = nil
            try cache.save(BookmarkCache(serverURL: settingsStore.serverURL, lastSyncAt: lastSyncAt, bookmarks: fetched))

            if showSuccess {
                AlertPresenter.showMessage("书签已刷新", informativeText: "已从 Linkwise 同步 \(fetched.count) 个书签。")
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func testConnection() async -> Bool {
        do {
            let client = try LinkwiseAPIClient(serverURLString: settingsStore.serverURL)
            _ = try await client.health()
            AlertPresenter.showMessage("连接成功", informativeText: "Linkwise 服务可用。")
            return true
        } catch {
            AlertPresenter.show(error)
            return false
        }
    }

    func createBookmark(title: String, url: String, folder: String) async -> Bool {
        do {
            let client = try LinkwiseAPIClient(serverURLString: settingsStore.serverURL)
            _ = try await client.createBookmark(CreateBookmarkRequest(title: title, url: url, folder: folder))
            await refreshBookmarks(showSuccess: false)
            AlertPresenter.showMessage("保存成功", informativeText: "当前页面已保存到 Linkwise。")
            return true
        } catch {
            AlertPresenter.show(error)
            return false
        }
    }

    func recordOpen(bookmark: Bookmark) {
        Task {
            do {
                let client = try LinkwiseAPIClient(serverURLString: settingsStore.serverURL)
                try await client.recordOpen(bookmarkID: bookmark.id)
            } catch {
                // Opening the URL is the primary action; usage tracking is best effort.
            }
        }
    }

    func rescanBrowsers() {
        browsers = BrowserDetector(customBrowsers: customBrowserStore.load()).installedBrowsers()
        notifyChange()
    }

    func addCustomBrowser(appURL: URL) -> Bool {
        guard let browser = BrowserDetector().customBrowser(from: appURL) else {
            AlertPresenter.showMessage("无法添加浏览器", informativeText: "请选择支持 http 或 https 链接的 macOS App。")
            return false
        }

        customBrowserStore.add(browser)
        browsers = BrowserDetector(customBrowsers: customBrowserStore.load()).installedBrowsers()
        notifyChange()
        return true
    }

    func notifyChange() {
        onChange?()
    }
}
