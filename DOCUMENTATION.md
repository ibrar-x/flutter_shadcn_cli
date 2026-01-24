# CLI Documentation (flutter_shadcn_cli)

## Overview
`flutter_shadcn_cli` is a copy‑paste installer for the shadcn Flutter registry. It pulls components and shared helpers into a Flutter app, manages optional files, and keeps dependencies in sync.

## Key Concepts
- **Registry**: Source of components and shared helpers. Supports local (dev) and remote (CDN) registries.
- **Install Path**: Base path inside `lib/` where components/composites are placed.
- **Shared Path**: Base path inside `lib/` where shared helpers are placed.
- **Manifest**: `<installPath>/components.json` records installed components.
- **State**: `.shadcn/state.json` tracks managed dependencies and sync metadata.

## Architecture

### Core Modules
- `bin/shadcn.dart`
  - CLI entrypoint and command routing.
- `lib/src/installer.dart`
  - Installation/removal logic, dependency sync, file layout, theme application.
- `lib/src/registry.dart`
  - Registry models and loaders (local/remote).
- `lib/src/config.dart`
  - `.shadcn/config.json` persistence.
- `lib/src/state.dart`
  - `.shadcn/state.json` persistence.
- `lib/src/theme_css.dart`
  - Applies preset colors to `color_scheme.dart`.

### Flow Summary
1. Load config (or prompt during init).
2. Load registry (local or remote).
3. Install/remove components and shared helpers.
4. Update manifest and state.
5. Sync dependencies via `dart pub add/remove`.

## Commands

### init
- Prompts for install/shared paths, optional files, prefix, and theme preset.
- Installs core shared helpers and required dependencies.

### add
- Adds one or more components.
- Resolves dependencies and installs shared helpers.

### remove
- Removes one or more components.
- `--all` removes everything including shared helpers, config, and empty folders.

### theme
- Lists presets or applies a preset to `color_scheme.dart`.
- Experimental: apply themes from a JSON file or URL.

### sync
- Applies config changes (paths/theme) to existing files.

### doctor
- Troubleshooting diagnostics.

## Dependency Management
- Required dependencies are aggregated from registry metadata.
- Adds/removes are batched for speed:
  - `dart pub add dep1 dep2 ...`
  - `dart pub remove dep1 dep2 ...`
- Managed dependencies are stored in `.shadcn/state.json`.

## File Layout
```
lib/
  <installPath>/
    components/
    composites/
    components.json
  <sharedPath>/
    theme/
    util/
    ...
.shadcn/
  config.json
  state.json
```

## Theme Presets
- Presets live in the registry under shared theme data.
- `theme_css.dart` rewrites `color_scheme.dart` with preset colors.

### Custom Themes (Experimental)
You can apply a custom theme JSON file or URL using the experimental flag:

```
flutter_shadcn --experimental theme --apply-file /path/to/theme.json
flutter_shadcn --experimental theme --apply-url https://example.com/theme.json
```

Expected JSON shape:
```
{
  "id": "custom",
  "name": "Custom",
  "light": { "background": "#FFFFFF" },
  "dark": { "background": "#000000" }
}
```

## Feature Flags
- `--wip`: Enable WIP features.
- `--experimental`: Enable experimental features (required for theme file/url).

## Development Workflow
1. Update registry or CLI logic.
2. Run `make cli-reset` from repo root.
3. Test using a sample Flutter app (e.g. docs app).
4. Validate `flutter analyze` results after installing.

## Common Tasks
- **Add a new flag**: update `bin/shadcn.dart`, wire behavior in `installer.dart`.
- **Add new registry metadata**: update `registry/components.json` and loaders.
- **Adjust dependency logic**: update `_syncDependenciesWithInstalled`.

## Known Constraints
- Install/shared paths must be inside `lib/`.
- Theme application assumes `color_scheme.dart` matches expected structure.
