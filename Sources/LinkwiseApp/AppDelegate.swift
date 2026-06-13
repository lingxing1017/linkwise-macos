import AppKit
import LinkwiseCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private let cache = LocalCache()
    private var appModel: AppModel?
    private var menuController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var saveWindowController: SaveBookmarkWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = AppModel(settingsStore: settingsStore, cache: cache)
        appModel = model

        let controller = MenuBarController(
            model: model,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onSaveCurrentPage: { [weak self] in self?.saveCurrentPage() }
        )
        menuController = controller
        controller.rebuildMenu()

        model.loadCachedBookmarks()

        if settingsStore.refreshOnLaunch {
            Task { await model.refreshBookmarks(showSuccess: false) }
        }
    }

    private func openSettings() {
        guard let appModel else { return }

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(model: appModel)
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func saveCurrentPage() {
        guard let appModel else { return }

        Task {
            do {
                let page = try CurrentPageReader().readCurrentPage()
                NSApp.activate(ignoringOtherApps: true)
                saveWindowController = SaveBookmarkWindowController(model: appModel, page: page)
                saveWindowController?.showWindow(nil)
                saveWindowController?.window?.makeKeyAndOrderFront(nil)
            } catch {
                AlertPresenter.show(error)
            }
        }
    }
}

