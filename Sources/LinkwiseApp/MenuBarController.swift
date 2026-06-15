import AppKit
import LinkwiseCore

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let model: AppModel
    private let onOpenSettings: () -> Void
    private let onSaveCurrentPage: () -> Void
    private let menuMinimumWidth: CGFloat = 220
    private lazy var folderImage: NSImage? = {
        let image = NSImage(systemSymbolName: "folder", accessibilityDescription: "目录")
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
        return image
    }()
    private lazy var bookmarkImage: NSImage? = {
        let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "网页")
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
        let menu = makeMenu()
        menu.autoenablesItems = false

        let titleItem = actionItem("拾链 Linkwise", selector: #selector(openWebManager))
        titleItem.image = connectionStatusImage()
        menu.addItem(titleItem)

        menu.addItem(lastSyncMenuItem())

        if model.lastError != nil {
            let errorItem = NSMenuItem(title: "无法连接 Linkwise 服务", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }

        menu.addItem(.separator())
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
            let uncategorized = truncatedMenuItem(title: "未分类", image: folderImage)
            let submenu = makeMenu()
            tree.bookmarks.forEach { submenu.addItem(bookmarkMenuItem($0)) }
            uncategorized.submenu = submenu
            menu.addItem(uncategorized)
        }

        for folder in tree.folders {
            menu.addItem(folderMenuItem(folder))
        }
    }

    private func folderMenuItem(_ folder: FolderNode) -> NSMenuItem {
        let item = truncatedMenuItem(title: folder.name, image: folderImage)
        let submenu = makeMenu()

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
        let item = actionItem(truncatedTitle(viewModel.title, image: bookmarkImage), selector: #selector(openBookmark(_:)))
        item.image = bookmarkImage
        item.representedObject = bookmark
        let submenu = makeMenu()

        if item.title != viewModel.title {
            submenu.addItem(fullTitleHeaderItem(viewModel.title))
            submenu.addItem(.separator())
        }

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

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = menuMinimumWidth
        return menu
    }

    private func actionItem(_ title: String, selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        item.isEnabled = true
        return item
    }

    private func truncatedMenuItem(title: String, image: NSImage? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: truncatedTitle(title, image: image), action: nil, keyEquivalent: "")
        item.image = image
        return item
    }

    private func truncatedTitle(_ title: String, image: NSImage?) -> String {
        let labelLeading: CGFloat = image == nil ? 18 : 37
        let imageColumnSafety: CGFloat = image == nil ? 0 : 34
        let labelWidth = menuMinimumWidth - labelLeading - 34 - imageColumnSafety
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.menuFont(ofSize: 0)]

        guard (title as NSString).size(withAttributes: attributes).width > labelWidth else {
            return title
        }

        let ellipsis = "..."
        var clipped = ""

        for character in title {
            let candidate = clipped + String(character) + ellipsis
            guard (candidate as NSString).size(withAttributes: attributes).width <= labelWidth else {
                break
            }
            clipped.append(character)
        }

        return clipped.isEmpty ? ellipsis : clipped + ellipsis
    }

    private func connectionStatusImage() -> NSImage? {
        let color: NSColor = model.lastError == nil ? .systemGreen : .systemRed
        let configuration = NSImage.SymbolConfiguration(paletteColors: [color])
        let image = NSImage(
            systemSymbolName: "link",
            accessibilityDescription: model.lastError == nil ? "连接正常" : "连接失败"
        )?.withSymbolConfiguration(configuration)
        image?.isTemplate = false
        image?.size = NSSize(width: 16, height: 16)
        return image
    }

    private func lastSyncMenuItem() -> NSMenuItem {
        let title: String

        if model.isRefreshing {
            title = "正在同步书签..."
        } else if let lastSyncAt = model.lastSyncAt {
            let formatter = DateFormatter()
            formatter.dateFormat = Calendar.current.isDate(lastSyncAt, equalTo: Date(), toGranularity: .year)
                ? "M/d HH:mm"
                : "yyyy/M/d HH:mm"
            title = "上次同步 \(formatter.string(from: lastSyncAt))"
        } else {
            title = "尚未同步"
        }

        let item = actionItem(title, selector: #selector(refreshBookmarks))
        item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新书签")
        item.isEnabled = !model.isRefreshing
        return item
    }

    private func bookmarkActionItem(_ title: String, bookmark: Bookmark, selector: Selector) -> NSMenuItem {
        let item = actionItem(title, selector: selector)
        item.representedObject = bookmark
        return item
    }

    private func fullTitleHeaderItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.view = MenuHeaderTitleView(title: title, width: menuMinimumWidth)
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

private final class MenuHeaderTitleView: NSView {
    private let label = NSTextField(wrappingLabelWithString: "")
    private let contentInset = NSEdgeInsets(top: 5, left: 16, bottom: 2, right: 16)

    init(title: String, width: CGFloat) {
        let labelWidth = width - contentInset.left - contentInset.right
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.menuFont(ofSize: 0)]
        let boundingRect = (title as NSString).boundingRect(
            with: NSSize(width: labelWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        let labelHeight = ceil(boundingRect.height)
        let height = labelHeight + contentInset.top + contentInset.bottom

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))

        label.font = .menuFont(ofSize: 0)
        label.textColor = .disabledControlTextColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.stringValue = title
        label.frame = NSRect(
            x: contentInset.left,
            y: contentInset.bottom,
            width: labelWidth,
            height: labelHeight
        )
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
