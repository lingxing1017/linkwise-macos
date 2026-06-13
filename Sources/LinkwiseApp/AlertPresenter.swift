import AppKit

@MainActor
enum AlertPresenter {
    static func show(_ error: Error) {
        showMessage("操作失败", informativeText: error.localizedDescription)
    }

    static func showMessage(_ messageText: String, informativeText: String = "") {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.alertStyle = messageText.contains("失败") ? .warning : .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

