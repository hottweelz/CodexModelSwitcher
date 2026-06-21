# CHANGELOG_AI.md

This file is the chronological AI handoff ledger for this project.

## 2026-06-21 17:46 EDT - Initialize AI handoff ledger

Task summary: Created the project-local AI handoff ledger.

Selected agent team: not applicable

Changes made:

- Created `CHANGELOG_AI.md`.

Files touched:

- `CHANGELOG_AI.md`

Commands/tests run:

- not applicable

Results: Project-local handoff ledger is ready.

Decisions made:

- Use this file for chronological AI handoffs in this repository.

Known issues:

- none

Next recommended steps:

- Continue with the requested task.

Notes for the next agent: Read the latest entry before making changes.

MEMORY.md update: not needed

## 2026-06-21 19:20 EDT - Fix profile-first menu surface

Task summary: Fixed the menu bar window that visually collapsed to the compact model/proxy surface instead of showing the profile-first UI.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Replaced the `ViewThatFits` profile/model body with an explicit scroll region and minimum body height so profile rows remain visible in the menu-bar window.
- Changed the header from `Codex Models` to `Codex Profiles`.
- Changed the footer to show the selected profile path by default instead of always showing proxy server text.
- Kept proxy status visible only when a proxy-backed provider is selected or the proxy is starting, active, or erroring.
- Made the `config.toml` footer action open the selected profile's config instead of always opening the primary `~/.codex/config.toml`.
- Relaunched the freshly built Debug app and confirmed no process is listening on the proxy port.
- Recorded the profile-first/proxy-hidden default UI decision in `MEMORY.md`.

Files touched:

- `CodexModelSwitcher/ContentView.swift`
- `CodexModelSwitcher/AppStore.swift`
- `MEMORY.md`
- `CHANGELOG_AI.md`

Commands/tests run:

- `swift run ProfileCoreTestRunner`
- `swiftc -typecheck CodexModelSwitcher/*.swift CodexModelSwitcher/ProfileCore/*.swift`
- `git diff --check`
- `xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build`
- `pkill -x CodexModelSwitcher || true`
- `/usr/bin/open -n /Users/jamestylee/Library/Developer/Xcode/DerivedData/CodexModelSwitcher-eqrgpewjpuikooezqcturopizngh/Build/Products/Debug/CodexModelSwitcher.app`
- `pgrep -x CodexModelSwitcher || true`
- `lsof -nP -iTCP:48117 -sTCP:LISTEN || true`
- `strings /Users/jamestylee/Library/Developer/Xcode/DerivedData/CodexModelSwitcher-eqrgpewjpuikooezqcturopizngh/Build/Products/Debug/CodexModelSwitcher.app/Contents/MacOS/CodexModelSwitcher.debug.dylib | rg "Codex Profiles|Codex Models|Proxy server|Proxy active|No profile|config.toml"`
- `xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug -showBuildSettings | rg "CODE_SIGN_IDENTITY|CODE_SIGN_STYLE|DEVELOPMENT_TEAM"`

Results: Core runner passed, Swift typecheck passed, `git diff --check` passed, Xcode Debug build passed, and the fresh app relaunched as PID `53178`. No listener was present on `127.0.0.1:48117`. The built Debug dylib contains `Codex Profiles` and does not contain the old `Codex Models` title.

Decisions made:

- The menu should make profile switching the first visible workflow.
- Proxy status should not be displayed as default chrome when proxy is inactive and the selected provider does not use it.

Known issues:

- The agent cannot directly inspect the menu-bar pixels from this environment; maintainer visual confirmation is still needed.
- The provider editor still includes the compatibility proxy toggle for advanced/audited use.

Next recommended steps:

- Click the menu bar icon and confirm the profile rows are visible above the model list.
- Copy one profile launch command from the UI and verify it launches Codex with the selected `CODEX_HOME`.

Notes for the next agent: If the old compact UI still appears, verify the running PID points at the freshly built DerivedData app and kill any duplicate `CodexModelSwitcher` processes before relaunching.

MEMORY.md update: added default profile-first/proxy-hidden UI decision.

## 2026-06-21 19:14 EDT - Verify Debug app launch

