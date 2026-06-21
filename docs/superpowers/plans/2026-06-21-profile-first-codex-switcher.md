# Profile-First Codex Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert CodexModelSwitcher into a profile-first menu bar app that manages separate Codex home directories through `CODEX_HOME` instead of copying account auth JSON.

**Architecture:** Add a small pure Swift profile core that is testable with SwiftPM, then wire it into the existing SwiftUI menu bar app. The app will discover known profile homes, show profile health, write provider/model config to the selected profile only, and generate or run profile-specific launch commands. The included compatibility proxy remains disabled and outside the default v1 flow.

**Tech Stack:** Swift 5, SwiftUI MenuBarExtra, Foundation FileManager/Process, Swift Package Manager for core unit tests, existing Xcode macOS app target.

---

## File Structure

- Create `Package.swift`: SwiftPM test harness for pure profile code.
- Create `CodexModelSwitcher/ProfileCore/CodexProfile.swift`: profile value model and default profile definitions.
- Create `CodexModelSwitcher/ProfileCore/CodexProfilePaths.swift`: profile-relative path resolver and app support paths.
- Create `CodexModelSwitcher/ProfileCore/ProfileHealthScanner.swift`: non-secret profile health detection.
- Create `CodexModelSwitcher/ProfileCore/ProfileConfigSummary.swift`: lightweight non-secret TOML summary parser.
- Create `CodexModelSwitcher/ProfileCore/ProfileConfigEditor.swift`: string-level `config.toml` rewrite helpers for selected model/provider.
- Create `CodexModelSwitcher/ProfileCore/CodexLauncher.swift`: launch command and process environment builder.
- Create `Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift`: SwiftPM unit tests for the profile core.
- Modify `CodexModelSwitcher/Types.swift`: add profile fields to `AppData` while keeping legacy account fields decodable.
- Modify `CodexModelSwitcher/Utils.swift`: move app storage to app support and expose profile path helpers.
- Modify `CodexModelSwitcher/CodexConfigWriter.swift`: write to the selected profile paths instead of fixed `~/.codex`.
- Modify `CodexModelSwitcher/AppStore.swift`: load/discover profiles, track selected profile, expose profile health, and route config writes through profile paths.
- Modify `CodexModelSwitcher/ContentView.swift`: make profile selection the first UI surface and keep provider/model editing scoped to the active profile.
- Modify `README.md`: document profile-first usage and proxy posture.
- Modify `CHANGELOG_AI.md`: add handoff entries as tasks complete.

---

### Task 1: Add Profile Core Models And Discovery

**Files:**
- Create: `Package.swift`
- Create: `CodexModelSwitcher/ProfileCore/CodexProfile.swift`
- Create: `CodexModelSwitcher/ProfileCore/CodexProfilePaths.swift`
- Test: `Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift`

- [ ] **Step 1: Write failing tests for default profile discovery**

Create `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexModelSwitcherCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CodexModelSwitcherCore", targets: ["CodexModelSwitcherCore"])
    ],
    targets: [
        .target(
            name: "CodexModelSwitcherCore",
            path: "CodexModelSwitcher/ProfileCore"
        ),
        .testTarget(
            name: "CodexModelSwitcherCoreTests",
            dependencies: ["CodexModelSwitcherCore"],
            path: "Tests/CodexModelSwitcherCoreTests"
        )
    ]
)
```

Create `Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift`:

