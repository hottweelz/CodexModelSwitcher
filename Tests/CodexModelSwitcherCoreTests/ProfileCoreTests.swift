import Foundation
import CodexModelSwitcherCore

@main
struct ProfileCoreTestRunner {
    static func main() throws {
        try defaultProfilesUseExistingCodexHomeNames()
        try profilePathsResolveInsideSelectedProfile()
        print("ProfileCoreTestRunner: all tests passed")
    }

    static func defaultProfilesUseExistingCodexHomeNames() throws {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let profiles = CodexProfile.defaultProfiles(homeDirectory: home)

        try expectEqual(profiles.map(\.name), ["Primary", "Secondary", "Free 1", "Free 2", "Free 3"])
        try expectEqual(profiles.map(\.path), [
            "/Users/example/.codex",
            "/Users/example/.codex-secondary",
            "/Users/example/.codex-free-1",
            "/Users/example/.codex-free-2",
            "/Users/example/.codex-free-3"
        ])
        try expectEqual(profiles.first?.id, "primary")
        try expectTrue(profiles.allSatisfy(\.isPinned), "default profiles should be pinned")
    }

    static func profilePathsResolveInsideSelectedProfile() throws {
        let profile = CodexProfile(
            id: "free-1",
            name: "Free 1",
            path: "/Users/example/.codex-free-1",
            isPinned: true
        )

        let paths = CodexProfilePaths(profile: profile)

        try expectEqual(paths.home.path, "/Users/example/.codex-free-1")
        try expectEqual(paths.config.path, "/Users/example/.codex-free-1/config.toml")
        try expectEqual(paths.auth.path, "/Users/example/.codex-free-1/auth.json")
        try expectEqual(paths.envFile.path, "/Users/example/.codex-free-1/model-switcher.env")
    }

    static func expectEqual<T: Equatable>(_ actual: T, _ expected: T) throws {
        if actual != expected {
            throw TestFailure("Expected \(expected), got \(actual)")
        }
    }

    static func expectTrue(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw TestFailure(message)
        }
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