Task summary: Verified the locally signed Debug app can launch as a menu bar process after the maintainer ran the build/run path.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Checked whether `CodexModelSwitcher` was already running.
- Verified the Debug app bundle exists in Xcode DerivedData and is configured as an `LSUIElement` menu bar app.
- Launched the Debug app bundle directly with `open -n`.
- Confirmed the `CodexModelSwitcher` process stayed alive.
- Confirmed the app data file exists without printing its contents.
- No app source behavior changed.

Files touched:

- `CHANGELOG_AI.md`

Commands/tests run:

- `pgrep -x CodexModelSwitcher || true`
- `ps -axo pid,comm | rg 'CodexModelSwitcher$' || true`
- `plutil -p /Users/jamestylee/Library/Developer/Xcode/DerivedData/CodexModelSwitcher-eqrgpewjpuikooezqcturopizngh/Build/Products/Debug/CodexModelSwitcher.app/Contents/Info.plist | rg 'CFBundleIdentifier|LSUIElement|CFBundleName|CFBundleExecutable'`
- `/usr/bin/open -n /Users/jamestylee/Library/Developer/Xcode/DerivedData/CodexModelSwitcher-eqrgpewjpuikooezqcturopizngh/Build/Products/Debug/CodexModelSwitcher.app`
- `pgrep -x CodexModelSwitcher || true`
- `ps -p 46015 -o pid,comm,args`
- `test -f "$HOME/Library/Application Support/CodexModelSwitcher/app-data.json" && ls -l "$HOME/Library/Application Support/CodexModelSwitcher/app-data.json" || true`

Results: The Debug app launched and remained running as PID `46015`. The app bundle is menu-bar-only with `LSUIElement = true`, so it will not show a Dock icon. The app data file exists at `~/Library/Application Support/CodexModelSwitcher/app-data.json`.

Decisions made:

- Leave the launched Debug app running so the maintainer can inspect the menu bar UI.

Known issues:

- Visual menu bar UI/profile-list inspection has not been performed by the agent.
- Debug app data contents were intentionally not printed because app/provider state may become sensitive.

Next recommended steps:

- Inspect the menu bar icon and confirm the profile list shows the expected Codex homes.
- Copy one profile launch command from the UI and verify it starts Codex with the selected `CODEX_HOME`.

Notes for the next agent: The app is a menu bar accessory process, not a Dock app; use exact `pgrep -x CodexModelSwitcher` instead of broad `pgrep -fl` because editor tooling may include the repo path in its command line.

MEMORY.md update: not needed

## 2026-06-21 19:11 EDT - Enable free local Debug signing

Task summary: Switched Debug signing to Xcode's local `Sign to Run Locally` path so contributors can build without the original maintainer's Apple developer team certificate.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Verified a free local Apple Development signing identity is present on this Mac.
- Confirmed the project was still pinned to the upstream Apple developer team for normal Debug builds.
- Changed the Debug target to manual ad-hoc local signing with `CODE_SIGN_IDENTITY = "-"` and an empty `DEVELOPMENT_TEAM`.
- Documented the contributor-friendly Debug signing posture in `README.md`.
- Recorded the signing decision in `MEMORY.md`.

Files touched:

- `CodexModelSwitcher.xcodeproj/project.pbxproj`
- `README.md`
- `MEMORY.md`
- `CHANGELOG_AI.md`

Commands/tests run:

- `security find-identity -p codesigning -v`
- `xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug -showBuildSettings | rg "DEVELOPMENT_TEAM|CODE_SIGN_STYLE|CODE_SIGN_IDENTITY|PRODUCT_BUNDLE_IDENTIFIER"`
- `xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build`
- `swift run ProfileCoreTestRunner`
- `codesign -dvvv --entitlements :- /Users/jamestylee/Library/Developer/Xcode/DerivedData/CodexModelSwitcher-eqrgpewjpuikooezqcturopizngh/Build/Products/Debug/CodexModelSwitcher.app`
- `spctl -a -vv /Users/jamestylee/Library/Developer/Xcode/DerivedData/CodexModelSwitcher-eqrgpewjpuikooezqcturopizngh/Build/Products/Debug/CodexModelSwitcher.app`