```swift
import XCTest
@testable import CodexModelSwitcherCore

final class ProfileCoreTests: XCTestCase {
    func testDefaultProfilesUseExistingCodexHomeNames() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let profiles = CodexProfile.defaultProfiles(homeDirectory: home)

        XCTAssertEqual(profiles.map(\.name), ["Primary", "Secondary", "Free 1", "Free 2", "Free 3"])
        XCTAssertEqual(profiles.map(\.path), [
            "/Users/example/.codex",
            "/Users/example/.codex-secondary",
            "/Users/example/.codex-free-1",
            "/Users/example/.codex-free-2",
            "/Users/example/.codex-free-3"
        ])
        XCTAssertEqual(profiles.first?.id, "primary")
        XCTAssertTrue(profiles.allSatisfy(\.isPinned))
    }

    func testProfilePathsResolveInsideSelectedProfile() {
        let profile = CodexProfile(
            id: "free-1",
            name: "Free 1",
            path: "/Users/example/.codex-free-1",
            isPinned: true
        )

        let paths = CodexProfilePaths(profile: profile)

        XCTAssertEqual(paths.home.path, "/Users/example/.codex-free-1")
        XCTAssertEqual(paths.config.path, "/Users/example/.codex-free-1/config.toml")
        XCTAssertEqual(paths.auth.path, "/Users/example/.codex-free-1/auth.json")
        XCTAssertEqual(paths.envFile.path, "/Users/example/.codex-free-1/model-switcher.env")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter ProfileCoreTests/testDefaultProfilesUseExistingCodexHomeNames
```

Expected: FAIL because `CodexProfile` and `CodexProfilePaths` do not exist yet.

- [ ] **Step 3: Implement profile models and paths**

Create `CodexModelSwitcher/ProfileCore/CodexProfile.swift`:

```swift
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

    public static func defaultProfiles(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [CodexProfile] {
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
```

Create `CodexModelSwitcher/ProfileCore/CodexProfilePaths.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter ProfileCoreTests
```

Expected: PASS for the two profile model/path tests.

- [ ] **Step 5: Commit**

```bash
git add Package.swift CodexModelSwitcher/ProfileCore Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift
git commit -m "Add Codex profile core models"
```

---

### Task 2: Add Non-Secret Health And Config Summary Parsing

**Files:**
- Create: `CodexModelSwitcher/ProfileCore/ProfileHealthScanner.swift`
- Create: `CodexModelSwitcher/ProfileCore/ProfileConfigSummary.swift`
- Modify: `Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift`

- [ ] **Step 1: Write failing tests for profile health and config summary**

Append to `ProfileCoreTests`:

```swift
    func testHealthScannerReportsAuthConfigAndSelectedModelWithoutReadingSecrets() throws {
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

        XCTAssertTrue(health.exists)
        XCTAssertTrue(health.hasAuth)
        XCTAssertTrue(health.hasConfig)
        XCTAssertEqual(health.selectedModel, "gpt-5.5")
        XCTAssertEqual(health.selectedProvider, "openai")
        XCTAssertEqual(health.status, .ready)
    }

    func testConfigSummaryParsesTopLevelModelAndProviderOnly() {
        let summary = ProfileConfigSummary.parse("""
        model = "gpt-5.5"
        model_provider = "openrouter"

        [model_providers.openrouter]
        name = "OpenRouter"
        base_url = "https://openrouter.ai/api/v1"
        """)

        XCTAssertEqual(summary.model, "gpt-5.5")
        XCTAssertEqual(summary.modelProvider, "openrouter")
        XCTAssertTrue(summary.providerIDs.contains("openrouter"))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter ProfileCoreTests/testHealthScannerReportsAuthConfigAndSelectedModelWithoutReadingSecrets
```

Expected: FAIL because `ProfileHealthScanner`, `ProfileHealth`, and `ProfileConfigSummary` do not exist yet.

- [ ] **Step 3: Implement health scanner and summary parser**

Create `CodexModelSwitcher/ProfileCore/ProfileConfigSummary.swift`:

