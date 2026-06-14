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
    private var lastActiveApplication: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateLastActiveApplication(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationDidChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

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
                let page = try CurrentPageReader().readCurrentPage(from: lastActiveApplication)
                NSApp.activate(ignoringOtherApps: true)
                saveWindowController = SaveBookmarkWindowController(model: appModel, page: page)
                saveWindowController?.showWindow(nil)
                saveWindowController?.window?.makeKeyAndOrderFront(nil)
            } catch {
                AlertPresenter.show(error)
            }
        }
    }

    @objc private func activeApplicationDidChange(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        updateLastActiveApplication(app)
    }

    private func updateLastActiveApplication(_ app: NSRunningApplication?) {
        guard let app,
              app.processIdentifier != NSRunningApplication.current.processIdentifier,
              app.activationPolicy == .regular
        else {
            return
        }

        lastActiveApplication = app
    }
}