Results: Debug build settings now show `CODE_SIGN_IDENTITY = -`, `CODE_SIGN_STYLE = Manual`, and `_DEVELOPMENT_TEAM_IS_EMPTY = YES`. `swift run ProfileCoreTestRunner` passed. Normal `xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build` passed without signing overrides.

Decisions made:

- Use local ad-hoc signing for Debug builds instead of committing a personal Apple developer team ID.
- Keep distribution/release signing as an explicit maintainer setup concern.

Known issues:

- Debug builds are ad-hoc signed and therefore not suitable for Gatekeeper distribution.
- Xcode reports that hardened runtime is disabled for the ad-hoc Debug signature.
- Manual menu bar UI launch/inspection has not been performed yet.

Next recommended steps:

- Launch the Debug app from Xcode and validate the menu bar profile UI against the existing Codex profile directories.
- Configure Release signing separately only when preparing a distributable build.

Notes for the next agent: Do not reintroduce the upstream team ID or a personal Apple team ID into Debug signing; use `Sign to Run Locally` for contributor builds.

MEMORY.md update: added Debug local signing decision.

## 2026-06-21 18:58 EDT - Verify Xcode macOS build

Task summary: Verified the newly installed Xcode toolchain and reran the macOS build checks for the profile-first Codex switcher.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Confirmed Xcode is now selected as the active developer directory.
- Verified the Xcode project exposes the expected `CodexModelSwitcher` scheme.
- Reran the profile core executable test runner.
- Reran the Xcode Debug app build with and without code signing.
- No app source behavior changed.

Files touched:

- `CHANGELOG_AI.md`

Commands/tests run:

- `xcode-select -p`
- `xcodebuild -version`
- `xcodebuild -list -project CodexModelSwitcher.xcodeproj`
- `swift run ProfileCoreTestRunner`
- `xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build`
- `xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug CODE_SIGNING_ALLOWED=NO build`

Results: Xcode is selected at `/Applications/Xcode.app/Contents/Developer`, `xcodebuild` reports Xcode 26.5 build 17F42, `swift run ProfileCoreTestRunner` passed, and the signing-disabled Xcode Debug build succeeded. The normal signed Debug build failed only at signing because no `Mac Development` certificate matching team ID `67329XW74P` with a private key is installed locally.

Decisions made:

- Treat the remaining Xcode blocker as local signing setup, not a source compile issue.
- Do not change source or project signing settings during this verification pass.

Known issues:

- A normal signed build still requires a valid local Mac Development certificate/private key for team `67329XW74P` or a project signing-team update.
- Manual menu bar UI launch/inspection has not been performed yet.

Next recommended steps:

- Open the project in Xcode and configure signing for the maintainer's Apple developer team, or keep using `CODE_SIGNING_ALLOWED=NO` for local compile-only verification.
- Launch the built menu bar app and validate the profile-first UI against the existing Codex profile directories.

Notes for the next agent: The macOS app compiles with signing disabled; do not treat the missing `67329XW74P` signing identity as a code regression.

MEMORY.md update: not needed

## 2026-06-21 18:19 EDT - Implement profile-first Codex switcher

Task summary: Implemented profile-first Codex home management with `CODEX_HOME` launch support and profile-scoped config writing.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Added a SwiftPM-backed profile core for known profile discovery, profile paths, health scanning, non-secret config summary parsing, config rewrite helpers, and launch command construction.
- Added an executable profile core test runner because local Command Line Tools did not provide `XCTest` or Swift `Testing`.
- Wired app state to selected Codex profiles and moved app data storage to `~/Library/Application Support/CodexModelSwitcher/app-data.json`.
- Added profile-scoped config writing so model/provider selection writes to the selected profile's `config.toml`.
- Updated the menu bar UI to show profiles first with profile health, copy launch command, and open folder actions.
- Updated README for profile-first usage and conservative proxy posture.
- Added `.gitignore` for SwiftPM `.build/` output.

Files touched:

- `.gitignore`
- `Package.swift`
- `CodexModelSwitcher/ProfileCore/CodexProfile.swift`
- `CodexModelSwitcher/ProfileCore/CodexProfilePaths.swift`
- `CodexModelSwitcher/ProfileCore/ProfileConfigSummary.swift`
- `CodexModelSwitcher/ProfileCore/ProfileHealthScanner.swift`
- `CodexModelSwitcher/ProfileCore/ProfileConfigEditor.swift`
- `CodexModelSwitcher/ProfileCore/CodexLauncher.swift`
- `Tests/CodexModelSwitcherCoreTests/ProfileCoreTests.swift`
- `CodexModelSwitcher/Types.swift`
- `CodexModelSwitcher/Utils.swift`
- `CodexModelSwitcher/CodexConfigWriter.swift`
- `CodexModelSwitcher/AppStore.swift`
- `CodexModelSwitcher/ContentView.swift`
- `README.md`
- `CHANGELOG_AI.md`

Commands/tests run:

- `swift run ProfileCoreTestRunner`
- `swiftc -typecheck CodexModelSwitcher/*.swift CodexModelSwitcher/ProfileCore/*.swift`
- `rg -n "authJSON|refresh_token|access_token" CodexModelSwitcher/ProfileCore Tests README.md`
- `rg -n "authJSON|refresh_token|access_token" CodexModelSwitcher/ProfileCore README.md`
- `xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build`
- XcodeBuildMCP `session_show_defaults`
- XcodeBuildMCP `list_schemes`
- `git status --short --branch`

Results: `swift run ProfileCoreTestRunner` passed, `swiftc -typecheck` passed for all app and profile core Swift files, and production-scope token-string scan found no `authJSON`, `refresh_token`, or `access_token` matches in `CodexModelSwitcher/ProfileCore` or `README.md`. Full Xcode build could not run because this machine's active developer directory is `/Library/Developer/CommandLineTools` and no `/Applications/Xcode*.app` was visible; XcodeBuildMCP also failed to list schemes because `xcrun` could not find `xcodebuild`.

Decisions made:

- `CODEX_HOME` profile directories are the account boundary.
- Profile labels come from defaults or user state, not token parsing.
- Proxy remains outside the default v1 trust path.
- The local executable runner is the test harness until a full Xcode test setup is available.

Known issues:

- Full Xcode project build remains unverified in this environment because Xcode is not installed or not selected.
- The legacy OpenAI account-management code still exists in the app but is no longer the primary profile-switching path.
- The compatibility proxy remains present in source but is not promoted as trusted default functionality.

Next recommended steps:

- Run a full Xcode build on a machine with Xcode selected.
- Manually launch the menu bar app, confirm all five existing profiles appear, copy one launch command, and verify the command starts Codex with the selected `CODEX_HOME`.
- Consider a follow-up cleanup to hide or remove legacy OpenAI account UI after manual profile-first validation.

Notes for the next agent: Treat profile directories as the account boundary; do not reintroduce default auth JSON copying between profiles.

MEMORY.md update: not needed

## 2026-06-21 17:46 EDT - Explore proxy-safe menu bar direction

Task summary: Inspected the native macOS menu bar app and existing local compatibility proxy to answer how to use the package idea without trusting third-party proxies.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Created missing project-local `MEMORY.md`.
- Recorded durable repo facts and proxy security constraints in `MEMORY.md`.
- Created and updated the project-local `CHANGELOG_AI.md`.
- No app behavior changed.

Files touched:

- `MEMORY.md`
- `CHANGELOG_AI.md`

Commands/tests run:

- `sed -n '1,220p' /Users/jamestylee/.ai/AGENTS.md`
- `sed -n '1,220p' MEMORY.md`
- `sed -n '1,260p' CHANGELOG_AI.md`
- `sed -n '1,240p' /Users/jamestylee/.ai/.ai/rules/agent-team-selection.md`
- `sed -n '1,240p' /Users/jamestylee/.ai/.ai/rules/ai-handoff.md`
- `git status --short --branch`
- `rg --files -n`
- `find /Users/jamestylee/.ai/.ai/agents -maxdepth 2 -type f | sort`
- `sed -n '1,220p' README.md`
- `sed -n '1,560p' CodexModelSwitcher/CompatibilityProxyServer.swift`
- `sed -n '1,320p' CodexModelSwitcher/Types.swift`
- `sed -n '1,620p' CodexModelSwitcher/AppStore.swift`
- `sed -n '1,980p' CodexModelSwitcher/ContentView.swift`
- `sed -n '1,260p' CodexModelSwitcher/CodexConfigWriter.swift`
- `sed -n '1,260p' CodexModelSwitcher/OpenAIAuthManager.swift`
- `sed -n '1,220p' CodexModelSwitcher/AppDelegate.swift`
- `sed -n '1,180p' CodexModelSwitcher/CodexModelSwitcherApp.swift`

Results: Confirmed the package is already a SwiftUI menu bar utility and already has an owned local proxy bound to `127.0.0.1:48117` that translates Responses-style requests to Chat Completions for selected providers.

Decisions made:

- Treat third-party proxy behavior as inspiration only.
- Preserve local-only proxy ownership as the preferred trust boundary unless the user explicitly approves otherwise.

Known issues:

- Existing proxy is lightweight and should be hardened before being treated as a trusted long-term compatibility layer.
- No build/test run was needed for this discovery-only pass.

Next recommended steps:

- Decide whether to pursue a zero-proxy config switcher, a hardened local-only proxy, or a hybrid per-provider mode.
- If implementation is requested, write a short design spec before code changes.

Notes for the next agent: Start with `CompatibilityProxyServer.swift`, `CodexConfigWriter.swift`, and `ContentView.swift`; proxy trust boundaries are the main product/security decision.

MEMORY.md update: added durable app facts and proxy security constraints.

## 2026-06-21 17:48 EDT - Review included proxy trust boundary

Task summary: Responded to maintainer concern about not blindly trusting the contributor-included proxy by inspecting local network, forwarding, and secret-handling surfaces.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Performed a targeted read-only proxy trust review.
- No application behavior changed.

Files touched:

- `CHANGELOG_AI.md`

Commands/tests run:

- `rg -n "URLSession|NWListener|NWConnection|Authorization|Bearer|apiKey|authJSON|refresh_token|access_token|launchctl|write\\(|baseURL|127\\.0\\.0\\.1|0\\.0\\.0\\.0|http://|https://" CodexModelSwitcher README.md`
- `sed -n '1,260p' CodexModelSwitcher/Utils.swift`
- `sed -n '1,200p' CodexModelSwitcher/CodexModelSwitcher.entitlements`
- `rg -n "AppPaths|codexDirectory|model-switcher|shellProfile|loginDirectory|envFile|codexConfig" CodexModelSwitcher`
- `nl -ba CodexModelSwitcher/CompatibilityProxyServer.swift | sed -n '1,180p'`
- `nl -ba CodexModelSwitcher/CompatibilityProxyServer.swift | sed -n '181,380p'`
- `nl -ba CodexModelSwitcher/CompatibilityProxyServer.swift | sed -n '380,500p'`
- `nl -ba CodexModelSwitcher/CodexConfigWriter.swift | sed -n '80,125p'`
- `nl -ba CodexModelSwitcher/Utils.swift | sed -n '1,35p'`

Results: The included proxy is local Swift code, binds to `127.0.0.1:48117`, forwards only to the configured provider base URL, and injects the selected provider API key. No hidden hosted proxy endpoint was found in the inspected source. The main concern is that the listener has no strong local auth gate, so any local process that can reach the loopback port while the app is running could try to use the selected proxy route.

Decisions made:

- Do not blindly trust the included proxy as-is.
- Prefer either disabling proxy by default or replacing/hardening it behind local-only binding, strict provider allowlisting, request validation, and a per-session local auth token.

Known issues:

- API keys and OpenAI auth JSON remain stored under `~/.codex/` by current app design.
- Proxy hardening has not yet been implemented.

Next recommended steps:

- Choose a proxy posture: zero-proxy first, hardened local proxy, or hybrid.
- If proxy remains, implement local auth, host allowlist validation, size limits, response redaction, explicit UI warning, and focused tests.