```swift
import Foundation

public struct ProfileConfigSummary: Equatable {
    public var model: String?
    public var modelProvider: String?
    public var providerIDs: [String]

    public static func parse(_ content: String) -> ProfileConfigSummary {
        var model: String?
        var modelProvider: String?
        var providerIDs: [String] = []
        var isTopLevel = true

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            if trimmed.hasPrefix("[") {
                isTopLevel = false
                if let providerID = providerID(from: trimmed) {
                    providerIDs.append(providerID)
                }
                continue
            }
            if isTopLevel, trimmed.hasPrefix("model =") {
                model = quotedValue(from: trimmed)
            }
            if isTopLevel, trimmed.hasPrefix("model_provider =") {
                modelProvider = quotedValue(from: trimmed)
            }
        }

        return ProfileConfigSummary(model: model, modelProvider: modelProvider, providerIDs: providerIDs)
    }

    private static func quotedValue(from line: String) -> String? {
        guard let first = line.firstIndex(of: "\""),
              let last = line.lastIndex(of: "\""),
              first < last else {
            return nil
        }
        return String(line[line.index(after: first)..<last])
    }

    private static func providerID(from tableHeader: String) -> String? {
        guard tableHeader.hasPrefix("[model_providers."),
              tableHeader.hasSuffix("]") else {
            return nil
        }
        return String(tableHeader.dropFirst("[model_providers.".count).dropLast())
            .split(separator: ".", maxSplits: 1)
            .first
            .map(String.init)
    }
}
```

Create `CodexModelSwitcher/ProfileCore/ProfileHealthScanner.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter ProfileCoreTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add CodexModelSwitcher/ProfileCore Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift
git commit -m "Add profile health scanning"
```

---

### Task 3: Add Profile Config Editing And Launch Command Builders

**Files:**
- Create: `CodexModelSwitcher/ProfileCore/ProfileConfigEditor.swift`
- Create: `CodexModelSwitcher/ProfileCore/CodexLauncher.swift`
- Modify: `Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift`

- [ ] **Step 1: Write failing tests for config rewrite and launch environment**

Append to `ProfileCoreTests`:

```swift
    func testProfileConfigEditorWritesSelectedModelAndProviderAtTopLevel() {
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

        XCTAssertTrue(updated.hasPrefix("""
        model = "moonshotai/kimi-k2.5"
        model_provider = "openrouter"
        """))
        XCTAssertTrue(updated.contains("[model_providers.openrouter]"))
        XCTAssertFalse(updated.contains("model = \"old-model\""))
        XCTAssertFalse(updated.contains("model_provider = \"old-provider\""))
    }

    func testLauncherBuildsCommandAndEnvironmentForProfile() {
        let profile = CodexProfile(
            id: "secondary",
            name: "Secondary",
            path: "/Users/example/.codex-secondary",
            isPinned: true
        )

        let launch = CodexLauncher(profile: profile)

        XCTAssertEqual(launch.shellCommand(), "CODEX_HOME='/Users/example/.codex-secondary' codex")
        XCTAssertEqual(launch.environment(base: ["PATH": "/usr/bin"])["CODEX_HOME"], "/Users/example/.codex-secondary")
        XCTAssertEqual(launch.workingDirectory.path, "/Users/example")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter ProfileCoreTests/testProfileConfigEditorWritesSelectedModelAndProviderAtTopLevel
```

Expected: FAIL because `ProfileConfigEditor` does not exist yet.

- [ ] **Step 3: Implement config editor and launcher**

Create `CodexModelSwitcher/ProfileCore/ProfileConfigEditor.swift`:

```swift
import Foundation

public struct ProfileConfigEditor {
    public init() {}

    public func rewrite(_ content: String, selectedModel: String, selectedProvider: String?) -> String {
        var lines = content.components(separatedBy: .newlines)
        if lines.last == "" {
            lines.removeLast()
        }
        lines = removeTopLevelKey("model", from: lines)
        lines = removeTopLevelKey("model_provider", from: lines)

        var prefix = [#"model = "\#(tomlEscape(selectedModel))""#]
        if let selectedProvider, !selectedProvider.isEmpty, selectedProvider != "openai" {
            prefix.append(#"model_provider = "\#(tomlEscape(selectedProvider))""#)
        }

        let remaining = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        var output = prefix.joined(separator: "\n")
        if !remaining.isEmpty {
            output += "\n\n" + remaining
        }
        return output + "\n"
    }

    private func removeTopLevelKey(_ key: String, from lines: [String]) -> [String] {
        var isTopLevel = true
        return lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                isTopLevel = false
            }
            return !(isTopLevel && trimmed.hasPrefix("\(key) ="))
        }
    }

    private func tomlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
```

