CLI installer for the shadcn_flutter registry. It copies Widgets and shared helpers into your Flutter app from either a local registry (development) or a remote registry (production).

## Highlights

- Local + remote registry support with auto‑fallback.
- Interactive init with install paths, optional files, and theme selection.
- Dependency‑aware installs with batched pubspec updates.
- Optional class aliases and folder path aliases.
- Clean output with optional verbose mode.
- Tracks installed Widgets in a local components.json.
- Full cleanup on remove --all (components, composites, shared, config, empty folders).

## Install (pub.dev)

```bash
dart pub global activate flutter_shadcn_cli
```

Make sure this folder is in your PATH:

```bash
$HOME/.pub-cache/bin
```

## Quick Start

### 1) Initialize in a Flutter app

```bash
flutter_shadcn init
```

Skip questions and use defaults:

```bash
flutter_shadcn init --yes
```

Install typography + icon font assets during init:

```bash
flutter_shadcn init --install-fonts --install-icons
```

You will be asked:

- Component install path inside lib/ (e.g. lib/ui/shadcn or lib/pages/docs)
- Shared files path inside lib/ (e.g. lib/ui/shadcn/shared)
- Which optional files to include
- Optional class prefix for widget names
- Theme preset

Init also installs core shared helpers (theme, util, color_extensions, form_control, form_value_supplier) and adds required packages (data_widget, gap).

Skip questions and set everything in one command:

```bash
flutter_shadcn init --yes \
	--install-path ui/shadcn \
	--shared-path ui/shadcn/shared \
	--include-meta \
	--include-readme=false \
	--include-preview=false \
	--prefix App \
	--theme new-york \
	--alias ui=ui
```

### 2) Add Widgets

```bash
flutter_shadcn add button
```

Add more than one:

```bash
flutter_shadcn add command dialog
```

Add everything:

```bash
flutter_shadcn add --all
```

Add assets only:

```bash
flutter_shadcn assets --all
```

### 3) Remove Widgets

```bash
flutter_shadcn remove button
```

Force remove (even if others depend on it):

```bash
flutter_shadcn remove button --force
```

Remove everything:

```bash
flutter_shadcn remove --all
```

## One‑line setup (fast)

Init and add in one command:

```bash
flutter_shadcn init --add button dialog
```

Add everything:

```bash
flutter_shadcn init --all
```

## Registry Modes (Local vs Remote)

### Default (auto)

- Uses local registry if found, otherwise falls back to remote.

### Local registry (development)

```bash
flutter_shadcn add button --registry local --registry-path /absolute/path/to/registry
```

Persist dev mode once (recommended):

```bash
flutter_shadcn --dev --dev-path /absolute/path/to/registry init
```

### Remote registry (consumer install)

```bash
flutter_shadcn add button --registry remote
```

Use a custom CDN URL:

```bash
flutter_shadcn add button --registry remote --registry-url https://cdn.jsdelivr.net/gh/ibrar-x/shadcn_flutter_kit@latest/flutter_shadcn_kit/lib
```

Default remote base URL (jsdelivr CDN):

```text
https://cdn.jsdelivr.net/gh/ibrar-x/shadcn_flutter_kit@latest/flutter_shadcn_kit/lib
```

## Config (.shadcn/config.json)

Saved choices per project:

- installPath (default lib/ui/shadcn)
- sharedPath (default lib/ui/shadcn/shared)
- includeReadme (optional)
- includeMeta (recommended)
- includePreview (optional)
- classPrefix (optional aliases)
- pathAliases (optional @alias paths)
- registryMode, registryPath, registryUrl

The CLI also writes a local manifest at `<installPath>/components.json` with
the list of installed Widgets.

## Commands

### init

```bash
flutter_shadcn init
```

Use defaults (no questions):

```bash
flutter_shadcn init --yes
```

Install fonts + icons during init:

```bash
flutter_shadcn init --install-fonts --install-icons
```

Set all values in one command:

```bash
flutter_shadcn init --yes \
	--install-path ui/shadcn \
	--shared-path ui/shadcn/shared \
	--include-meta \
	--include-readme=false \
	--include-preview=false \
	--prefix App \
	--theme new-york \
	--alias ui=ui
```

### add

```bash
flutter_shadcn add button
```

### assets

