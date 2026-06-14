import AppKit
import LinkwiseCore

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let model: AppModel
    private let onOpenSettings: () -> Void
    private let onSaveCurrentPage: () -> Void
    private lazy var folderImage: NSImage? = {
        let image = NSImage(systemSymbolName: "folder", accessibilityDescription: "目录")
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
        return image
    }()

    init(model: AppModel, onOpenSettings: @escaping () -> Void, onSaveCurrentPage: @escaping () -> Void) {
        self.model = model
        self.onOpenSettings = onOpenSettings
        self.onSaveCurrentPage = onSaveCurrentPage
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Linkwise")
            button.imagePosition = .imageLeading
            button.toolTip = "拾链 Linkwise"
        }

        model.onChange = { [weak self] in
            self?.rebuildMenu()
        }
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let titleItem = actionItem("拾链 Linkwise", selector: #selector(openWebManager), key: "w")
        titleItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: "打开 Web 管理界面")
        menu.addItem(titleItem)

        if let lastSyncAt = model.lastSyncAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let syncItem = NSMenuItem(title: "上次同步 \(formatter.string(from: lastSyncAt))", action: nil, keyEquivalent: "")
            syncItem.isEnabled = false
            menu.addItem(syncItem)
        }

        if let lastError = model.lastError {
            let errorItem = NSMenuItem(title: "连接异常：\(lastError)", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("刷新书签", selector: #selector(refreshBookmarks), key: "r"))
        menu.addItem(actionItem("保存当前页面", selector: #selector(saveCurrentPage), key: "s"))
        menu.addItem(.separator())

        addBookmarkItems(to: menu)

        menu.addItem(.separator())
        menu.addItem(actionItem("设置...", selector: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(actionItem("退出", selector: #selector(quit), key: "q"))

        statusItem.menu = menu
    }

    private func addBookmarkItems(to menu: NSMenu) {
        guard !model.bookmarks.isEmpty else {
            let emptyItem = NSMenuItem(title: "暂无书签", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        let tree = BookmarkTreeBuilder.build(from: model.bookmarks)

        if !tree.bookmarks.isEmpty {
            let uncategorized = NSMenuItem(title: "未分类", action: nil, keyEquivalent: "")
            uncategorized.image = folderImage
            let submenu = NSMenu()
            tree.bookmarks.forEach { submenu.addItem(bookmarkMenuItem($0)) }
            uncategorized.submenu = submenu
            menu.addItem(uncategorized)
        }

        for folder in tree.folders {
            menu.addItem(folderMenuItem(folder))
        }
    }

    private func folderMenuItem(_ folder: FolderNode) -> NSMenuItem {
        let item = NSMenuItem(title: folder.name, action: nil, keyEquivalent: "")
        item.image = folderImage
        let submenu = NSMenu()

        for child in folder.folders {
            submenu.addItem(folderMenuItem(child))
        }

        if !folder.folders.isEmpty && !folder.bookmarks.isEmpty {
            submenu.addItem(.separator())
        }

        for bookmark in folder.bookmarks {
            submenu.addItem(bookmarkMenuItem(bookmark))
        }

        item.submenu = submenu
        return item
    }

    private func bookmarkMenuItem(_ bookmark: Bookmark) -> NSMenuItem {
        let viewModel = BookmarkViewModel(bookmark)
        let item = NSMenuItem(title: viewModel.title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        submenu.addItem(bookmarkActionItem("打开", bookmark: bookmark, selector: #selector(openBookmark(_:))))

        for browser in model.browsers {
            let browserItem = bookmarkActionItem("用 \(browser.name) 打开", bookmark: bookmark, selector: #selector(openBookmarkWithBrowser(_:)))
            browserItem.representedObject = BookmarkBrowserAction(bookmark: bookmark, browser: browser)
            submenu.addItem(browserItem)
        }

        submenu.addItem(.separator())
        submenu.addItem(bookmarkActionItem("复制 URL", bookmark: bookmark, selector: #selector(copyBookmarkURL(_:))))
        item.submenu = submenu

        return item
    }

    private func actionItem(_ title: String, selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        item.isEnabled = true
        return item
    }

    private func bookmarkActionItem(_ title: String, bookmark: Bookmark, selector: Selector) -> NSMenuItem {
        let item = actionItem(title, selector: selector)
        item.representedObject = bookmark
        return item
    }

    @objc private func refreshBookmarks() {
        Task { await model.refreshBookmarks() }
    }

    @objc private func saveCurrentPage() {
        onSaveCurrentPage()
    }

    @objc private func openWebManager() {
        guard let url = URL(string: model.serverURL) else {
            AlertPresenter.showMessage("服务地址无效", informativeText: model.serverURL)
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else { return }
        open(bookmark: bookmark, browser: defaultBrowser())
    }

    @objc private func openBookmarkWithBrowser(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? BookmarkBrowserAction else { return }
        open(bookmark: action.bookmark, browser: action.browser)
    }

    @objc private func copyBookmarkURL(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bookmark.url, forType: .string)
    }

    private func open(bookmark: Bookmark, browser: InstalledBrowser?) {
        do {
            try BrowserLauncher.open(BookmarkViewModel(bookmark), using: browser)
            model.recordOpen(bookmark: bookmark)
        } catch {
            AlertPresenter.show(error)
        }
    }

    private func defaultBrowser() -> InstalledBrowser? {
        guard let bundleID = model.settingsStore.defaultBrowserBundleID else {
            return nil
        }

        return model.browsers.first { $0.bundleIdentifier == bundleID }
    }
}

private final class BookmarkBrowserAction {
    let bookmark: Bookmark
    let browser: InstalledBrowser

    init(bookmark: Bookmark, browser: InstalledBrowser) {
        self.bookmark = bookmark
        self.browser = browser
    }
}
