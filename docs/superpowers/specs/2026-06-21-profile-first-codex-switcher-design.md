# Profile-First Codex Switcher Design

Status: Draft for maintainer review

Date: 2026-06-21

Selected agent team: product-manager, macos-spatial-metal-engineer, security-reviewer

## Summary

CodexModelSwitcher should pivot from an account-auth copier into a profile-first menu bar app. The core object is a Codex home directory, not an OpenAI account JSON blob. Each profile keeps its own `auth.json`, `config.toml`, sessions, memories, caches, and local state. The app discovers and manages profiles such as `~/.codex`, `~/.codex-secondary`, `~/.codex-free-1`, `~/.codex-free-2`, and `~/.codex-free-3`, then helps the maintainer edit each profile's model/provider config or launch Codex with an explicit `CODEX_HOME`.

The compatibility proxy remains out of the v1 trust path. Existing proxy code can stay disabled or hidden behind an advanced setting until it is separately audited and hardened.

## Problem

The current app stores managed OpenAI account credentials in app data and can write selected account auth back into `~/.codex/auth.json`. That duplicates sensitive auth material and fights the maintainer's existing workflow, where separate Codex homes already isolate account state.

The safer product should respect the existing manual setup:

- `~/.codex`
- `~/.codex-secondary`
- `~/.codex-free-1`
- `~/.codex-free-2`
- `~/.codex-free-3`

The app should reduce manual switching friction without weakening that separation.

## Goals

- Show known Codex profiles in the menu bar.
- Discover local profile health without reading or displaying secret token values.
- Edit provider/model config within a selected profile's own `config.toml`.
- Produce or run launch commands with `CODEX_HOME` set to the selected profile path.
- Preserve separate profile directories as the account boundary.
- Disable or de-emphasize the included compatibility proxy until a separate proxy hardening project is approved.

## Non-Goals

- Do not centralize all OpenAI account credentials into `~/.codex/model-switcher.json`.
- Do not copy `auth.json` between profiles by default.
- Do not route provider traffic through a third-party proxy.
- Do not enable the included local proxy as a default path.
- Do not redesign Codex itself or migrate session databases.

## User Experience

The first menu view should be a compact profile list. Each row represents one Codex home and shows:

- Profile label, such as `Primary`, `Secondary`, `Free 1`, `Free 2`, or `Free 3`.
- Path, shortened for scanability.
- Health indicators: `auth.json` present, `config.toml` present, selected model detected, and optional warning state.
- Quick actions: select, edit config, copy launch command, open folder.

Selecting a profile should not copy auth. It should set the app's active profile and make future edits target that profile. Launch actions should run Codex with `CODEX_HOME=<profile path>`.

Editing models/providers should use the existing menu bar feel, but the editor must make the target profile obvious. The app should write only that profile's `config.toml`.

## Architecture

Introduce a `CodexProfile` model:

```swift
struct CodexProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var path: String
    var isPinned: Bool
    var isActive: Bool
}
```

Introduce profile-aware path resolution:

```swift
struct CodexProfilePaths {
    var home: URL
    var config: URL
    var auth: URL
    var modelSwitcherData: URL
    var envFile: URL
}
```

`AppPaths` should stop assuming one fixed `~/.codex` target for all operations. Fixed app-level storage should live at `~/Library/Application Support/CodexModelSwitcher/profiles.json`. Profile-specific reads and writes should flow through `CodexProfilePaths`.

Recommended boundaries:

- `ProfileStore`: discovers, persists labels, and tracks active profile.
- `ProfileHealthScanner`: checks file presence and parses non-secret config summaries.
- `ProfileConfigWriter`: rewrites the selected profile's `config.toml`.
- `CodexLauncher`: launches Codex with `CODEX_HOME` set to the selected profile.
- `CompatibilityProxyServer`: not used in v1 default flows.

## Profile Discovery

On first run, scan for the known profiles:

- `~/.codex`
- `~/.codex-secondary`
- `~/.codex-free-1`
- `~/.codex-free-2`
- `~/.codex-free-3`

A directory qualifies as a Codex profile if it contains `auth.json`, `config.toml`, `sessions`, `history.jsonl`, or Codex state databases. It does not need all files to be shown.

The app should allow adding a custom profile path, but it should warn before creating a new profile directory.

## Config Handling

The app should parse enough TOML to find:

- top-level `model`
- top-level `model_provider`
- existing `[model_providers.*]` blocks

Provider/model edits should target only the active profile's `config.toml`. If the profile has no config, the app may create one after explicit user action.

Existing managed-provider markers can stay, but should be scoped per profile. The app should not delete unmanaged provider blocks unless they match the selected profile's own managed marker and provider ID.

## Launch Handling

The app should offer two launch options:

- Copy shell command: `CODEX_HOME="/path/to/profile" codex`
- Run Codex: launch the Codex executable with `CODEX_HOME` in the process environment.

V1 launch should use the user's home directory as the working directory. Launching from a chosen project folder is deferred until there is an explicit workspace picker.

## Credential Handling

V1 should avoid storing token contents in app data. It should inspect whether `auth.json` exists, but it should not parse or persist email/account metadata from token payloads in the first implementation. Profile labels should come from defaults or user-edited labels.

The existing `openAIAccounts` model should be treated as legacy. Migration should preserve existing app data but not expand that pattern.

## Proxy Posture

Proxy is off by default and not part of the profile-first v1.

Before any proxy feature is promoted, it needs a separate hardening design with:

- loopback-only binding
- per-session local auth token
- strict upstream host allowlist
- HTTPS-only upstreams unless explicitly allowed
- request size and concurrency limits
- no prompt, response, or API key logging
- focused tests for request and response translation

## Error Handling

Profile errors should be local and specific:

- Missing `auth.json`: show `Not logged in`.
- Missing `config.toml`: show `No config yet`.
- Unparseable config: show `Config needs manual review`.
- Launch failure: show the executable path and exit status without exposing secrets.
- Write failure: show the path and filesystem error.

The app should never print token contents in UI, logs, or error messages.

## Testing

Add focused unit tests for:

- profile discovery from temporary directories
- profile health detection
- profile-specific config rewrite
- launch environment construction with `CODEX_HOME`
- no auth JSON persistence in new profile storage
- proxy disabled by default

Manual verification should include:

- open app in menu bar
- confirm all five existing profiles appear
- switch active profile
- edit a model in one profile and confirm only that profile's config changes
- copy launch command and verify it uses the selected profile path
- run launch command and confirm Codex uses the selected home

## Migration Plan

1. Add profile models and discovery without removing existing provider UI.
2. Move config writer calls behind profile-aware paths.
3. Replace OpenAI account dropdown with profile dropdown.
4. Hide or mark the old account-auth management path as legacy.
5. Disable proxy by default in the UI and config generation.
6. Update README to explain profile-first usage.

## Review Criteria

The design is ready for implementation when:

- Profile directories are the account boundary.
- Auth JSON copying is not a default behavior.
- `CODEX_HOME` is the launch/switching mechanism.
- Proxy work is explicitly separated from v1.
- The app can preserve the maintainer's existing five-profile setup.