Create `CodexModelSwitcher/ProfileCore/CodexLauncher.swift`:

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter ProfileCoreTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add CodexModelSwitcher/ProfileCore Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift
git commit -m "Add profile config and launch helpers"
```

---

### Task 4: Wire Profiles Into App State And Config Writing

**Files:**
- Modify: `CodexModelSwitcher/Types.swift`
- Modify: `CodexModelSwitcher/Utils.swift`
- Modify: `CodexModelSwitcher/CodexConfigWriter.swift`
- Modify: `CodexModelSwitcher/AppStore.swift`

- [ ] **Step 1: Write failing tests for no auth JSON persistence in core app data**

Append to `ProfileCoreTests`:

```swift
    func testProfileStorageJSONContainsProfileLabelsButNoAuthJSON() throws {
        let profile = CodexProfile(
            id: "primary",
            name: "Primary",
            path: "/Users/example/.codex",
            isPinned: true
        )

        let encoded = try JSONEncoder().encode([profile])
        let json = String(data: encoded, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"path\""))
        XCTAssertFalse(json.contains("authJSON"))
        XCTAssertFalse(json.contains("refresh_token"))
        XCTAssertFalse(json.contains("access_token"))
    }
```

- [ ] **Step 2: Run test to verify it passes before app wiring**

Run:

```bash
swift test --filter ProfileCoreTests/testProfileStorageJSONContainsProfileLabelsButNoAuthJSON
```

Expected: PASS. This guards the profile storage model before wiring it into the app.

- [ ] **Step 3: Add profile fields to app data**

Modify `CodexModelSwitcher/Types.swift`:

```swift
struct AppData: Codable {
    var services: [CodexService]
    var selectedModel: SelectedModel?
    var profiles: [CodexProfile]
    var selectedProfileID: String?
    var openAIAccounts: [OpenAIAccount]
    var selectedOpenAIAccountID: String?

    static let empty = AppData(services: [], selectedModel: nil)

    init(
        services: [CodexService],
        selectedModel: SelectedModel?,
        profiles: [CodexProfile] = CodexProfile.defaultProfiles(),
        selectedProfileID: String? = "primary",
        openAIAccounts: [OpenAIAccount] = [],
        selectedOpenAIAccountID: String? = nil
    ) {
        self.services = services
        self.selectedModel = selectedModel
        self.profiles = profiles
        self.selectedProfileID = selectedProfileID
        self.openAIAccounts = openAIAccounts
        self.selectedOpenAIAccountID = selectedOpenAIAccountID
    }

    enum CodingKeys: String, CodingKey {
        case services
        case selectedModel
        case profiles
        case selectedProfileID
        case openAIAccounts
        case selectedOpenAIAccountID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        services = try container.decode([CodexService].self, forKey: .services)
        selectedModel = try container.decodeIfPresent(SelectedModel.self, forKey: .selectedModel)
        profiles = try container.decodeIfPresent([CodexProfile].self, forKey: .profiles) ?? CodexProfile.defaultProfiles()
        selectedProfileID = try container.decodeIfPresent(String.self, forKey: .selectedProfileID) ?? profiles.first?.id
        openAIAccounts = try container.decodeIfPresent([OpenAIAccount].self, forKey: .openAIAccounts) ?? []
        selectedOpenAIAccountID = try container.decodeIfPresent(String.self, forKey: .selectedOpenAIAccountID)
    }
}
```

- [ ] **Step 4: Move app data paths to application support**

Modify `CodexModelSwitcher/Utils.swift` so `AppPaths` includes profile-aware storage:

```swift
enum AppPaths {
    static let appSupportDirectory = CodexModelSwitcherAppPaths.supportDirectory
    static let appData = CodexModelSwitcherAppPaths.appData
    static let profilesData = CodexModelSwitcherAppPaths.profilesData
    static let defaultCodexDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex", isDirectory: true)

