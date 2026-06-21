# MEMORY.md

## Durable Project Facts

- CodexModelSwitcher is a native macOS SwiftUI menu bar app using `MenuBarExtra` with accessory activation, so it runs without a Dock icon.
- The app manages Codex provider/model selection by writing to `~/.codex/config.toml` and persists app data under `~/.codex/model-switcher.json`.
- The app includes a local compatibility proxy server in `CodexModelSwitcher/CompatibilityProxyServer.swift` bound to `127.0.0.1:48117`.
- The maintainer already uses separate Codex home directories for multiple accounts: `~/.codex`, `~/.codex-secondary`, `~/.codex-free-1`, `~/.codex-free-2`, and `~/.codex-free-3`.

## Architectural Decisions

- Future multi-account work should prefer switching or launching with explicit `CODEX_HOME` profile directories instead of copying all account credentials into one shared `~/.codex` profile.
- Debug builds should use Xcode's local `Sign to Run Locally` identity so contributors can build without the original maintainer's Apple developer team certificate.
- The default menu-bar surface should be profile-first and should not show proxy status unless a proxy-backed provider is selected or the proxy is active/erroring.
- Provider settings should be discoverable from the main menu bar surface, while API key status should be visible without exposing key values.

## Security Constraints

- API keys and OpenAI account auth JSON are sensitive because the app writes provider keys, environment exports, and selected OpenAI credentials under `~/.codex/`.
- Proxy-related changes must preserve local-only binding unless the user explicitly approves a broader network trust boundary.
- Avoid introducing third-party proxy services for provider traffic; prefer owned, auditable local behavior.

## Coding Conventions

## Maintainer Preferences

- The maintainer does not want to blindly trust the contributor-included proxy; proxy functionality should be disabled, audited, or replaced unless explicitly approved.
- Preserve the existing multi-profile Codex home workflow as a first-class concept.

## Known Constraints

- Codex may need to be restarted after changing provider, model, or OpenAI account settings.

## Update Policy

Update this file only when a durable project fact, architectural decision, security constraint, coding convention, maintainer preference, or known constraint is discovered or changed.

Do not copy chronological handoff entries into this file.
