import Foundation

public protocol KeyValueSettings: Sendable {
    func string(forKey defaultName: String) -> String?
    func bool(forKey defaultName: String) -> Bool
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: @retroactive @unchecked Sendable, KeyValueSettings {}

public final class SettingsStore: @unchecked Sendable {
    public static let serverURLKey = "serverURL"
    public static let refreshOnLaunchKey = "refreshOnLaunch"
    public static let defaultBrowserBundleIDKey = "defaultBrowserBundleID"

    public let defaults: KeyValueSettings

    public init(defaults: KeyValueSettings = UserDefaults.standard) {
        self.defaults = defaults
    }

    public var serverURL: String {
        get {
            defaults.string(forKey: Self.serverURLKey)?.normalizedServerURLString ?? ""
        }
        set {
            defaults.set(newValue.normalizedServerURLString, forKey: Self.serverURLKey)
        }
    }

    public var refreshOnLaunch: Bool {
        get {
            defaults.string(forKey: Self.refreshOnLaunchKey) == nil ? true : defaults.bool(forKey: Self.refreshOnLaunchKey)
        }
        set {
            defaults.set(newValue, forKey: Self.refreshOnLaunchKey)
        }
    }

    public var defaultBrowserBundleID: String? {
        get {
            let value = defaults.string(forKey: Self.defaultBrowserBundleIDKey)
            return value?.isEmpty == true ? nil : value
        }
        set {
            defaults.set(newValue, forKey: Self.defaultBrowserBundleIDKey)
        }
    }
}