Notes for the next agent: The local listener and request parser are the highest-priority proxy hardening surfaces.

MEMORY.md update: not needed

## 2026-06-21 17:51 EDT - Capture existing CODEX_HOME profile workflow

Task summary: Incorporated maintainer context that multiple Codex accounts are already managed manually through separate home directories.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Verified the listed Codex home directories exist without reading token contents.
- Recorded the multi-profile account workflow in `MEMORY.md`.
- No app behavior changed.

Files touched:

- `MEMORY.md`
- `CHANGELOG_AI.md`

Commands/tests run:

- `for d in "$HOME/.codex" "$HOME/.codex-secondary" "$HOME/.codex-free-1" "$HOME/.codex-free-2" "$HOME/.codex-free-3"; do ...`
- `rg -n "CODEX_HOME|codex-secondary|codex-free|authJSON|selectedOpenAIAccountID|openAIAccounts|model-switcher" README.md CodexModelSwitcher MEMORY.md CHANGELOG_AI.md`
- `rg -n "CODEX_HOME|codex-free|codex-secondary|\\.codex-free|HomeBoss|HomeAI" /Users/jamestylee/.codex/memories/MEMORY.md`

Results: Confirmed all five profiles exist locally and have separate `auth.json` and `config.toml` files. Prior memory also confirms adjacent tooling treated Codex worker homes as separate account surfaces.

Decisions made:

- Treat explicit `CODEX_HOME` profile directories as the safer primary account model.
- Avoid designing around blind credential copying from every account into `~/.codex/model-switcher.json`.

Known issues:

- Current app code is still centered on `~/.codex` and the `openAIAccounts` auth JSON store.
- No implementation has been done yet.

Next recommended steps:

- Design a profile-aware switcher that discovers, labels, validates, and launches Codex profiles using explicit `CODEX_HOME`.

Notes for the next agent: Start the design from `AppPaths.codexDirectory`, `OpenAIAuthManager.loginEnvironment`, and `CodexConfigWriter.writeOpenAIAuth`; those are the current fixed-home/copy-auth surfaces.

MEMORY.md update: added existing multi-profile Codex home workflow and maintainer preference.

## 2026-06-21 17:52 EDT - Write profile-first design spec

Task summary: Wrote the approved profile-first switcher design for maintainer review.

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

Changes made:

- Added a design spec for converting CodexModelSwitcher into a profile-first `CODEX_HOME` switcher.
- Kept proxy work explicitly outside v1 and marked it as disabled/audited-later.
- Reordered local handoff entries into chronological order.
- No Swift implementation changed.

Files touched:

- `docs/superpowers/specs/2026-06-21-profile-first-codex-switcher-design.md`
- `CHANGELOG_AI.md`

Commands/tests run:

- `find docs -maxdepth 3 -type f | sort`
- `sed -n '1,220p' MEMORY.md`
- `sed -n '1,260p' CHANGELOG_AI.md`
- `git status --short --branch`
- `git ls-files`
- `git log --oneline -5`
- `nl -ba CHANGELOG_AI.md | sed -n '1,260p'`
- `rg -n "TBD|TODO|placeholder|Open Questions|open question|maybe|later\\?|\\?\\?" docs/superpowers/specs/2026-06-21-profile-first-codex-switcher-design.md CHANGELOG_AI.md MEMORY.md`
- `sed -n '1,260p' docs/superpowers/specs/2026-06-21-profile-first-codex-switcher-design.md`

Results: Design document passed placeholder and ambiguity self-review and is ready for maintainer review before implementation planning.

Decisions made:

- V1 should be profile-first and should not store auth JSON in new app profile storage.
- Existing compatibility proxy remains out of the default v1 trust path.

Known issues:

- Spec has not yet been converted into an implementation plan.
- Existing app code still uses fixed `~/.codex` paths and the old account-auth model.

Next recommended steps:

- Maintainer should review the design spec.
- After approval, create an implementation plan for profile models, discovery, profile-aware config writing, UI changes, and tests.

Notes for the next agent: Do not implement until the maintainer approves the written spec; next workflow step is implementation planning.

MEMORY.md update: not needed
