# flutter_shadcn_cli

CLI installer for the shadcn_flutter registry. It copies components and shared primitives into your Flutter app from either a local registry (development) or a remote registry (production).

## Highlights

- Local + remote registry support with auto-fallback.
- Interactive init with install paths, optional files, and theme selection.
- Dependency-aware installs with automatic pubspec updates.
- Optional class aliases and folder path aliases.
- Clean output with optional verbose mode.

## Install (pub.dev)

- `dart pub global activate flutter_shadcn_cli`
- Ensure `$HOME/.pub-cache/bin` is on your PATH.

## Quick Start

### Initialize in a Flutter app
- `flutter_shadcn init`
  - Installs core shared assets (`theme`, `util`).
  - Prompts for install directory and shared directory (must be under `lib/`).
  - Prompts for optional files (`README.md`, `meta.json`, `preview.dart`).
  - Prompts for optional class prefix (leave blank to skip aliases).
  - Prompts to select a starter theme.

### Add components
- `flutter_shadcn add button`
- `flutter_shadcn add command dialog`
- `flutter_shadcn add --all`

### Remove components
- `flutter_shadcn remove button`
- `flutter_shadcn remove button --force`

## Registry Modes (Local vs Remote)

The CLI resolves the registry in this order:

### Default (auto)
- `--registry auto` (default)
- Uses local registry if found, otherwise falls back to remote.

### Local registry (development)
Use this when developing against a local copy of the registry.

- `--registry local`
- `--registry-path /absolute/path/to/registry`
- Environment override: `SHADCN_REGISTRY_ROOT=/absolute/path/to/registry`

Persist dev mode once (recommended):
- `flutter_shadcn --dev --dev-path /absolute/path/to/registry init`

This saves the local registry path to `.shadcn/config.json` so future commands
use local mode by default without extra flags.

The CLI searches for `registry/components.json` in:
1. `--registry-path`
2. `SHADCN_REGISTRY_ROOT`
3. The global package registry (if installed globally)
4. The CLI package’s own registry
5. Parent folders of the CLI script
6. Parent folders of the current working directory

### Remote registry (consumer install)
Use this for end users who install from the hosted registry.

- `--registry remote`
- `--registry-url https://cdn.jsdelivr.net/gh/sunarya-thito/shadcn_flutter@latest/shadcn_flutter_kit/flutter_shadcn_kit/lib`
- Environment override: `SHADCN_REGISTRY_URL=...`

**Default remote base URL (jsdelivr CDN):**

`https://cdn.jsdelivr.net/gh/sunarya-thito/shadcn_flutter@latest/shadcn_flutter_kit/flutter_shadcn_kit/lib`

The CLI expects `registry/components.json` under the base URL. If you point the base to a root containing `registry/`, it will automatically resolve `.../registry` for the registry index and use the base for file downloads.

## Config (.shadcn/config.json)

The CLI stores user preferences per project:

- `installPath` (default `lib/ui/shadcn`)
- `sharedPath` (default `lib/ui/shadcn/shared`)
- `includeReadme` (optional)
- `includeMeta` (recommended)
- `includePreview` (optional)
- `classPrefix` (optional aliases)
- `pathAliases` (optional `@alias` paths)
- `registryMode`, `registryPath`, `registryUrl` (if set via `--dev` or overrides)

You can edit `.shadcn/config.json` directly if needed.

## Commands

### `init`
Initializes the shadcn_flutter structure in the current project.

- Installs shared `theme` and `util`.
- Prompts for install directory and shared directory.
- Prompts for optional files (`README.md`, `meta.json`, `preview.dart`).
- Creates `.shadcn/config.json`.
- Prompts for optional alias prefix.
- Prompts for theme selection.

### `add`
Installs one or more components plus their dependencies.

- `flutter_shadcn add button`
- `flutter_shadcn add command dialog`
- `flutter_shadcn add --all`

Behavior:
- Installs component dependencies first.
- Installs required shared bundles.
- Writes component files into your install path.
- Adds missing `pubspec.yaml` dependencies automatically.
- Generates aliases (if a prefix is configured).

### `remove`
Removes a component and its files.

- `flutter_shadcn remove button`
- `flutter_shadcn remove button --force`

Behavior:
- Blocks removal if other installed components depend on it (unless `--force`).
- Regenerates aliases after removal.

### `theme`
Manages registry theme presets.

- `flutter_shadcn theme --list`
- `flutter_shadcn theme --apply <preset-id>`
- `flutter_shadcn theme` (interactive)

### `doctor`
Prints registry resolution diagnostics.

- `flutter_shadcn doctor`

## Aliases (Optional)

The CLI can generate a single export file that aliases registry classes with a prefix (e.g., `AppButton`).

- During `init`, you will be prompted for a class prefix.
- Leave blank to skip alias generation.
- The alias file is generated at:
  - `lib/ui/shadcn/app_components.dart`

## Folder Path Aliases

During init you can set folder aliases (e.g. `ui=lib/ui, hooks=lib/hooks`).

Use them in paths with `@alias`, for example:

- `@ui/shadcn`

Aliases must resolve inside `lib/`.

## Install Paths

The registry defaults are read from `components.json`:
- `defaults.installPath` (typically `lib/ui/shadcn`)
- `defaults.sharedPath` (typically `lib/ui/shadcn/shared`)

All files are installed relative to these defaults.

## Dependency Handling

When a component declares `pubspec.dependencies`:
- The CLI reads `pubspec.yaml`.
- Adds only missing dependencies.
- Skips any dependency already present.

If `pubspec.yaml` is missing, it will skip dependency updates and print a warning.

## Verbose Output

Use `--verbose` to see detailed file operations.

- `flutter_shadcn add button --verbose`

## Examples

### Local development
- `flutter_shadcn add button --registry local --registry-path /path/to/shadcn_flutter/registry`

### Persist local dev mode
- `flutter_shadcn --dev --dev-path /path/to/shadcn_flutter/registry init`
- `flutter_shadcn add button` (uses local registry automatically)

### Remote consumer install
- `flutter_shadcn add button --registry remote`

### Remote using a custom CDN URL
- `flutter_shadcn add button --registry remote --registry-url https://cdn.jsdelivr.net/gh/your-org/your-repo@latest/path/to/lib`

## Recommended Optional Files

- `meta.json` is strongly recommended for validation, audits, and CI checks against `components.json`.
- `README.md` and `preview.dart` are optional and excluded by default.

## Environment Variables

- `SHADCN_REGISTRY_ROOT` — local registry path
- `SHADCN_REGISTRY_URL` — remote registry base URL

## Troubleshooting

- Run `flutter_shadcn doctor` to confirm registry resolution.
- If components are not found:
  - Check your registry base URL contains `registry/components.json`.
  - Ensure network access when using remote mode.
- If aliases are missing:
  - Ensure you set a class prefix during `init`.
  - Re-run `flutter_shadcn init` or edit `.shadcn/config.json`.

## Publishing

- Update this README for GitHub and pub.dev before release.
- Ensure the default remote registry URL is correct.
- Run tests before publishing.
