import Foundation

public enum ProfileDisplayText {
    public static func selectedProfileFooter(
        for profile: CodexProfile,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        "\(profile.name) \(shortPath(profile.path, homeDirectory: homeDirectory))"
    }

    public static func modelSelectionTarget(for profile: CodexProfile) -> String {
        "Models update \(profile.name) config.toml"
    }

    public static func shortPath(
        _ path: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        path.replacingOccurrences(of: homeDirectory.path, with: "~")
    }
}
