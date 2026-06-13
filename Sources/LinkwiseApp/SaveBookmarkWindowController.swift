import AppKit

@MainActor
final class SaveBookmarkWindowController: NSWindowController {
    private let model: AppModel
    private let titleField = NSTextField()
    private let urlField = NSTextField()
    private let folderField = NSTextField()

    init(model: AppModel, page: CurrentPage) {
        self.model = model

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "保存当前页面"
        window.center()
        super.init(window: window)

        buildUI()
        titleField.stringValue = page.title
        urlField.stringValue = page.url
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

        stack.addArrangedSubview(labeledRow(title: "标题", view: titleField))
        stack.addArrangedSubview(labeledRow(title: "URL", view: urlField))
        stack.addArrangedSubview(labeledRow(title: "目录", view: folderField))

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(cancelButton)
        row.addArrangedSubview(saveButton)
        stack.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func labeledRow(title: String, view: NSTextField) -> NSStackView {
        let row = NSStackView()
        row.orientation = .vertical
        row.spacing = 6
        row.alignment = .leading

        let label = NSTextField(labelWithString: title)
        row.addArrangedSubview(label)
        row.addArrangedSubview(view)
        view.widthAnchor.constraint(equalToConstant: 476).isActive = true

        return row
    }

    @objc private func cancel() {
        close()
    }

    @objc private func save() {
        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = folderField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            let success = await model.createBookmark(title: title, url: url, folder: folder)
            if success {
                close()
            }
        }
    }
}

