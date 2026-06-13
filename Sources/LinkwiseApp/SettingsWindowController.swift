import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let model: AppModel
    private let serverField = NSTextField()
    private let refreshCheckbox = NSButton(checkboxWithTitle: "启动时自动刷新书签", target: nil, action: nil)
    private let browserPopup = NSPopUpButton()

    init(model: AppModel) {
        self.model = model

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Linkwise 设置"
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

        stack.addArrangedSubview(labeledRow(title: "Linkwise 服务地址", view: serverField))

        refreshCheckbox.target = self
        refreshCheckbox.action = #selector(saveValues)
        stack.addArrangedSubview(refreshCheckbox)

        stack.addArrangedSubview(labeledRow(title: "默认打开浏览器", view: browserPopup))

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        buttonRow.alignment = .centerY

        let testButton = NSButton(title: "连接测试", target: self, action: #selector(testConnection))
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveAndClose))
        let rescanButton = NSButton(title: "重新扫描浏览器", target: self, action: #selector(rescanBrowsers))

        buttonRow.addArrangedSubview(testButton)
        buttonRow.addArrangedSubview(rescanButton)
        buttonRow.addArrangedSubview(NSView())
        buttonRow.addArrangedSubview(saveButton)
        stack.addArrangedSubview(buttonRow)

        buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func labeledRow(title: String, view: NSView) -> NSStackView {
        let row = NSStackView()
        row.orientation = .vertical
        row.spacing = 6
        row.alignment = .leading

        let label = NSTextField(labelWithString: title)
        row.addArrangedSubview(label)
        row.addArrangedSubview(view)
        view.widthAnchor.constraint(equalToConstant: 416).isActive = true

        return row
    }

    private func loadValues() {
        serverField.stringValue = model.settingsStore.serverURL
        refreshCheckbox.state = model.settingsStore.refreshOnLaunch ? .on : .off
        reloadBrowserPopup()
    }

    private func reloadBrowserPopup() {
        browserPopup.removeAllItems()
        browserPopup.addItem(withTitle: "系统默认浏览器")
        browserPopup.lastItem?.representedObject = ""

        for browser in model.browsers {
            browserPopup.addItem(withTitle: browser.name)
            browserPopup.lastItem?.representedObject = browser.bundleIdentifier
        }

        if let current = model.settingsStore.defaultBrowserBundleID,
           let index = model.browsers.firstIndex(where: { $0.bundleIdentifier == current }) {
            browserPopup.selectItem(at: index + 1)
        } else {
            browserPopup.selectItem(at: 0)
        }
    }

    @objc private func saveValues() {
        model.settingsStore.serverURL = serverField.stringValue
        model.settingsStore.refreshOnLaunch = refreshCheckbox.state == .on
        model.settingsStore.defaultBrowserBundleID = browserPopup.selectedItem?.representedObject as? String
        model.notifyChange()
    }

    @objc private func testConnection() {
        saveValues()
        Task { _ = await model.testConnection() }
    }

    @objc private func rescanBrowsers() {
        model.rescanBrowsers()
        reloadBrowserPopup()
    }

    @objc private func saveAndClose() {
        saveValues()
        close()
    }
}

