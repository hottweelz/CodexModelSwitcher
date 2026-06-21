import Foundation

public struct CodexLauncher {
    public var profile: CodexProfile
    public var executable: String
    public var workingDirectory: URL

    public init(
        profile: CodexProfile,
        executable: String = "codex",
        workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.profile = profile
        self.executable = executable
        self.workingDirectory = workingDirectory
    }

    public func shellCommand() -> String {
        "CODEX_HOME=\(shellEscape(profile.path)) \(executable)"
    }

    public func environment(base: [String: String] = ProcessInfo.processInfo.environment) -> [String: String] {
        var environment = base
        environment["CODEX_HOME"] = profile.path
        return environment
    }

    private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
