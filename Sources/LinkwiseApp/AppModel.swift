import AppKit
import Foundation
import LinkwiseCore

enum ReadConnectionState: Equatable {
    case unconfigured
    case idle
    case refreshing
    case available
    case failed(String)
}

enum WriteAuthState: Equatable {
    case unpaired
    case paired
    case needsRepairing
}

protocol LinkwiseAPIClientProtocol: Sendable {
    func health() async throws -> HealthResponse
    func fetchBookmarks() async throws -> [Bookmark]
    func createBookmark(_ request: CreateBookmarkRequest) async throws -> CreateBookmarkResponse
    func recordOpen(bookmarkID: String) async throws
}

extension LinkwiseAPIClient: LinkwiseAPIClientProtocol {}

typealias LinkwiseAPIClientFactory = @Sendable (_ serverURL: String, _ appToken: String?) throws -> any LinkwiseAPIClientProtocol
typealias AlertPresenterHandler = @MainActor @Sendable (_ message: String, _ informativeText: String) -> Void

@MainActor
final class AppModel {
    let settingsStore: SettingsStore
    let cache: LocalCache
    private let appTokenStore: AppTokenStore
    private let apiClientFactory: LinkwiseAPIClientFactory
    private let alertPresenter: AlertPresenterHandler
    private let customBrowserStore = CustomBrowserStore()
    private(set) var bookmarks: [Bookmark] = []
    private(set) var lastSyncAt: Date?
    private(set) var lastError: String?
    private(set) var isRefreshing = false
    private(set) var browsers: [InstalledBrowser] = []
    private(set) var readConnectionState: ReadConnectionState
    private(set) var writeAuthState: WriteAuthState
    var onChange: (() -> Void)?

    init(
        settingsStore: SettingsStore,
        cache: LocalCache,
        appTokenStore: AppTokenStore = KeychainAppTokenStore(),
        apiClientFactory: @escaping LinkwiseAPIClientFactory = { serverURL, appToken in
            try LinkwiseAPIClient(serverURLString: serverURL, appToken: appToken)
        },
        alertPresenter: @escaping AlertPresenterHandler = { message, informativeText in
            AlertPresenter.showMessage(message, informativeText: informativeText)
        }
    ) {
        self.settingsStore = settingsStore
        self.cache = cache
        self.appTokenStore = appTokenStore
        self.apiClientFactory = apiClientFactory
        self.alertPresenter = alertPresenter
        self.readConnectionState = settingsStore.serverURL.isEmpty ? .unconfigured : .idle
        self.writeAuthState = ((try? appTokenStore.loadToken())?.isEmpty == false) ? .paired : .unpaired
        self.browsers = BrowserDetector(customBrowsers: customBrowserStore.load()).installedBrowsers()
    }

    var serverURL: String {
        settingsStore.serverURL
    }

    var hasAppToken: Bool {
        (try? appTokenStore.loadToken())?.isEmpty == false
    }

    var appTokenPrefix: String? {
        guard let token = try? appTokenStore.loadToken(), !token.isEmpty else {
            return nil
        }

        return String(token.prefix(16))
    }

    @discardableResult
    func saveAppTokenIfPresent(_ rawToken: String) throws -> Bool {
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !token.isEmpty else {
            writeAuthState = hasAppToken ? .paired : .unpaired
            notifyChange()
            return false
        }

        guard token.hasPrefix("lwapp_") else {
            throw LinkwiseError.invalidAppToken
        }

        try appTokenStore.saveToken(token)
        writeAuthState = .paired
        notifyChange()
        return true
    }

    func deleteAppToken() throws {
        try appTokenStore.deleteToken()
        writeAuthState = .unpaired
        notifyChange()
    }

    func createPublicClient() throws -> any LinkwiseAPIClientProtocol {
        try apiClientFactory(settingsStore.serverURL, nil)
    }

    func createAuthorizedClient() throws -> any LinkwiseAPIClientProtocol {
        guard let token = try appTokenStore.loadToken(), !token.isEmpty else {
            writeAuthState = .unpaired
            notifyChange()
            throw LinkwiseError.appSessionRequired
        }

        writeAuthState = .paired
        return try apiClientFactory(settingsStore.serverURL, token)
    }

    func handleWriteFailure(_ error: Error) {
        guard let linkwiseError = error as? LinkwiseError else { return }

        if linkwiseError == .appSessionRequired, writeAuthState != .unpaired {
            writeAuthState = .needsRepairing
            notifyChange()
        }
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
        readConnectionState = settingsStore.serverURL.isEmpty ? .unconfigured : .refreshing
        notifyChange()

        defer {
            isRefreshing = false
            notifyChange()
        }

        do {
            let client = try createPublicClient()
            let fetched = try await client.fetchBookmarks()
            bookmarks = fetched
            lastSyncAt = Date()
            lastError = nil
            readConnectionState = .available
            try cache.save(BookmarkCache(serverURL: settingsStore.serverURL, lastSyncAt: lastSyncAt, bookmarks: fetched))

            if showSuccess {
                alertPresenter("书签已刷新", "已从拾链同步 \(fetched.count) 个书签。")
            }
        } catch {
            lastError = error.localizedDescription
            readConnectionState = .failed(error.localizedDescription)
        }
    }

    func testConnection() async -> Bool {
        do {
            let client = try createPublicClient()
            _ = try await client.health()
            readConnectionState = .available
            alertPresenter("连接成功", "拾链服务可用。")
            return true
        } catch {
            readConnectionState = .failed(error.localizedDescription)
            alertPresenter("操作失败", error.localizedDescription)
            return false
        }
    }

    func createBookmark(title: String, url: String, folder: String) async -> Bool {
        do {
            let client = try createAuthorizedClient()
            _ = try await client.createBookmark(CreateBookmarkRequest(title: title, url: url, folder: folder))
            await refreshBookmarks(showSuccess: false)
            alertPresenter("保存成功", "当前页面已保存到拾链。")
            return true
        } catch {
            handleWriteFailure(error)
            alertPresenter("操作失败", error.localizedDescription)
            return false
        }
    }

    func recordOpen(bookmark: Bookmark) {
        Task {
            do {
                let client = try createPublicClient()
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
