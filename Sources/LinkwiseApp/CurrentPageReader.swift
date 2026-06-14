import AppKit
import Foundation
import LinkwiseCore

struct CurrentPage: Equatable, Sendable {
    let title: String
    let url: String
    let folder: String

    init(title: String, url: String, folder: String = "") {
        self.title = title
        self.url = url
        self.folder = folder
    }
}

struct CurrentPageReader {
    func readCurrentPage(from preferredApplication: NSRunningApplication? = nil) throws -> CurrentPage {
        guard let app = preferredApplication ?? NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier
        else {
            throw LinkwiseError.unsupportedBrowser
        }

        switch bundleID {
        case "com.apple.Safari":
            return try readWithAppleScript(bundleIdentifier: bundleID, urlProperty: "URL of current tab of front window", titleProperty: "name of current tab of front window")
        case "com.google.Chrome",
             "com.microsoft.edgemac",
             "com.brave.Browser",
             "net.imput.helium":
            return try readWithAppleScript(bundleIdentifier: bundleID, urlProperty: "URL of active tab of front window", titleProperty: "title of active tab of front window")
        default:
            return try readWithSupportedScriptShape(bundleIdentifier: bundleID)
        }
    }

    private func readWithSupportedScriptShape(bundleIdentifier: String) throws -> CurrentPage {
        let scriptShapes = [
            ("URL of active tab of front window", "title of active tab of front window"),
            ("URL of current tab of front window", "name of current tab of front window")
        ]
        var lastError: Error?

        for shape in scriptShapes {
            do {
                return try readWithAppleScript(
                    bundleIdentifier: bundleIdentifier,
                    urlProperty: shape.0,
                    titleProperty: shape.1
                )
            } catch let error as LinkwiseError {
                if error.isPermissionDenied {
                    throw error
                }

                lastError = error
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }

        throw LinkwiseError.unsupportedBrowser
    }

    private func readWithAppleScript(bundleIdentifier: String, urlProperty: String, titleProperty: String) throws -> CurrentPage {
        let script = """
        tell application id "\(bundleIdentifier)"
            set pageUrl to \(urlProperty)
            set pageTitle to \(titleProperty)
            return pageTitle & linefeed & pageUrl
        end tell
        """

        var errorInfo: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw LinkwiseError.noCurrentPage("无法创建读取当前页面的脚本。")
        }

        let output = appleScript.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Linkwise 需要获得自动化权限，才能读取当前浏览器标签页的标题和 URL。"

            if message.localizedCaseInsensitiveContains("not authorized") ||
                message.localizedCaseInsensitiveContains("not allowed") ||
                message.localizedCaseInsensitiveContains("permission") {
                throw LinkwiseError.permissionDenied("Linkwise 需要获得自动化权限，才能读取当前浏览器标签页的标题和 URL。请在系统设置中允许 Linkwise 控制对应浏览器。")
            }

            throw LinkwiseError.noCurrentPage(message)
        }

        let parts = output.stringValue?.components(separatedBy: "\n") ?? []
        guard parts.count >= 2 else {
            throw LinkwiseError.noCurrentPage("当前浏览器没有可读取的标签页。")
        }

        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let url = parts.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard isSavableURL(url) else {
            throw LinkwiseError.invalidBookmarkURL(url)
        }

        return CurrentPage(title: title.isEmpty ? url : title, url: url)
    }

    private func isSavableURL(_ value: String) -> Bool {
        CurrentPage.isSavableURL(value)
    }
}

extension CurrentPage {
    static func clipboardFallback(from pasteboard: NSPasteboard = .general) -> CurrentPage? {
        guard let value = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            isSavableURL(value)
        else {
            return nil
        }

        return CurrentPage(title: "", url: value)
    }

    static func isSavableURL(_ value: String) -> Bool {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            return false
        }

        return true
    }
}

private extension LinkwiseError {
    var isPermissionDenied: Bool {
        if case .permissionDenied = self {
            return true
        }

        return false
    }
}
