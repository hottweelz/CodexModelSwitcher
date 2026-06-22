![Codex Model Switcher](/icon.png)

# Codex Model Switcher

A local-first macOS menu bar app for switching between Codex home profiles and editing model/provider configuration without copying account credentials between profiles.

The app treats each Codex home directory as an account boundary. It discovers profiles such as `~/.codex`, `~/.codex-secondary`, `~/.codex-free-1`, `~/.codex-free-2`, and `~/.codex-free-3`, then lets you choose which profile is the target for model/provider config writes.

![Screenshot](/screenshot.png)

## Current Posture

- Profile-first v1: choose a target `CODEX_HOME`, then update that profile's `config.toml`.
- No auth copying by default: each profile keeps its own `auth.json`, `config.toml`, sessions, memories, and local state.
- Provider keys are treated as secrets: the UI shows key presence, not key values.
- Proxy is Day 2 work: the local compatibility proxy exists in source, but it is advanced/off by default and should not be part of the default v1 workflow.

## Features

- Discover known local Codex profiles.
- Show profile health without displaying token contents.
- Select a target profile before writing model/provider config.
- Add, edit, and delete custom model providers.
- Manage multiple models per provider.
- Write model/provider config to the selected profile only.
- Show provider key/proxy status without displaying key values.
- Copy a `CODEX_HOME='/path/to/profile' codex` launch command for any profile.
- Keep the app menu-bar only, without a Dock icon.

## Quick Start

### Build And Run

Open the Xcode project:

```sh
open CodexModelSwitcher.xcodeproj
```

Build and run the `CodexModelSwitcher` scheme. The Debug target uses Xcode's local `Sign to Run Locally` identity, so a paid Apple Developer Program team is not required for local development.

Command-line build:

```sh
xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build
```

The built app is menu-bar-only. It will not show a Dock icon.

### Install On Macs Without Xcode

Build a local package on a Mac that has Xcode installed:

```sh
./script/package_local.sh
```

This creates:

```txt
dist/CodexModelSwitcher-local-macos.zip
dist/CodexModelSwitcher-local-macos.zip.sha256
```

Copy the zip to another Mac. That Mac does not need Xcode or the source checkout.

On the other Mac:

```sh
unzip CodexModelSwitcher-local-macos.zip
cd CodexModelSwitcher-local
./install.sh
```

The installer copies `CodexModelSwitcher.app` into `/Applications`, clears quarantine metadata when possible, stops any running copy, and launches the menu bar app.

This package is meant for private installs on your own Macs. It is locally/ad-hoc signed, not notarized for public distribution. If macOS blocks a transferred copy, run the included `install.sh` first; public distribution can be handled later with Developer ID signing and notarization.

The current project targets macOS 15.3 or newer.

### Use Profiles Safely

1. Click the Codex Model Switcher menu bar icon.
2. Select a profile row such as `Primary`, `Secondary`, or `Free 1`.
3. Treat the selected row as the target profile. Selecting a profile only changes app state.
4. Choose a model only when you are ready to update that selected profile's `config.toml`.
5. Restart or launch Codex with that profile for changes to take effect.

Copying a launch command is the safest test path:

```sh
CODEX_HOME='/Users/you/.codex-free-1' codex
```

The copied command starts Codex with that profile as `CODEX_HOME`; it does not move credentials between profiles.

## Provider Settings

Use the gear button to edit the selected provider. Provider rows also expose a gear for settings.

For providers such as OpenRouter:

- If no key is saved in the app, generated config uses the provider's `env_key`, for example `OPENROUTER_API_KEY`.
- If a key is saved in the app, the app can write managed provider config and key material into the selected profile's local config/env surfaces when applying a model selection.
- The menu shows `No API key` or `API key saved`, but never displays the key value.

Keep provider keys and files under `~/.codex*` private.

## What Gets Written

App data:

```txt
~/Library/Application Support/CodexModelSwitcher/app-data.json
```

Selected profile files:

```txt
~/.codex*/config.toml
~/.codex*/model-switcher.env
```

Legacy app data may still be read from:

```txt
~/.codex/model-switcher.json
```

The app does not copy profile `auth.json` files by default.

## Proxy Status

The compatibility proxy is local Swift code in `CodexModelSwitcher/CompatibilityProxyServer.swift`. It binds to:

```txt
127.0.0.1:48117
```

It only starts when a non-OpenAI provider has `Local compatibility proxy` enabled. Leave this off for the v1 profile-first workflow.

Proxy hardening, auth gates, request limits, and proxy-first workflows are Day 2 work. Do not rely on proxy behavior as the default trust path yet.

## Development Checks

Run the profile core test runner:

```sh
swift run ProfileCoreTestRunner
```

Typecheck app and profile core Swift files:

```sh
swiftc -typecheck CodexModelSwitcher/*.swift CodexModelSwitcher/ProfileCore/*.swift
```

Build the macOS app:

```sh
xcodebuild -project CodexModelSwitcher.xcodeproj -scheme CodexModelSwitcher -configuration Debug build
```

## Contributor Notes

- Keep v1 profile-first.
- Do not make proxy behavior default.
- Do not print or log API keys, `auth.json`, refresh tokens, or access tokens.
- Update `CHANGELOG_AI.md` after AI-assisted work.
- Update `MEMORY.md` only for durable facts, decisions, constraints, or maintainer preferences.

## License

MIT License.
