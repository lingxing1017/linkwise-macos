import AppKit
import Foundation
import LinkwiseCore

@MainActor
final class AppModel {
    let settingsStore: SettingsStore
    let cache: LocalCache
    private(set) var bookmarks: [Bookmark] = []
    private(set) var lastSyncAt: Date?
    private(set) var lastError: String?
    private(set) var browsers: [InstalledBrowser] = []
    var onChange: (() -> Void)?

    init(settingsStore: SettingsStore, cache: LocalCache) {
        self.settingsStore = settingsStore
        self.cache = cache
        self.browsers = BrowserDetector().installedBrowsers()
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

    func refreshBookmarks(showSuccess: Bool = true) async {
        do {
            let client = try LinkwiseAPIClient(serverURLString: settingsStore.serverURL)
            let fetched = try await client.fetchBookmarks()
            bookmarks = fetched
            lastSyncAt = Date()
            lastError = nil
            try cache.save(BookmarkCache(serverURL: settingsStore.serverURL, lastSyncAt: lastSyncAt, bookmarks: fetched))
            notifyChange()

            if showSuccess {
                AlertPresenter.showMessage("书签已刷新", informativeText: "已从 Linkwise 同步 \(fetched.count) 个书签。")
            }
        } catch {
            lastError = error.localizedDescription
            notifyChange()
            AlertPresenter.show(error)
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
        browsers = BrowserDetector().installedBrowsers()
        notifyChange()
    }

    func notifyChange() {
        onChange?()
    }
}

