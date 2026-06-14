import XCTest
@testable import LinkwiseApp

final class BrowserDetectorTests: XCTestCase {
    func testScansAppsThatSupportWebURLSchemes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let helium = apps.appendingPathComponent("Helium.app", isDirectory: true)
        let zen = apps.appendingPathComponent("Zen.app", isDirectory: true)
        let infuse = apps.appendingPathComponent("Infuse.app", isDirectory: true)
        let parallels = apps.appendingPathComponent("Parallels Desktop.app", isDirectory: true)
        let velja = apps.appendingPathComponent("Velja.app", isDirectory: true)
        let notes = apps.appendingPathComponent("Notes.app", isDirectory: true)

        try writeInfoPlist(
            appURL: helium,
            bundleIdentifier: "net.imput.helium",
            name: "Helium",
            schemes: ["http", "https", "file"],
            contentTypes: ["public.html", "public.xhtml"]
        )
        try writeInfoPlist(
            appURL: zen,
            bundleIdentifier: "app.zen-browser.zen",
            name: "Zen",
            schemes: ["http", "https"],
            contentTypes: ["public.html"]
        )
        try writeInfoPlist(
            appURL: infuse,
            bundleIdentifier: "com.firecore.infuse",
            name: "Infuse",
            schemes: ["http", "infuse"],
            contentTypes: ["public.movie"]
        )
        try writeInfoPlist(
            appURL: parallels,
            bundleIdentifier: "com.parallels.desktop.console",
            name: "Parallels Desktop",
            schemes: ["http", "https"],
            extensions: ["pvm", "iso"]
        )
        try writeInfoPlist(
            appURL: velja,
            bundleIdentifier: "com.sindresorhus.Velja",
            name: "Velja",
            schemes: ["http", "https", "file"],
            contentTypes: ["public.html", "public.xhtml"]
        )
        try writeInfoPlist(
            appURL: notes,
            bundleIdentifier: "com.example.Notes",
            name: "Notes",
            schemes: ["notes"]
        )

        let detector = BrowserDetector(applicationDirectories: [apps])
        let browsers = detector.scannedBrowserApps()

        XCTAssertEqual(browsers.map(\.name), ["Helium", "Velja", "Zen"])
        XCTAssertEqual(
            browsers.map(\.bundleIdentifier),
            ["net.imput.helium", "com.sindresorhus.Velja", "app.zen-browser.zen"]
        )
    }

    func testIncludesUserAddedWebBrowsers() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let zen = apps.appendingPathComponent("Zen.app", isDirectory: true)

        try writeInfoPlist(
            appURL: zen,
            bundleIdentifier: "app.zen-browser.zen",
            name: "Zen",
            schemes: ["http", "https"],
            contentTypes: ["public.html"]
        )

        let record = CustomBrowserRecord(
            name: "Zen",
            bundleIdentifier: "app.zen-browser.zen",
            path: zen.path
        )
        let detector = BrowserDetector(
            applicationDirectories: [apps],
            customBrowsers: [record]
        )

        XCTAssertEqual(detector.scannedBrowserApps().map(\.name), ["Zen"])
        XCTAssertTrue(detector.installedBrowsers().contains {
            $0.bundleIdentifier == "app.zen-browser.zen"
        })
    }

    private func writeInfoPlist(
        appURL: URL,
        bundleIdentifier: String,
        name: String,
        schemes: [String],
        extensions: [String] = [],
        contentTypes: [String] = []
    ) throws {
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contents,
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
            "CFBundleURLTypes": [
                [
                    "CFBundleURLName": "URL",
                    "CFBundleURLSchemes": schemes
                ]
            ],
            "CFBundleDocumentTypes": [
                [
                    "CFBundleTypeExtensions": extensions,
                    "LSItemContentTypes": contentTypes
                ]
            ]
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: contents.appendingPathComponent("Info.plist"))
    }
}