    static let codexDirectory = defaultCodexDirectory
    static let codexConfig = defaultCodexDirectory.appendingPathComponent("config.toml")
    static let loginDirectory = defaultCodexDirectory
        .appendingPathComponent("model-switcher", isDirectory: true)
        .appendingPathComponent("login", isDirectory: true)
    static let envFile = defaultCodexDirectory.appendingPathComponent("model-switcher.env")
    static let shellProfile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".zprofile")

    static func profilePaths(for profile: CodexProfile) -> CodexProfilePaths {
        CodexProfilePaths(profile: profile)
    }
}
```

- [ ] **Step 5: Make config writer accept profile paths**

Modify `CodexModelSwitcher/CodexConfigWriter.swift`:

```swift
func applySelection(_ selected: SelectedModel, in data: AppData, profile: CodexProfile) throws {
    guard let service = data.services.first(where: { $0.id == selected.serviceID }) else {
        throw AppError.missingService
    }
    guard service.models.contains(where: { $0.id == selected.modelID }) else {
        throw AppError.missingModel
    }

    let paths = AppPaths.profilePaths(for: profile)
    try FileManager.default.createDirectory(
        at: paths.home,
        withIntermediateDirectories: true
    )

    let current = (try? String(contentsOf: paths.config, encoding: .utf8)) ?? ""
    let updated = rewriteConfig(current, selected: selected, data: data)
    try updated.write(to: paths.config, atomically: true, encoding: .utf8)

    try writeAPIKeys(for: data.services, envFile: paths.envFile)
    if service.requiresAPIKey, !service.apiKey.isEmpty {
        setLaunchEnvironment(name: service.envKey, value: service.apiKey)
    }
}
```

Also change `writeAPIKeys` signature:

```swift
private func writeAPIKeys(for services: [CodexService], envFile: URL) throws {
    let exports = services
        .filter { $0.requiresAPIKey && !$0.apiKey.isEmpty }
        .map { "export \($0.envKey)=\(shellEscape($0.apiKey))" }
        .joined(separator: "\n")

    try (exports + (exports.isEmpty ? "" : "\n"))
        .write(to: envFile, atomically: true, encoding: .utf8)
}
```

Keep `restoreOpenAIAuth(from:)` available for legacy account records, but remove calls to it from profile-first selection and model-switching flows. Keep the old fixed-home `applySelection(_:in:)` only as a wrapper that calls the new overload with the primary profile.

- [ ] **Step 6: Route AppStore selection through selected profile**

Modify `CodexModelSwitcher/AppStore.swift` by adding:

```swift
var selectedProfile: CodexProfile? {
    guard let selectedProfileID = data.selectedProfileID else { return data.profiles.first }
    return data.profiles.first { $0.id == selectedProfileID } ?? data.profiles.first
}

func profileHealth(for profile: CodexProfile) -> ProfileHealth {
    ProfileHealthScanner().health(for: profile)
}

func selectProfile(_ profileID: String) {
    data.selectedProfileID = profileID
    persist()
    statusMessage = "Selected Codex profile."
    errorMessage = ""
}

func launchCommand(for profile: CodexProfile) -> String {
    CodexLauncher(profile: profile).shellCommand()
}
```

Update `select(serviceID:modelID:)` to use the selected profile:

```swift
guard let profile = selectedProfile else {
    errorMessage = "Choose a Codex profile first."
    return
}
try configWriter.applySelection(selected, in: data, profile: profile)
```

Update `persist()` to create `AppPaths.appSupportDirectory` instead of `AppPaths.codexDirectory`.

- [ ] **Step 7: Run tests and build**

Run:

```bash
swift test
xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build
```

Expected: `swift test` PASS and Xcode build PASS.

- [ ] **Step 8: Commit**

```bash
git add CodexModelSwitcher Package.swift Tests
git commit -m "Wire app state to Codex profiles"
```

---

### Task 5: Replace Account-First UI With Profile-First UI

**Files:**
- Modify: `CodexModelSwitcher/ContentView.swift`
- Modify: `CodexModelSwitcher/AppStore.swift`

- [ ] **Step 1: Add profile list helpers to AppStore**

Modify `AppStore.swift`:

```swift
func copyLaunchCommand(for profile: CodexProfile) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(launchCommand(for: profile), forType: .string)
    statusMessage = "Copied launch command for \(profile.name)."
    errorMessage = ""
}

