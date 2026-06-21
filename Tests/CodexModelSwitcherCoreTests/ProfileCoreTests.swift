import Foundation
import CodexModelSwitcherCore

@main
struct ProfileCoreTestRunner {
    static func main() throws {
        try defaultProfilesUseExistingCodexHomeNames()
        try profilePathsResolveInsideSelectedProfile()
        try healthScannerReportsAuthConfigAndSelectedModelWithoutReadingSecrets()
        try configSummaryParsesTopLevelModelAndProviderOnly()
        try profileConfigEditorWritesSelectedModelAndProviderAtTopLevel()
        try launcherBuildsCommandAndEnvironmentForProfile()
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

    static func healthScannerReportsAuthConfigAndSelectedModelWithoutReadingSecrets() throws {
        let root = try makeTemporaryDirectory()
        let profileHome = root.appendingPathComponent(".codex-free-2", isDirectory: true)
        try FileManager.default.createDirectory(at: profileHome, withIntermediateDirectories: true)
        try Data("secret-token-json".utf8).write(to: profileHome.appendingPathComponent("auth.json"))
        try Data("""
        model = "gpt-5.5"
        model_provider = "openai"
        """.utf8).write(to: profileHome.appendingPathComponent("config.toml"))

        let profile = CodexProfile(id: "free-2", name: "Free 2", path: profileHome.path, isPinned: true)

        let health = ProfileHealthScanner().health(for: profile)

        try expectTrue(health.exists, "profile should exist")
        try expectTrue(health.hasAuth, "profile should report auth file presence")
        try expectTrue(health.hasConfig, "profile should report config file presence")
        try expectEqual(health.selectedModel, "gpt-5.5")
        try expectEqual(health.selectedProvider, "openai")
        try expectEqual(health.status, .ready)
    }

    static func configSummaryParsesTopLevelModelAndProviderOnly() throws {
        let summary = ProfileConfigSummary.parse("""
        model = "gpt-5.5"
        model_provider = "openrouter"

        [model_providers.openrouter]
        name = "OpenRouter"
        base_url = "https://openrouter.ai/api/v1"
        """)

        try expectEqual(summary.model, "gpt-5.5")
        try expectEqual(summary.modelProvider, "openrouter")
        try expectTrue(summary.providerIDs.contains("openrouter"), "summary should include provider table id")
    }

    static func profileConfigEditorWritesSelectedModelAndProviderAtTopLevel() throws {
        let original = """
        model = "old-model"
        model_provider = "old-provider"

        [model_providers.openrouter]
        name = "OpenRouter"
        base_url = "https://openrouter.ai/api/v1"
        """

        let updated = ProfileConfigEditor().rewrite(
            original,
            selectedModel: "moonshotai/kimi-k2.5",
            selectedProvider: "openrouter"
        )

        try expectTrue(updated.hasPrefix("""
        model = "moonshotai/kimi-k2.5"
        model_provider = "openrouter"
        """), "updated config should start with selected model and provider")
        try expectTrue(updated.contains("[model_providers.openrouter]"), "existing provider table should remain")
        try expectFalse(updated.contains("model = \"old-model\""), "old top-level model should be removed")
        try expectFalse(updated.contains("model_provider = \"old-provider\""), "old top-level provider should be removed")
    }

    static func launcherBuildsCommandAndEnvironmentForProfile() throws {
        let profile = CodexProfile(
            id: "secondary",
            name: "Secondary",
            path: "/Users/example/.codex-secondary",
            isPinned: true
        )

        let launch = CodexLauncher(
            profile: profile,
            workingDirectory: URL(fileURLWithPath: "/Users/example", isDirectory: true)
        )

        try expectEqual(launch.shellCommand(), "CODEX_HOME='/Users/example/.codex-secondary' codex")
        try expectEqual(launch.environment(base: ["PATH": "/usr/bin"])["CODEX_HOME"], "/Users/example/.codex-secondary")
        try expectEqual(launch.workingDirectory.path, "/Users/example")
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

    static func expectFalse(_ condition: Bool, _ message: String) throws {
        if condition {
            throw TestFailure(message)
        }
    }

    static func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
