import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let model: AppModel
    private let addBrowserMenuValue = "__add_browser__"
    private let contentWidth: CGFloat = 356
    private let serverField = NSTextField()
    private let tokenField = NSTextField()
    private let tokenStatusLabel = NSTextField(labelWithString: "")
    private let tokenTitleRow = NSStackView()
    private let tokenActionButton = NSButton(title: "保存", target: nil, action: nil)
    private let refreshCheckbox = NSButton(checkboxWithTitle: "启动时自动刷新书签", target: nil, action: nil)
    private let browserPopup = NSPopUpButton()

    init(model: AppModel) {
        self.model = model

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 270),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "拾链 设置"
        window.center()
        super.init(window: window)
        buildUI()
        loadValues()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22)
        ])

        serverField.delegate = self
        serverField.target = self
        serverField.action = #selector(saveValues)
        serverField.placeholderString = "https://your-linkwise-server.example"

        let testButton = NSButton(title: "连接测试", target: self, action: #selector(testConnection))
        stack.addArrangedSubview(
            labeledRow(
                title: "拾链 服务地址",
                view: horizontalRow([serverField, testButton])
            )
        )

        tokenField.delegate = self
        tokenField.target = self
        tokenField.action = #selector(saveAppToken)
        tokenField.placeholderString = "lwapp_..."
        configureSingleLine(tokenField)

        tokenActionButton.target = self
        tokenActionButton.action = #selector(tokenAction)

        let tokenStack = NSStackView()
        tokenStack.orientation = .vertical
        tokenStack.spacing = 6
        tokenStack.alignment = .leading
        tokenStack.addArrangedSubview(horizontalRow([tokenField, tokenActionButton]))
        stack.addArrangedSubview(tokenLabeledRow(view: tokenStack))

        refreshCheckbox.target = self
        refreshCheckbox.action = #selector(saveValues)
        stack.addArrangedSubview(refreshCheckbox)

        browserPopup.target = self
        browserPopup.action = #selector(saveValues)

        let rescanButton = NSButton(title: "重新扫描", target: self, action: #selector(rescanBrowsers))
        stack.addArrangedSubview(
            labeledRow(
                title: "默认打开浏览器",
                view: horizontalRow([browserPopup, rescanButton])
            )
        )
    }

    private func labeledRow(title: String, view: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .vertical
        row.spacing = 6
        row.alignment = .leading

        let label = NSTextField(labelWithString: title)
        row.addArrangedSubview(label)
        row.addArrangedSubview(view)
        view.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        return row
    }

    private func tokenLabeledRow(view: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .vertical
        row.spacing = 6
        row.alignment = .leading

        tokenTitleRow.orientation = .horizontal
        tokenTitleRow.spacing = 8
        tokenTitleRow.alignment = .firstBaseline

        let label = NSTextField(labelWithString: "App Token")
        tokenStatusLabel.textColor = .secondaryLabelColor
        tokenTitleRow.addArrangedSubview(label)
        tokenTitleRow.addArrangedSubview(tokenStatusLabel)

        row.addArrangedSubview(tokenTitleRow)
        row.addArrangedSubview(view)
        view.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        return row
    }

    private func configureSingleLine(_ field: NSTextField) {
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingMiddle

        if let cell = field.cell as? NSTextFieldCell {
            cell.usesSingleLineMode = true
            cell.wraps = false
            cell.isScrollable = true
            cell.lineBreakMode = .byTruncatingMiddle
        }
    }

    private func horizontalRow(_ views: [NSView]) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY

        for view in views {
            row.addArrangedSubview(view)
        }

        let trailingWidth = views.dropFirst().reduce(CGFloat.zero) { width, view in
            width + view.intrinsicContentSize.width
        }
        let spacing = CGFloat(max(views.count - 1, 0)) * row.spacing
        let firstViewWidth = max(180, contentWidth - trailingWidth - spacing)
        views.first?.widthAnchor.constraint(equalToConstant: firstViewWidth).isActive = true
        row.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        return row
    }

    private func loadValues() {
        serverField.stringValue = model.settingsStore.serverURL
        refreshTokenControls()
        refreshCheckbox.state = model.settingsStore.refreshOnLaunch ? .on : .off
        reloadBrowserPopup()
    }

    private func refreshTokenControls() {
        if let token = model.appTokenDisplayValue {
            tokenField.stringValue = token
            tokenStatusLabel.stringValue = "已配对"
            tokenActionButton.title = "移除"
            tokenActionButton.isEnabled = true
        } else {
            tokenStatusLabel.stringValue = "未配对"
            tokenActionButton.title = "保存"
            tokenActionButton.isEnabled = !tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func reloadBrowserPopup() {
        browserPopup.removeAllItems()
        browserPopup.addItem(withTitle: "系统默认浏览器")
        browserPopup.lastItem?.representedObject = ""

        for browser in model.browsers {
            browserPopup.addItem(withTitle: browser.name)
            browserPopup.lastItem?.representedObject = browser.bundleIdentifier
        }

        browserPopup.menu?.addItem(.separator())
        browserPopup.addItem(withTitle: "添加浏览器")
        browserPopup.lastItem?.representedObject = addBrowserMenuValue

        if let current = model.settingsStore.defaultBrowserBundleID,
           let index = model.browsers.firstIndex(where: { $0.bundleIdentifier == current }) {
            browserPopup.selectItem(at: index + 1)
        } else {
            browserPopup.selectItem(at: 0)
        }
    }

    @objc private func saveValues() {
        let selectedBrowser = browserPopup.selectedItem?.representedObject as? String

        if selectedBrowser == addBrowserMenuValue {
            reloadBrowserPopup()
            addBrowser()
            return
        }

        model.settingsStore.serverURL = serverField.stringValue
        model.settingsStore.refreshOnLaunch = refreshCheckbox.state == .on
        model.settingsStore.defaultBrowserBundleID = selectedBrowser
        model.notifyChange()
    }

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSTextField === tokenField {
            refreshTokenControls()
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if obj.object as? NSTextField === tokenField {
            refreshTokenControls()
            return
        }

        saveValues()
    }

    @objc private func testConnection() {
        saveValues()
        Task { _ = await model.testConnection() }
    }

    @objc private func rescanBrowsers() {
        model.rescanBrowsers()
        reloadBrowserPopup()
    }

    @objc private func tokenAction() {
        if model.hasAppToken {
            removeAppToken()
        } else {
            saveAppToken()
        }
    }

    @objc private func saveAppToken() {
        do {
            guard try model.saveAppTokenIfPresent(tokenField.stringValue) else {
                refreshTokenControls()
                return
            }
            refreshTokenControls()
        } catch {
            AlertPresenter.show(error)
            window?.makeFirstResponder(tokenField)
        }
    }

    private func removeAppToken() {
        do {
            try model.deleteAppToken()
            tokenField.stringValue = ""
            refreshTokenControls()
        } catch {
            AlertPresenter.show(error)
        }
    }

    @objc private func addBrowser() {
        let panel = NSOpenPanel()
        panel.title = "选择浏览器"
        panel.prompt = "添加"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK,
              let appURL = panel.url,
              model.addCustomBrowser(appURL: appURL)
        else {
            return
        }

        reloadBrowserPopup()
    }

    var tokenStatusIsInTitleRowForTesting: Bool {
        tokenStatusLabel.superview === tokenTitleRow
    }

    var tokenFieldUsesSingleLineModeForTesting: Bool {
        tokenField.usesSingleLineMode && ((tokenField.cell as? NSTextFieldCell)?.usesSingleLineMode ?? false)
    }

    var tokenFieldWrapsForTesting: Bool {
        (tokenField.cell as? NSTextFieldCell)?.wraps ?? true
    }
}
