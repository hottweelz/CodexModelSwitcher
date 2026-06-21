![Codex Model Switcher](/icon.png)

# Codex Model Switcher

A small macOS menu bar app for managing local Codex profiles and model provider configurations.

The app treats each Codex home directory as an account boundary. It can discover profiles such as `~/.codex`, `~/.codex-secondary`, `~/.codex-free-1`, `~/.codex-free-2`, and `~/.codex-free-3`, then edit the selected profile's `config.toml` or copy a launch command using `CODEX_HOME`.

![Screenshot](/screenshot.png)

## Features

- Discover and switch between local Codex profiles.
- Show profile health without displaying token contents.
- Add, edit, and delete custom model providers.
- Manage multiple models per provider.
- Write model/provider config to the selected profile only.
- Show provider key/proxy status without displaying key values.
- Copy a `CODEX_HOME='/path/to/profile' codex` launch command for any profile.
- Keep the app menu-bar only, without a Dock icon.

## Notes

Codex may need to be restarted after changing provider or model settings.

Each profile keeps its own `auth.json`, `config.toml`, sessions, memories, and local state. The app does not copy profile auth JSON by default.

API keys and OpenAI credentials are sensitive. Treat files under `~/.codex*` like secrets.

Provider settings are available from the gear button. If a provider key is not saved in the app, generated config uses the provider's `env_key` so Codex can still use an environment variable supplied outside the app.

## Development

The Debug target is configured to use Xcode's local `Sign to Run Locally` identity so contributors can build without a paid Apple Developer Program team. Release or distribution builds should be signed with the maintainer's own Apple developer settings.

## Proxy Status

The compatibility proxy is not part of the default profile-first flow. Treat proxy behavior as advanced/audited functionality only.

## License

MIT License.
