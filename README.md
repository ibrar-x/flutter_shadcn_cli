# flutter_shadcn_cli

This tool puts ready‑made Flutter widgets into your app.

Developer note: the CLI copies Dart files from the registry into your project, updates your pubspec when a widget needs extra packages, and saves your choices in .shadcn/config.json so you don’t have to repeat them.

## 1) Install the tool

```bash
dart pub global activate flutter_shadcn_cli
```

Make sure this folder is in your PATH:

```bash
$HOME/.pub-cache/bin
```

## 2) Start in your app

Run this inside your Flutter app folder:

```bash
flutter_shadcn init
```

You will be asked simple questions like:

- Where to put files (inside lib/)
- Which optional files to include

## 3) Add a widget

```bash
flutter_shadcn add button
```

Add more than one widget:

```bash
flutter_shadcn add command dialog
```

Add every widget:

```bash
flutter_shadcn add --all
```

## One‑line setup (fast)

Init and add in one command:

```bash
flutter_shadcn init --add button
```

Add multiple:

```bash
flutter_shadcn init --add button --add dialog
```

Add everything:

```bash
flutter_shadcn init --all
```

## Remove a widget

```bash
flutter_shadcn remove button
```

Force remove (even if other widgets depend on it):

```bash
flutter_shadcn remove button --force
```
# flutter_shadcn_cli

CLI installer for the shadcn_flutter registry. It copies Widgets and shared helpers into your Flutter app from either a local registry (development) or a remote registry (production).

## Highlights

- Local + remote registry support with auto‑fallback.
- Interactive init with install paths, optional files, and theme selection.
- Dependency‑aware installs with automatic pubspec updates.
- Optional class aliases and folder path aliases.
- Clean output with optional verbose mode.

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

You will be asked:

- Where to put files (inside lib/)
- Which optional files to include
- Optional alias prefix
- Theme preset

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

### 3) Remove Widgets

```bash
flutter_shadcn remove button
```

Force remove (even if others depend on it):

```bash
flutter_shadcn remove button --force
```

## One‑line setup (fast)

Init and add in one command:

```bash
flutter_shadcn init --add button
```

Add multiple:

```bash
flutter_shadcn init --add button --add dialog
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

## Commands

### init

```bash
flutter_shadcn init
```

### add

```bash
flutter_shadcn add button
```

### remove

```bash
flutter_shadcn remove button
```

### theme

```bash
flutter_shadcn theme --list
```

### doctor

```bash
flutter_shadcn doctor
```

## Folder Path Aliases

Set during init, for example:

```text
ui=lib/ui, hooks=lib/hooks
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

If Widgets are not found:

- Check your registry URL has registry/components.json.
- Make sure you are online for remote installs.

If aliases are missing:

- Set a class prefix during init.
- Run init again.

## New Updates

- One‑line setup with init --add/--all.
- Local dev mode saved with --dev.
- Optional file toggles (README.md, meta.json, preview.dart).
- Folder alias support with @alias paths.

## CLI Acknowledgements

This copy–paste CLI was built from the ground up to make it easy to browse, configure and install Widgets into your Flutter projects. While many of the widgets and design tokens in this kit are adapted from the excellent shadcn_flutter library (https://github.com/sunarya-thito/shadcn_flutter), the CLI itself is an original tool designed specifically for our registry/studio workflow. It does not reuse or derive code from the official shadcn/ui CLI or other third‑party CLIs.

You can see the refactored Widgets and documentation for this kit here:
https://github.com/ibrar-x/shadcn_flutter_kit/tree/main/flutter_shadcn_kit

Please refer to the upstream shadcn_flutter project for the canonical implementation and license details.
