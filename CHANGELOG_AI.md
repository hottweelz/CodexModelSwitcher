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
