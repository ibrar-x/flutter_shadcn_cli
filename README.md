# flutter_shadcn_cli

A CLI to install and sync shadcn/ui components into your Flutter app. Part of the
**shadcn_flutter_kit** ecosystem.

[![GitHub Repo](https://img.shields.io/badge/GitHub-shadcn_flutter_kit-black?style=for-the-badge&logo=github)](https://github.com/ibrar-x/shadcn_flutter_kit)
[![Docs](https://img.shields.io/badge/Docs-Widget%20Catalog-blue?style=for-the-badge&logo=google-chrome&logoColor=white)](https://ibrar-x.github.io/shadcn_flutter_kit/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](https://github.com/ibrar-x/shadcn_flutter_kit/blob/main/LICENSE)
[![Stars](https://img.shields.io/github/stars/ibrar-x/shadcn_flutter_kit?style=for-the-badge&logo=github)](https://github.com/ibrar-x/shadcn_flutter_kit/stargazers)

---

CLI installer for the shadcn_flutter registry. It copies Widgets and shared helpers into your Flutter app from either a local registry (development) or a remote registry (production).

## Highlights

- Local + remote registry support with auto‑fallback.
- Interactive init with install paths, optional files, and theme selection.
- Dependency‑aware installs with batched pubspec updates.
- Optional class aliases and folder path aliases.
- Clean output with optional verbose mode.
- Tracks installed Widgets in a local components.json.
- Full cleanup on remove --all (components, composites, shared, config, empty folders).
- **Component discovery**: list, search, and info commands with intelligent caching.
- **Dry-run preview**: See dependencies, assets, and platform changes before install.
- **AI skill manager**: Interactive multi-skill installation with auto-discovery of 28+ AI model folders (.claude, .cursor, .gemini, etc.).
  - Human-readable model names (\"Cursor\", \"Claude (Anthropic)\", \"Codex (OpenAI)\")
  - Install multiple skills to multiple models in one flow
  - Intelligent duplicate detection (skip/overwrite/cancel installed skills)
  - Context-aware installation modes: copy or symlink for efficiency
  - Interactive removal with batch uninstall support
- **Smart symlink management**: Share skills across multiple AI models without duplicating files.
  - Auto-detects existing installations and offers symlink as option
  - Safe removal that unlocks symlinks without deleting source files
  - Batch operations with graceful error handling
- **Schema validation**: Doctor validates components.json against components.schema.json.
- **Version management**: Automatic update notifications (once per day) plus manual check and upgrade commands.
- **Integrated feedback system**: Submit bugs, feature requests, or questions directly via GitHub.
  - Interactive menu with 6 feedback types (bug, feature, docs, question, performance, other)
  - Type-specific templates with relevant questions
  - Auto-includes environment details (CLI version, OS, Dart SDK)
  - Non-interactive mode for one-command submissions
  - GitHub CLI integration (creates issues directly without browser if `gh` is installed)
  - Automatic fallback to browser if GitHub CLI is unavailable

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
	--theme modern-minimal \
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
flutter_shadcn init button dialog
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
the list of installed Widgets and component metadata (version/tags). It also
tracks per-component install manifests under `.shadcn/components/<id>.json`
for auditing and upgrade workflows.

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
	--theme modern-minimal \
	--alias ui=ui
```

### add

```bash
flutter_shadcn add button
```

### dry-run

Preview everything that will be installed (dependencies, shared, assets, fonts, platform changes):

```bash
flutter_shadcn dry-run button
```

Preview all components:

```bash
flutter_shadcn dry-run --all
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

Doctor also reports resolved platform targets (defaults + overrides), the
components.json cache location, and schema validation status.

### list

Browse and list all available components from the registry:

Uses local registry when available; falls back to remote.

```bash
flutter_shadcn list
```

Refresh cache from remote:

```bash
flutter_shadcn list --refresh
```

### search

Search for components by name, description, tags, or keywords:

```bash
flutter_shadcn search button
```

Search results are ranked by relevance:

```bash
flutter_shadcn search "form input"
```

Refresh cache:

```bash
flutter_shadcn search button --refresh
```

### info

Get detailed information about a specific component:

```bash
flutter_shadcn info button
```

Shows:
- Component description and tags
- API (constructors, callbacks, properties)
- Usage examples
- Dependencies
- Related components

Refresh cache:

```bash
flutter_shadcn info button --refresh
```

### install-skill

Manage AI skills for model-specific installations. Discovers hidden AI model folders (`.claude`, `.gpt4`, `.cursor`, etc.) in your project root.

**Interactive mode** — enter skill ID and choose models:

```bash
flutter_shadcn install-skill
```

**Install to specific model:**

```bash
flutter_shadcn install-skill --skill my-skill --model .claude
```

**Override skills URL/path:**

```bash
flutter_shadcn install-skill --skill my-skill --skills-url /path/to/skills
```

**Interactive model selection:**

```bash
flutter_shadcn install-skill --skill my-skill
```

**List installed skills by model:**

```bash
flutter_shadcn install-skill --list
```

**Uninstall from specific model:**

```bash
flutter_shadcn install-skill --uninstall my-skill --model .claude
```

**Installation modes:**
- Copy skill to each model independently
- Install to first model + create symlinks to others
- Selective symlink creation

### version

Display the current CLI version or check for updates.

**Show current version:**

```bash
flutter_shadcn version
```

**Check for available updates:**

```bash
flutter_shadcn version --check
```

### upgrade

Upgrade the CLI to the latest version from pub.dev.

**Upgrade to latest version:**

```bash
flutter_shadcn upgrade
```

**Force upgrade (even if already on latest):**

```bash
flutter_shadcn upgrade --force
```

The upgrade command will:
- Check pub.dev for the latest version
- Download and install the new version
- Confirm successful upgrade
- Provide manual upgrade steps if automatic upgrade fails

**Automatic Update Notifications:**
The CLI automatically checks for updates once per 24 hours on every command execution (except `version` and `upgrade`). If a newer version is available, you'll see:

```
┌─────────────────────────────────────────────────────────┐
│ A new version of flutter_shadcn_cli is available!      │
│ Current: 0.1.8 → Latest: 0.1.9                          │
│ Run: flutter_shadcn upgrade                             │
└─────────────────────────────────────────────────────────┘
```

**Disable automatic checks:**
Edit `.shadcn/config.json` and set:
```json
{
  "checkUpdates": false
}
```

### feedback

Submit feedback, report bugs, or request features via GitHub:

```bash
flutter_shadcn feedback
```

The feedback command provides an interactive menu with the following options:

- 🐛 **Report a bug** - Issues with components, installation, or CLI behavior
- ✨ **Request a feature** - Ideas for new components or enhancements
- 📖 **Documentation** - Suggestions for documentation improvements
- ❓ **Ask a question** - Questions about usage or configuration
- ⚡ **Performance issue** - Slow builds, runtime performance problems
- 💡 **Other feedback** - General suggestions and ideas

The command will:
1. Show an interactive menu of feedback types
2. Collect your feedback details (title and description)
3. **If GitHub CLI (`gh`) is installed**: Create issue directly in terminal
4. **Otherwise**: Open GitHub with a pre-filled issue template in browser
5. Auto-include CLI version, OS, and Dart version

**GitHub CLI Integration:**
If you have [GitHub CLI](https://cli.github.com/) installed and authenticated (`gh auth login`), issues are created instantly without leaving the terminal. Otherwise, the command falls back to opening your browser.

**Non-interactive mode:**
```bash
flutter_shadcn feedback --type bug --title "Init fails on Windows" --body "Describe the issue"
```

Valid types: `bug`, `feature`, `docs`, `question`, `performance`, `other`

All feedback goes to the [shadcn_flutter_kit](https://github.com/ibrar-x/shadcn_flutter_kit) repository and helps improve the toolkit for everyone!

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

- Component discovery system: `list`, `search`, `info` commands for browsing registry.
- Intelligent index.json caching with 24-hour staleness policy.
- Local index.json support with remote fallback.
- Dry-run preview for dependencies, assets, and platform changes.
- Interactive AI skill manager with model folder auto-discovery.
- Symlink support for sharing skills across multiple AI models.
- Skills URL override with `--skills-url`.
- Doctor validates components.json schema and reports cache location.
- One‑line setup with init `<components>` or `--all`.
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
