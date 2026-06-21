import Foundation

public enum ProfileHealthStatus: String, Codable, Equatable {
    case missing
    case notLoggedIn
    case noConfig
    case ready
}

public struct ProfileHealth: Equatable {
    public var exists: Bool
    public var hasAuth: Bool
    public var hasConfig: Bool
    public var selectedModel: String?
    public var selectedProvider: String?
    public var status: ProfileHealthStatus
}

public struct ProfileHealthScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func health(for profile: CodexProfile) -> ProfileHealth {
        let paths = CodexProfilePaths(profile: profile)
        let exists = fileManager.fileExists(atPath: paths.home.path)
        let hasAuth = fileManager.fileExists(atPath: paths.auth.path)
        let hasConfig = fileManager.fileExists(atPath: paths.config.path)
        let summary = (try? String(contentsOf: paths.config, encoding: .utf8))
            .map(ProfileConfigSummary.parse)

        let status: ProfileHealthStatus
        if !exists {
            status = .missing
        } else if !hasAuth {
            status = .notLoggedIn
        } else if !hasConfig {
            status = .noConfig
        } else {
            status = .ready
        }

        return ProfileHealth(
            exists: exists,
            hasAuth: hasAuth,
            hasConfig: hasConfig,
            selectedModel: summary?.model,
            selectedProvider: summary?.modelProvider,
            status: status
        )
    }
}