```bash
flutter_shadcn assets --list
```

```bash
flutter_shadcn assets --icons
```

```bash
flutter_shadcn assets --fonts
```

```bash
flutter_shadcn assets --all
```

### platform

```bash
flutter_shadcn platform --list
```

```bash
flutter_shadcn platform --set ios.infoPlist=ios/Runner/Info.plist \
	--set android.gradle=android/app/build.gradle
```

```bash
flutter_shadcn platform --reset ios.infoPlist
```

### remove

```bash
flutter_shadcn remove button
```

```bash
flutter_shadcn remove --all
```

### theme

```bash
flutter_shadcn theme --list
```

Apply a custom theme JSON file (experimental):

```bash
flutter_shadcn --experimental theme --apply-file /path/to/theme.json
```

Example JSON structure:

- [theme_example.json](theme_example.json)

```json
{
	"id": "custom",
	"name": "Custom Theme",
	"light": {
		"background": "#FFFFFF",
		"foreground": "#09090B",
		"primary": "#1447E6",
		"primaryForeground": "#EFF6FF"
	},
	"dark": {
		"background": "#09090B",
		"foreground": "#FAFAFA",
		"primary": "#2B7FFF",
		"primaryForeground": "#EFF6FF"
	}
}
```

Apply a custom theme JSON URL (experimental):

```bash
flutter_shadcn --experimental theme --apply-url https://example.com/theme.json
```

### sync

```bash
flutter_shadcn sync
```

Use `sync` after editing .shadcn/config.json to move paths and re-apply the theme.

### doctor

```bash
flutter_shadcn doctor
```

Doctor also reports resolved platform targets (defaults + overrides).

## Folder Path Aliases

Set during init, for example:

```text
ui=ui
```

Use them like:

```text
@ui/shadcn
```

## Optional Files

- meta.json is strongly recommended for audits and validation.
- README.md and preview.dart are optional and skipped by default.

## Verbose Output

```bash
flutter_shadcn add button --verbose
```

## Troubleshooting

```bash
flutter_shadcn doctor
```

### If a new flag is "not found"

Sometimes the global executable uses an old cached snapshot. Fix it like this:

```bash
# Step 1: remove the global cache (this is safe)
# The * is a wildcard that matches any folder name.
rm -f ~/.pub-cache/hosted/*/bin/cache/flutter_shadcn_cli/* || true

# Step 2: if you ran the CLI from a project folder, delete the local snapshot
# (run this in your project root where .dart_tool/ exists)
rm -f .dart_tool/pub/bin/flutter_shadcn_cli/*.snapshot || true

# Step 3: confirm the flag exists
flutter_shadcn --help
```

If that doesn’t work, re‑activate the CLI:

```bash
dart pub global deactivate flutter_shadcn_cli
dart pub global activate flutter_shadcn_cli
```

If Widgets are not found:

- Check your registry URL has registry/components.json.
- Make sure you are online for remote installs.

If aliases are missing:

- Set a class prefix during init.
- Run init again.

## Feature Flags

- `--wip`: Enables WIP features.
- `--experimental`: Enables experimental features (required for theme file/url).

## New Updates

- One‑line setup with init --add/--all.
- Local dev mode saved with --dev.
- Optional file toggles (README.md, meta.json, preview.dart).
- Folder alias support with @alias paths.
- Init installs core shared helpers + required deps by default.
- `assets` command for installing icon/typography fonts.
- Init flags for installing icons/fonts on demand.
- Dependency updates are batched for faster installs/removals.
- remove --all cleans empty parent folders after deleting files.
- Platform targets can be configured via the platform command.

## CLI Acknowledgements

This copy–paste CLI was built from the ground up to make it easy to browse, configure and install Widgets into your Flutter projects. While many of the widgets and design tokens in this kit are adapted from the excellent shadcn_flutter library (https://github.com/sunarya-thito/shadcn_flutter), the CLI itself is an original tool designed specifically for our registry/studio workflow. It does not reuse or derive code from the official shadcn/ui CLI or other third‑party CLIs.

You can see the refactored Widgets and documentation for this kit here:
https://github.com/ibrar-x/shadcn_flutter_kit/tree/main/flutter_shadcn_kit

Please refer to the upstream shadcn_flutter project for the canonical implementation and license details.
