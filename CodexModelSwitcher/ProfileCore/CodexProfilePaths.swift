import Foundation

public struct CodexProfilePaths: Equatable {
    public var home: URL
    public var config: URL
    public var auth: URL
    public var modelSwitcherData: URL
    public var envFile: URL

    public init(profile: CodexProfile) {
        self.init(home: URL(fileURLWithPath: profile.path, isDirectory: true))
    }

    public init(home: URL) {
        self.home = home
        config = home.appendingPathComponent("config.toml")
        auth = home.appendingPathComponent("auth.json")
        modelSwitcherData = home.appendingPathComponent("model-switcher.json")
        envFile = home.appendingPathComponent("model-switcher.env")
    }
}

public enum CodexModelSwitcherAppPaths {
    public static var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexModelSwitcher", isDirectory: true)
    }

    public static var appData: URL {
        supportDirectory.appendingPathComponent("app-data.json")
    }

    public static var profilesData: URL {
        supportDirectory.appendingPathComponent("profiles.json")
    }
}