func openProfileFolder(_ profile: CodexProfile) {
    NSWorkspace.shared.open(URL(fileURLWithPath: profile.path, isDirectory: true))
}
```

Ensure `AppStore.swift` imports AppKit:

```swift
import AppKit
import Foundation
import SwiftUI
```

- [ ] **Step 2: Add profile-first UI section**

In `ContentView.swift`, replace `serviceList` in the non-editor body with a profile-first stack:

```swift
private var serviceList: some View {
    ViewThatFits(in: .vertical) {
        profileAndServiceStack
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        ScrollView {
            profileAndServiceStack
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }
    .frame(maxHeight: maxBodyHeight)
}

private var profileAndServiceStack: some View {
    VStack(alignment: .leading, spacing: 10) {
        profileStack
        Divider()
        Text("Models")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        serviceStack
    }
}

private var profileStack: some View {
    VStack(alignment: .leading, spacing: 4) {
        Text("Profiles")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        ForEach(store.data.profiles) { profile in
            ProfileRowView(profile: profile)
                .environmentObject(store)
        }
    }
}
```

- [ ] **Step 3: Add profile row view**

Add this view near `ServiceSectionView` in `ContentView.swift`:

```swift
private struct ProfileRowView: View {
    @EnvironmentObject private var store: AppStore
    let profile: CodexProfile
    @State private var isHovering = false

    var body: some View {
        let health = store.profileHealth(for: profile)
        Button {
            store.selectProfile(profile.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: iconName(for: health.status))
                    .foregroundStyle(iconColor(for: health.status))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.name)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .lineLimit(1)
                    Text(detailText(for: health))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if store.data.selectedProfileID == profile.id {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                if isHovering {
                    Button {
                        store.copyLaunchCommand(for: profile)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy launch command")

                    Button {
                        store.openProfileFolder(profile)
                    } label: {
                        Image(systemName: "folder")
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help("Open profile folder")
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(store.data.selectedProfileID == profile.id ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { isHovering = $0 }
    }

    private func detailText(for health: ProfileHealth) -> String {
        switch health.status {
        case .missing:
            return "\(shortPath(profile.path)) - missing"
        case .notLoggedIn:
            return "\(shortPath(profile.path)) - not logged in"
        case .noConfig:
            return "\(shortPath(profile.path)) - no config"
        case .ready:
            return [health.selectedProvider, health.selectedModel]
                .compactMap { $0 }
                .joined(separator: " / ")
        }
    }

    private func iconName(for status: ProfileHealthStatus) -> String {
        switch status {
        case .missing:
            return "questionmark.circle"
        case .notLoggedIn:
            return "person.crop.circle.badge.exclamationmark"
        case .noConfig:
            return "doc.badge.gearshape"
        case .ready:
            return "checkmark.circle.fill"
        }
    }

    private func iconColor(for status: ProfileHealthStatus) -> Color {
        switch status {
        case .ready:
            return .green
        case .missing, .notLoggedIn, .noConfig:
            return .orange
        }
    }

    private func shortPath(_ path: String) -> String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}
```

- [ ] **Step 4: Update header text for active profile**

Change `currentSelectionText` in `ContentView.swift`:

```swift
private var currentSelectionText: String {
    guard let profile = store.selectedProfile,
          let service = store.selectedService,
          let model = store.selectedModel else {
        return "No profile selected"
    }

    return "\(profile.name) / \(service.name) / \(model.name)"
}
```

- [ ] **Step 5: Run build**

Run:

```bash
xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add CodexModelSwitcher/ContentView.swift CodexModelSwitcher/AppStore.swift
git commit -m "Add profile-first menu UI"
```

---

### Task 6: Documentation, Final Verification, And Handoff

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG_AI.md`

- [ ] **Step 1: Update README**

Replace the opening description in `README.md` with:

```markdown
# Codex Model Switcher

A small macOS menu bar app for managing local Codex profiles and model provider configurations.

The app treats each Codex home directory as an account boundary. It can discover profiles such as `~/.codex`, `~/.codex-secondary`, `~/.codex-free-1`, `~/.codex-free-2`, and `~/.codex-free-3`, then edit the selected profile's `config.toml` or copy a launch command using `CODEX_HOME`.
```

Update the feature list:

```markdown
## Features

- Discover and switch between local Codex profiles.
- Show profile health without displaying token contents.
- Add, edit, and delete custom model providers.
- Manage multiple models per provider.
- Write model/provider config to the selected profile only.
- Copy a `CODEX_HOME='/path/to/profile' codex` launch command for any profile.
- Keep the app menu-bar only, without a Dock icon.
```

Update the notes:

```markdown
## Notes

Codex may need to be restarted after changing provider or model settings.

Each profile keeps its own `auth.json`, `config.toml`, sessions, memories, and local state. The app does not copy profile auth JSON by default.

The compatibility proxy is not part of the default profile-first flow. Treat proxy behavior as advanced/audited functionality only.
```

- [ ] **Step 2: Run full verification**

Run:

```bash
swift test
xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build
rg -n "authJSON|refresh_token|access_token" CodexModelSwitcher/ProfileCore Tests README.md
git status --short --branch
```

Expected:

- `swift test` passes.
- Xcode build succeeds.
- `rg` finds no `authJSON`, `refresh_token`, or `access_token` in new profile core/tests/README.
- `git status` shows only intentional changes plus any pre-existing untracked adapter files.

- [ ] **Step 3: Add final handoff**

Add a `CHANGELOG_AI.md` entry containing:

```markdown
## 2026-06-21 HH:MM EDT - Implement profile-first Codex switcher

Task summary: Implemented profile-first Codex home management with `CODEX_HOME` launch support and profile-scoped config writing.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Added a tested profile core for known profile discovery, health scanning, config summary parsing, config rewrite helpers, and launch command construction.
- Wired app state to selected Codex profiles.
- Updated menu bar UI to show profiles first.
- Updated README for profile-first usage.

Files touched:

- `Package.swift`
- `CodexModelSwitcher/ProfileCore/*`
- `Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift`
- `CodexModelSwitcher/Types.swift`
- `CodexModelSwitcher/Utils.swift`
- `CodexModelSwitcher/CodexConfigWriter.swift`
- `CodexModelSwitcher/AppStore.swift`
- `CodexModelSwitcher/ContentView.swift`
- `README.md`
- `CHANGELOG_AI.md`

Commands/tests run:

- `swift test`
- `xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build`
- `rg -n "authJSON|refresh_token|access_token" CodexModelSwitcher/ProfileCore Tests README.md`
- `git status --short --branch`

Results: `swift test` passed, Xcode Debug build passed, and the token-string scan found no auth JSON token fields in the new profile core, tests, or README.

Decisions made:

- `CODEX_HOME` profile directories are the account boundary.
- Proxy remains outside the default v1 trust path.

Known issues:

- The compatibility proxy remains outside the default v1 trust path and still needs a separate hardening project before promotion.

Next recommended steps:

- Manually launch the menu bar app, confirm all five existing profiles appear, copy one launch command, and verify the command starts Codex with the selected `CODEX_HOME`.

Notes for the next agent: Treat profile directories as the account boundary; do not reintroduce default auth JSON copying between profiles.

MEMORY.md update: not needed
```

- [ ] **Step 4: Commit final documentation and handoff**

```bash
git add README.md CHANGELOG_AI.md
git commit -m "Document profile-first switcher usage"
```

- [ ] **Step 5: Report result**

Final response should include:

- commits made
- tests/build commands and results
- any known issues
- whether the branch is ahead of origin
