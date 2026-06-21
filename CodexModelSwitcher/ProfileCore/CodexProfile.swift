import Foundation

public struct CodexProfile: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var path: String
    public var isPinned: Bool

    public init(id: String, name: String, path: String, isPinned: Bool) {
        self.id = id
        self.name = name
        self.path = path
        self.isPinned = isPinned
    }

    public static func defaultProfiles(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [CodexProfile] {
        let home = homeDirectory.path
        return [
            CodexProfile(id: "primary", name: "Primary", path: "\(home)/.codex", isPinned: true),
            CodexProfile(id: "secondary", name: "Secondary", path: "\(home)/.codex-secondary", isPinned: true),
            CodexProfile(id: "free-1", name: "Free 1", path: "\(home)/.codex-free-1", isPinned: true),
            CodexProfile(id: "free-2", name: "Free 2", path: "\(home)/.codex-free-2", isPinned: true),
            CodexProfile(id: "free-3", name: "Free 3", path: "\(home)/.codex-free-3", isPinned: true)
        ]
    }
}
