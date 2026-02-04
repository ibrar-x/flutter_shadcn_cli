# Flutter Shadcn CLI - Complete Commands Documentation

This document provides comprehensive documentation for every command in `flutter_shadcn_cli`, including what each command does, which files it uses, and why.

---

## Table of Contents

1. [init](#init)
2. [add](#add)
3. [remove](#remove)
4. [dry-run](#dry-run)
5. [assets](#assets)
6. [platform](#platform)
7. [theme](#theme)
8. [sync](#sync)
9. [doctor](#doctor)
10. [list](#list)
11. [search](#search)
12. [info](#info)
13. [install-skill](#install-skill)
14. [version](#version)
15. [upgrade](#upgrade)

---

## init

### What it does
Initializes a Flutter project to use the shadcn component registry. This is the first command you run and sets up the necessary folder structure, configuration, shared files, and core dependencies.

**Key responsibilities:**
- Prompts for component install path (e.g., `lib/ui/shadcn`)
- Prompts for shared files path (e.g., `lib/ui/shadcn/shared`)
- Optionally includes meta.json, README.md, and preview.dart files
- Prompts for optional class prefix for widget names
- Prompts for theme selection from available presets
- Creates `.shadcn/config.json` configuration file
- Installs core shared helpers (theme, util, color_extensions, form_control, form_value_supplier)
- Adds required dependencies (data_widget, gap) to pubspec.yaml
- Optionally installs typography and icon fonts

**Usage:**
```bash
# Interactive mode (asks questions)
flutter_shadcn init

# Skip all questions, use defaults
flutter_shadcn init --yes

# Set all values in one command
flutter_shadcn init --yes \
  --install-path ui/shadcn \
  --shared-path ui/shadcn/shared \
  --include-meta \
  --include-readme=false \
  --include-preview=false \
  --prefix App \
  --theme modern-minimal

# Install fonts and icons during init
flutter_shadcn init --install-fonts --install-icons

# One-line setup: init + add components
flutter_shadcn init --add button dialog
flutter_shadcn init --all
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Project configuration | Stores install paths, shared paths, theme selection, registry mode, class prefix, and path aliases for future commands |
| `pubspec.yaml` | Flutter project manifest | Adds required dependencies (data_widget, gap) and any optional icon/font packages |
| `<installPath>/components.json` | Local component manifest | Tracks which components are installed and their versions for audits and removals |
| `<sharedPath>/theme/color_scheme.dart` | Theme implementation | Applies the selected theme preset to the project's color system |
| `<sharedPath>/theme/preset_theme_data.dart` | Theme data bundle | Source of all 42 built-in theme presets (modern-minimal, cosmic-night, etc.) |
| `<installPath>/_example/` | Example widget showcase | Optionally created to show component usage examples |
| Various shared files | Core helpers | Copied from registry into `<sharedPath>/` (tokens, utils, primitives, form helpers) |

### Why These Files

- **`.shadcn/config.json`**: Persists user choices so subsequent commands (add, remove, sync, doctor) can auto-detect project settings without re-prompting.
- **`pubspec.yaml`**: Must declare all dependencies so Flutter can resolve them during build.
- **`<installPath>/components.json`**: Acts as a manifest for tracking what's installed, enabling smart removal and dependency checking.
- **`<sharedPath>/color_scheme.dart`**: Bridges theme presets to Material Design color system so all widgets inherit the selected theme.
- **Theme bundle files**: Pre-compiled theme data speeds up theme switching without needing to parse theme configs.
- **Shared files**: Prevents duplication—all components reference these common utilities and primitives.

---

## add

### What it does
Installs one or more shadcn components into the Flutter project. Handles dependency resolution, file copying, pubspec updates, and post-install steps.

**Key responsibilities:**
- Resolves component dependencies (e.g., menu → popover → overlay)
- Copies component files to the install path
- Copies any missing shared files
- Updates pubspec.yaml with required packages
- Records installed components in the local manifest
- Runs post-install platform-specific steps if defined
- Displays installation summary with counts and file changes

**Usage:**
```bash
# Add a single component
flutter_shadcn add button

# Add multiple components
flutter_shadcn add button dialog form

# Add everything at once
flutter_shadcn add --all

# Force add (ignore dependency errors)
flutter_shadcn force-add button

# Use local registry for development
flutter_shadcn add button --registry local --registry-path /path/to/registry

# Use remote registry with custom URL
flutter_shadcn add button --registry remote --registry-url https://custom-cdn.com

# Show verbose output
flutter_shadcn add button --verbose
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Project settings | Reads install path, shared path, class prefix, and registry configuration |
| `registry/components.json` or remote equivalent | Component index | Lists all available components, their files, dependencies, and shared requirements |
| `registry/components/<name>/` | Component source | Copies component.dart, component_impl.dart, and other component files |
| `registry/shared/` | Shared helpers source | Copies tokens, utils, primitives, form helpers referenced by component |
| `<installPath>/components.json` | Installed component tracking | Updates manifest with newly installed component and version info |
| `pubspec.yaml` | Project dependencies | Adds/updates package versions required by the component |
| `<installPath>/<name>/` | Component destination | Copies component files into project maintaining folder structure |
| `<sharedPath>/` | Shared destination | Copies any missing shared files alongside component installation |
| `components.schema.json` | Schema validation | Validates component structure during installation (used if validation is enabled) |

### Why These Files

- **`.shadcn/config.json`**: Provides project context (paths, registry mode) without re-prompting user.
- **`registry/components.json`**: Single source of truth for what components exist and their dependencies.
- **Component source files**: The actual widget code to be copied; structure must match to ensure proper imports.
- **Shared files**: Prevent code duplication and ensure consistent primitives across all components.
- **`<installPath>/components.json`**: Enables `remove` command to know what's installed; useful for audits and version tracking.
- **`pubspec.yaml`**: Dependencies must be declared for Dart analyzer and package manager to resolve them.
- **`components.schema.json`**: Ensures components conform to expected structure (optional but recommended for quality).

---

## remove

### What it does
Removes one or more installed components from the project. Checks dependencies to prevent breaking other components, cleans up unused shared files, updates pubspec.yaml, and deletes empty folders.

**Key responsibilities:**
- Checks if other components depend on the component being removed
- Prompts for force-removal if dependencies are found
- Deletes component files and folders
- Removes no-longer-used shared files
- Updates pubspec.yaml by removing unused dependencies
- Cleans up empty parent folders
- Updates local manifest to reflect removal
- Displays removal summary with counts

**Usage:**
```bash
# Remove a single component
flutter_shadcn remove button

# Remove multiple components
flutter_shadcn remove button dialog

# Force remove (ignore dependencies)
flutter_shadcn remove button --force

# Remove everything
flutter_shadcn remove --all

# Show verbose output
flutter_shadcn remove button --verbose
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Project settings | Reads install path and shared path to locate files to remove |
| `<installPath>/components.json` | Dependency graph | Queries which components depend on the one being removed; prevents breaking dependencies |
| `registry/components.json` | Component metadata | Looks up which shared files are used only by this component (for cleanup) |
| `<installPath>/<name>/` | Component location | Deletes the component folder and all its files |
| `<sharedPath>/` | Shared files location | Removes shared files that are no longer needed by any component |
| `pubspec.yaml` | Project dependencies | Removes package versions that are no longer required after component removal |
| `<installPath>/components.json` | Installed manifest | Updates manifest to remove component entry |

### Why These Files

- **`.shadcn/config.json`**: Tells remove where components are installed without re-prompting.
- **`<installPath>/components.json`**: Critical for checking if other installed components depend on this one; prevents breaking the project.
- **`registry/components.json`**: Helps determine which shared files are exclusive to this component (safe to delete) vs. shared with others.
- **Component/shared files**: The actual files to delete.
- **`pubspec.yaml`**: Must remove unused dependencies to keep the project clean and build size minimal.

---

## dry-run

### What it does
Previews what would be installed without actually installing anything. Shows all dependencies, shared files, pubspec updates, assets, fonts, platform changes, and post-install notes. Helps users understand the scope of installation before committing.

**Key responsibilities:**
- Resolves all component dependencies
- Calculates file counts (component files, shared files, platform changes)
- Lists pubspec updates that would be added
- Shows asset and font installations
- Displays post-install platform-specific steps
- Shows dependency graph with visual hierarchy
- Displays installation plan in an easy-to-read format with separators and alignment

**Usage:**
```bash
# Preview single component installation
flutter_shadcn dry-run button

# Preview multiple components
flutter_shadcn dry-run button dialog form

# Preview all components
flutter_shadcn dry-run --all

# Show verbose details
flutter_shadcn dry-run button --verbose
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Project settings | Reads install path and registry configuration |
| `registry/components.json` | Component metadata | Looks up component files, dependencies, shared requirements, and platform steps |
| `registry/components/<name>/` | Component source | Counts files to show what would be copied |
| `registry/shared/` | Shared files source | Counts shared files needed for the component |
| `pubspec.yaml` | Current dependencies | Identifies which packages would be added (for comparison) |
| `components.schema.json` | Schema validation | Validates that components conform to expected structure before preview |

### Why These Files

- **`.shadcn/config.json`**: Provides context for where files would be installed.
- **`registry/components.json`**: Source of truth for what files and dependencies each component needs; used to calculate the preview plan.
- **Component/shared files**: Necessary to count and list files for preview display.
- **`pubspec.yaml`**: Shows current state so diff can highlight what would be added.
- **`components.schema.json`**: Validates plan before showing it to user; catches configuration errors early.

---

## assets

### What it does
Manages typography fonts and icon fonts for the project. Can list available assets, install all assets, install specific icon fonts, or install typography fonts.

**Key responsibilities:**
- Lists available icon sets and typography fonts
- Copies font files into `assets/fonts/` (or configured path)
- Updates pubspec.yaml with font declarations
- Supports selective installation (icons only, fonts only, or both)

**Usage:**
```bash
# List available assets
flutter_shadcn assets --list

# Install all assets
flutter_shadcn assets --all

# Install only icons
flutter_shadcn assets --icons

# Install only typography fonts
flutter_shadcn assets --fonts

# Install during init
flutter_shadcn init --install-fonts --install-icons
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Project settings | Reads asset paths and registry configuration |
| `registry/assets/` | Asset source | Contains font files and icon sets to copy |
| `pubspec.yaml` | Font declarations | Adds font family definitions and asset paths for Flutter to load fonts |
| `assets/fonts/` or configured path | Asset destination | Stores copied font files for app to use |

### Why These Files

- **`.shadcn/config.json`**: Specifies where assets should be installed.
- **`registry/assets/`**: Single source for all available typography and icon fonts.
- **`pubspec.yaml`**: Flutter's font system requires font declarations in pubspec.yaml; without them, fonts won't be available to widgets.
- **Asset destination folder**: Must exist and be declared for Flutter to include fonts in the app bundle.

---

## platform

### What it does
Manages platform-specific target paths (iOS Info.plist, Android Gradle files, etc.). Allows users to override default platform file locations for components that need platform-specific configuration.

**Key responsibilities:**
- Lists current platform targets (defaults and overrides)
- Allows setting custom paths for platform files
- Resets overrides back to defaults
- Stores configuration in `.shadcn/config.json`

**Usage:**
```bash
# List current platform targets
flutter_shadcn platform --list

# Set custom platform paths
flutter_shadcn platform --set ios.infoPlist=ios/Runner/Info.plist \
  --set android.gradle=android/app/build.gradle

# Reset to defaults
flutter_shadcn platform --reset ios.infoPlist

# Reset all
flutter_shadcn platform --reset-all
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Platform overrides | Stores custom platform file paths set by user |
| `ios/Runner/Info.plist` | iOS configuration | Target file for iOS-specific component configuration |
| `android/app/build.gradle` | Android configuration | Target file for Android-specific component configuration |
| `windows/runner/windows.h` | Windows configuration | Target file for Windows-specific component configuration |
| `macos/Runner/Info.plist` | macOS configuration | Target file for macOS-specific component configuration |

### Why These Files

- **`.shadcn/config.json`**: Persists user's platform overrides so they apply to all future installations without re-setting.
- **Platform-specific files**: Some components (e.g., those using deep linking, camera, or native plugins) need to modify platform-specific files. Users can override defaults if their project structure differs.

---

## theme

### What it does
Manages color themes for the project. Lists available preset themes, applies themes, and (experimentally) applies custom theme files/URLs. Theme changes update the color scheme across all installed components.

**Key responsibilities:**
- Lists all 42 available theme presets
- Applies selected theme to the project
- Updates `<sharedPath>/theme/color_scheme.dart` with selected theme colors
- Optionally applies custom theme JSON (experimental)
- Reapplies theme colors to any hex color references in components

**Usage:**
```bash
# List available themes
flutter_shadcn theme --list

# Apply a theme interactively
flutter_shadcn theme

# Apply specific theme
flutter_shadcn theme modern-minimal

# Apply custom theme from file (experimental)
flutter_shadcn --experimental theme --apply-file /path/to/theme.json

# Apply custom theme from URL (experimental)
flutter_shadcn --experimental theme --apply-url https://example.com/theme.json
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Current theme | Stores selected theme ID for reference and sync operations |
| `registry/shared/theme/preset_theme_data.dart` | Theme presets | Contains all 42 built-in themes with light/dark color definitions |
| `<sharedPath>/theme/color_scheme.dart` | Theme application | Updates with selected theme's colors; all components import and use this file |
| Custom theme JSON | Custom theme source | If using `--apply-file` or `--apply-url`, loads external theme definition |

### Why These Files

- **`.shadcn/config.json`**: Tracks current theme selection so `sync` command can reapply it, and other tools can show which theme is active.
- **`preset_theme_data.dart`**: Centralized source for all available themes; avoids duplication and makes theme management consistent.
- **`<sharedPath>/color_scheme.dart`**: All components import and reference this file, making it the critical integration point for theme changes to take effect.

---

## sync

### What it does
Applies stored configuration changes (from `.shadcn/config.json`) to the project. Useful after manually editing the config file or when folder paths need to be reorganized. Re-applies the current theme and validates configuration.

**Key responsibilities:**
- Reads current configuration from `.shadcn/config.json`
- Reapplies the current theme to the project
- Validates configuration consistency
- Reorganizes installed files if paths have changed
- Updates any path-dependent configurations

**Usage:**
```bash
# Sync configuration (typically after editing .shadcn/config.json)
flutter_shadcn sync

# Sync after changing install paths manually
flutter_shadcn sync

# Sync to reapply current theme
flutter_shadcn sync
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Source configuration | Reads all stored settings: install path, shared path, theme, class prefix, path aliases |
| `<sharedPath>/theme/color_scheme.dart` | Theme target | Reapplies the theme specified in config |
| `registry/shared/theme/preset_theme_data.dart` | Theme source | Looks up the theme definition to reapply |
| Installed component files | Validation targets | Verifies files still exist at configured paths |

### Why These Files

- **`.shadcn/config.json`**: Single source of truth for all project settings; sync reads this to ensure everything matches.
- **`color_scheme.dart`**: Reapplied during sync to ensure theme is current if it was manually edited in config.
- **`preset_theme_data.dart`**: Needed to look up the theme colors for reapplication.
- **Installed files**: Validation ensures configuration paths match actual file locations.

---

## doctor

### What it does
Runs diagnostics on the project's shadcn setup. Validates configuration, checks components.json schema, verifies installed files, and reports cache status. Helps troubleshoot installation issues.

**Key responsibilities:**
- Validates `.shadcn/config.json` exists and is readable
- Validates `<installPath>/components.json` against `components.schema.json`
- Checks that all configured paths are valid
- Reports resolved platform targets (defaults + user overrides)
- Shows index.json cache location and staleness
- Displays aligned, readable diagnostic output
- Provides actionable error messages for detected issues

**Usage:**
```bash
# Run full diagnostics
flutter_shadcn doctor

# Show resolved platforms and cache info
flutter_shadcn doctor --verbose
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Configuration validation | Checks if config is valid and accessible |
| `<installPath>/components.json` | Schema validation | Validates installed components structure against schema |
| `components.schema.json` | Validation rules | Defines expected structure for components.json |
| `~/.flutter_shadcn/cache/` | Cache diagnostics | Shows cache location, age, and size |
| Configured paths | Path validation | Verifies install path, shared path, and platform targets exist |
| Registry configuration | Registry validation | Checks registry mode (local/remote) and paths/URLs are accessible |

### Why These Files

- **`.shadcn/config.json`**: Essential to validate since all other commands depend on it; corrupted config breaks the entire CLI.
- **`<installPath>/components.json`**: Should conform to schema; validation catches invalid entries that could break future operations.
- **`components.schema.json`**: Provides the rules for what valid components look like; used as reference for validation.
- **Cache paths**: Helps diagnose cache issues (staleness, size, location) and guides users on how to refresh.
- **Configured paths**: Verifies user-configured paths are actually valid before commands try to use them.

---

## list

### What it does
Displays all available components from the registry, grouped by category. Uses intelligent caching to avoid repeated remote downloads. Helps users browse and discover components before installing.

**Key responsibilities:**
- Loads index.json from local registry or remote with caching
- Groups components by category (layout, form, feedback, etc.)
- Displays component names, descriptions, and tags
- Uses 24-hour cache staleness policy (configurable with `--refresh`)
- Falls back to cached index.json if remote download fails
- Provides graceful error handling with recovery suggestions

**Usage:**
```bash
# List all components grouped by category
flutter_shadcn list

# Force refresh from remote (ignore cache)
flutter_shadcn list --refresh

# Show verbose details
flutter_shadcn list --verbose

# Use specific registry
flutter_shadcn list --registry remote
flutter_shadcn list --registry local --registry-path /path/to/registry
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Registry configuration | Reads registry mode and paths for correct source |
| `registry/index.json` | Component index source | Local or remote index listing all available components |
| `~/.flutter_shadcn/cache/<registryId>/index.json` | Cached index | Caches index.json locally to avoid repeated downloads (24-hour staleness) |
| Remote registry URL | Remote source | Falls back to remote if local not found; default CDN or custom URL |

### Why These Files

- **`.shadcn/config.json`**: Specifies which registry to use (local or remote).
- **`registry/index.json`**: Lightweight index file listing all components; much faster than loading full components.json.
- **Cache file**: Reduces network requests and improves responsiveness; critical for offline support and reducing CDN load.
- **Remote URL**: Source of truth when local registry unavailable; enables cloud-based component sharing.

---

## search

### What it does
Searches for components by name, description, tags, or keywords. Results are ranked by relevance. Combines index.json caching with intelligent scoring to quickly find matching components.

**Key responsibilities:**
- Loads index.json from local/remote with caching
- Searches component names, descriptions, tags, and keywords
- Ranks results by relevance score
- Displays top matching components with scores
- Uses same caching strategy as `list` command
- Handles search errors gracefully

**Usage:**
```bash
# Search for components
flutter_shadcn search button

# Search with phrase
flutter_shadcn search "form input"

# Force refresh cache
flutter_shadcn search button --refresh

# Show verbose results
flutter_shadcn search button --verbose

# Use specific registry
flutter_shadcn search button --registry local --registry-path /path/to/registry
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Registry configuration | Reads registry mode and paths |
| `registry/index.json` | Search source | Contains component metadata (name, description, tags, keywords) for searching |
| `~/.flutter_shadcn/cache/<registryId>/index.json` | Cached index | Reuses same cache as `list` command (24-hour staleness) |
| Remote registry URL | Remote source | Falls back if local not found |

### Why These Files

- **`.shadcn/config.json`**: Determines which registry to search.
- **`registry/index.json`**: Lightweight source with all searchable metadata; includes names, descriptions, tags, keywords.
- **Cache**: Avoids repeated downloads for frequently used searches; shared with `list` and `info` commands.
- **Remote URL**: Enables searching from remote registry if local unavailable.

---

## info

### What it does
Displays detailed information about a specific component. Shows description, API, usage examples with code, dependencies, related components, and tags. Uses cached index for quick lookup.

**Key responsibilities:**
- Loads component metadata from index.json (cached)
- Displays component description and tags
- Shows component API (constructors, properties, callbacks)
- Displays usage examples with actual Dart code indented properly
- Lists component dependencies
- Shows related components
- Handles missing components gracefully with suggestions

**Usage:**
```bash
# Get detailed component info
flutter_shadcn info button

# Show verbose details
flutter_shadcn info button --verbose

# Force refresh cache
flutter_shadcn info button --refresh

# Use specific registry
flutter_shadcn info button --registry local --registry-path /path/to/registry
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Registry configuration | Reads registry mode and paths |
| `registry/index.json` | Component metadata source | Contains component descriptions, API, examples, tags, dependencies |
| `~/.flutter_shadcn/cache/<registryId>/index.json` | Cached index | Reuses cache from `list` and `search` (24-hour staleness) |
| Remote registry URL | Remote source | Falls back if local not found |
| `registry/components/<name>/README.md` | Component documentation | Optional; additional documentation if available locally |

### Why These Files

- **`.shadcn/config.json`**: Determines which registry to query.
- **`registry/index.json`**: Contains all component metadata including description, API, examples in structured format.
- **Cache**: Shared with `list` and `search`; avoids repeated downloads when querying multiple components.
- **Component README** (optional): If available locally, provides human-readable documentation alongside CLI output.

---

## install-skill

### What it does
Manages AI skills for model-specific installations. Auto-discovers hidden AI model folders (`.claude`, `.gpt4`, `.cursor`, `.gemini`, etc.) and installs skill documentation files from the local registry to enable AI-assisted component development. Supports both copying skills per-model and symlinking for efficiency.

**Key responsibilities:**
- Auto-discovers AI model folders in project root (20+ supported AI assistants)
- Finds skills in local registry (searches parent directories automatically)
- Parses `skill.json` manifest to determine which files to copy
- Interactive model selection (numbered menu)
- Copies skill files maintaining directory structure
- Creates symlinks from multiple models to a single skill installation
- Tracks installed skills per model with manifest files
- Lists installed skills grouped by AI model
- Supports uninstalling skills from specific models

**Files copied from skill:**
- `SKILL.md` - Main skill documentation (AI instructions)
- `INSTALLATION.md` - Installation guide
- `README.md` - Skill overview (if exists)
- `references/commands.md` - CLI command reference
- `references/examples.md` - Usage examples

**Management files (remain in registry):**
- `skill.json` - Skill metadata and manifest (CLI use only)
- `skill.yaml` - Alternative manifest format (CLI use only)
- `references/schemas.md` - Component schema reference (CLI/dev use only)

**Usage:**
```bash
# Interactive skill installation (prompts for skill ID and model selection)
flutter_shadcn install-skill

# Install specific skill to specific model
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .claude

# Install with custom skills URL/path
flutter_shadcn install-skill --skill flutter-shadcn-ui --skills-url /path/to/skills

# Install skill with interactive model selection
flutter_shadcn install-skill --skill flutter-shadcn-ui

# List installed skills by model
flutter_shadcn install-skill --list

# Uninstall skill from specific model
flutter_shadcn install-skill --uninstall flutter-shadcn-ui --model .claude

# Create symlinks (install to .claude, then symlink to others)
flutter_shadcn install-skill --skill flutter-shadcn-ui --symlink --model .claude

# Show verbose output
flutter_shadcn install-skill --verbose --skill flutter-shadcn-ui --model .claude
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `.shadcn/config.json` | Registry configuration | Reads registry URL as default skills source |
| `shadcn_flutter_kit/flutter_shadcn_kit/skills/{skillId}/` | Primary skill source | Local kit registry with skill files |
| `../skills/{skillId}/` | Parent directory skill source | Searches up directory tree for skills folder |
| `skills/{skillId}/` | Project root skill source | Local skills in project |
| `{skillId}/skill.json` | Skill manifest | Defines which files to copy and compatibility |
| `{skillId}/skill.yaml` | Alternative manifest | Optional YAML format manifest |
| `{skillId}/SKILL.md` | Main skill doc | AI instructions and knowledge base |
| `{skillId}/INSTALLATION.md` | Installation guide | How to deploy skill to AI models |
| `{skillId}/references/*.md` | Reference docs | Commands, schemas, examples |
| `<projectRoot>/.claude/skills/{skillId}/` | Claude skill location | Copies skill files for Claude AI |
| `<projectRoot>/.gpt4/skills/{skillId}/` | GPT-4 skill location | Copies skill files for ChatGPT |
| `<projectRoot>/.cursor/skills/{skillId}/` | Cursor skill location | Copies skill files for Cursor AI |
| `<projectRoot>/.gemini/skills/{skillId}/` | Gemini skill location | Copies skill files for Google Gemini |
| `<model>/skills/{skillId}/manifest.json` | Install tracking | Records installation metadata |

### Why These Files

- **`.shadcn/config.json`**: Provides registry URL which defaults as skills source location.
- **Local kit registry paths**: Searches multiple locations to find skill source files without requiring manual configuration.
- **skill.json manifest**: Declares files structure, allows CLI to copy correct files with proper paths.
- **AI model folders** (`.claude`, `.gpt4`, etc.): Hidden folders where AI assistants read skills and prompts; auto-discovery eliminates manual configuration.
- **Skill documentation files**: Provide AI models with complete knowledge of CLI commands, component patterns, troubleshooting, and best practices.
- **manifest.json tracking**: Records which skills are installed where, enabling list/uninstall functionality.

### Installation Modes

1. **Copy per-model**: Copies skill files to each selected model independently. Ensures isolated installations.
2. **Install + symlink**: Installs skill files once, creates symlinks from other model folders. Saves disk space (skill files ~50KB).
3. **Selective symlink**: Install to primary model, manually choose which other models get symlinks vs. copies.

### Skill Discovery Algorithm

The CLI searches for skills in this order:
1. `shadcn_flutter_kit/flutter_shadcn_kit/skills/{skillId}` - Traverses up from project root
2. Parent directories: `../skills/{skillId}` - Searches up directory tree
3. Project root: `./skills/{skillId}` - Local skills folder
4. Fallback: Creates placeholder if skill not found locally

---

## version

### What it does
Displays the current CLI version or checks for available updates from pub.dev. Helps users stay informed about new releases and features.

**Key responsibilities:**
- Shows current installed version number
- Optionally checks pub.dev for newer versions
- Displays update notification with version comparison
- Provides upgrade instructions if update available

**Usage:**
```bash
# Show current version
flutter_shadcn version

# Check for available updates
flutter_shadcn version --check
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `pubspec.yaml` (embedded) | Current version source | Version number is compiled into the CLI binary |
| `https://pub.dev/api/packages/flutter_shadcn_cli` | Latest version API | Queries pub.dev REST API to fetch latest published version |

### Why These Files

- **Embedded version**: The current version (0.1.8) is hardcoded in `version_manager.dart` as a constant, ensuring the CLI always knows its own version without external dependencies.
- **pub.dev API**: Official source of truth for latest published version; using the API ensures accurate, real-time version information.

---

## upgrade

### What it does
Upgrades the CLI to the latest version published on pub.dev. Automates the update process with a single command, eliminating manual steps.

**Key responsibilities:**
- Checks pub.dev for the latest version
- Compares with current installed version
- Runs `dart pub global activate flutter_shadcn_cli` to upgrade
- Confirms successful upgrade or provides manual fallback instructions
- Supports force upgrade to reinstall current version if needed

**Usage:**
```bash
# Upgrade to latest version
flutter_shadcn upgrade

# Force upgrade (even if already on latest)
flutter_shadcn upgrade --force

# Show help
flutter_shadcn upgrade --help
```

### Files Used

| File Path | Purpose | Why |
|-----------|---------|-----|
| `pubspec.yaml` (embedded) | Current version comparison | Used to determine if upgrade is needed |
| `https://pub.dev/api/packages/flutter_shadcn_cli` | Latest version lookup | Fetches the latest published version for comparison |
| `dart` executable | Upgrade execution | Runs `dart pub global activate` command to install latest version |
| `~/.pub-cache/bin/` | Installation target | Where dart pub global installs the upgraded CLI executable |

### Why These Files

- **Current version**: Embedded version allows comparison to determine if upgrade is necessary.
- **pub.dev API**: Authoritative source for latest version; ensures we upgrade to the correct version.
- **dart executable**: Official Dart package manager tool; only way to properly upgrade globally activated packages.
- **pub-cache**: Standard location for globally activated Dart packages; upgrade updates files here automatically.

### Automatic Update Checking

The CLI automatically checks for updates on every command execution (excluding `version` and `upgrade` commands to avoid recursion):

**How it works:**
1. **Rate limiting**: Checks pub.dev API once per 24 hours maximum
2. **Caching**: Stores last check timestamp and result in `~/.flutter_shadcn/cache/version_check.json`
3. **Silent failure**: If API check fails, it silently continues without interrupting user workflow
4. **Notification**: If newer version detected, shows subtle banner at startup

**Cache file structure:**
```json
{
  "lastCheck": "2026-02-04T10:30:00.000Z",
  "hasUpdate": true,
  "latestVersion": "0.1.9",
  "currentVersion": "0.1.8"
}
```

**Opt-out:**
Edit `.shadcn/config.json`:
```json
{
  "checkUpdates": false
}
```

**Benefits:**
- Users stay informed about new features and bug fixes
- No manual checking required
- Minimal network overhead (24-hour cache)
- Non-intrusive (doesn't block commands)

---

## Global Flags & Options

### `--registry`
Specifies which registry to use: `local` or `remote`.

**Files Used:**
- `.shadcn/config.json` - Reads fallback registry mode if flag not provided

### `--registry-path`
Path to local registry (used with `--registry local`).

**Files Used:**
- `.shadcn/config.json` - Stored for future use

### `--registry-url`
Custom CDN/remote URL for registry (used with `--registry remote`).

**Files Used:**
- `.shadcn/config.json` - Stored for future use

### `--refresh`
Forces cache refresh for discovery commands (list, search, info).

**Files Used:**
- `~/.flutter_shadcn/cache/` - Clears or updates cached index.json

### `--verbose`
Shows detailed output for debugging.

**Files Used:**
- Various command-specific files are logged in detail

### `--yes`
Skips all prompts and uses default values (init only).

**Files Used:**
- Same as the command but without user interaction

### `--experimental`
Enables experimental features (e.g., custom theme files).

**Files Used:**
- Command-specific experimental features are unlocked

### `--wip`
Enables work-in-progress features.

**Files Used:**
- Command-specific WIP features are unlocked

---

## Summary Table: Files by Frequency

| File | Frequency | Used By Commands |
|------|-----------|------------------|
| `.shadcn/config.json` | **CRITICAL** | Every command except version/upgrade (init, add, remove, dry-run, assets, platform, theme, sync, doctor, list, search, info, install-skill) |
| `registry/components.json` | **HIGH** | add, remove, dry-run, doctor (validation) |
| `registry/index.json` | **HIGH** | list, search, info, doctor |
| `<installPath>/components.json` | **HIGH** | add, remove, dry-run, doctor |
| `pubspec.yaml` | **HIGH** | init, add, remove, assets, version (embedded), upgrade (embedded) |
| `components.schema.json` | **MEDIUM** | add, remove, dry-run, doctor |
| `<sharedPath>/theme/color_scheme.dart` | **MEDIUM** | init, theme, sync |
| `preset_theme_data.dart` | **MEDIUM** | init, theme, sync |
| Cache files | **MEDIUM** | list, search, info, doctor |
| `https://pub.dev/api/packages/flutter_shadcn_cli` | **LOW** | version (--check), upgrade |
| Platform config files | **LOW** | platform, add (post-install) |
| Skill folders | **LOW** | install-skill |
| Asset files | **LOW** | assets, init |
| `<installPath>/components.json` | **HIGH** | add, remove, dry-run, doctor |
| `pubspec.yaml` | **HIGH** | init, add, remove, assets |
| `components.schema.json` | **MEDIUM** | add, remove, dry-run, doctor |
| `<sharedPath>/theme/color_scheme.dart` | **MEDIUM** | init, theme, sync |
| `preset_theme_data.dart` | **MEDIUM** | init, theme, sync |
| Cache files | **MEDIUM** | list, search, info, doctor |
| Platform config files | **LOW** | platform, add (post-install) |
| Skill folders | **LOW** | install-skill |
| Asset files | **LOW** | assets, init |

---

## Diagram: Command Dependency Flow

```
init ────────┬────────────────────────────┐
             │                            │
             ▼                            ▼
       Creates config.json          Creates components.json
             │                            │
    ┌────────┴─────────────┐       ┌─────┴──────────────┐
    │                      │       │                    │
    ▼                      ▼       ▼                    ▼
   add                 remove    dry-run              (tracks
   │                      │        │              installed)
   ├─→ Installs        Removes   Previews
   │    components     components installs
   │                      │
   │    ┌─────────────────┘
   │    │
   │    └──→ Both use registry/components.json
   │         and <installPath>/components.json
   │
   └──→ theme ←──┐
                 │
            Updates  color_scheme.dart
                 │
                 └──→ All components inherit theme

    sync ────────→ Reapplies config & theme
    
    doctor ──────→ Validates all above files
    
list/search/info ──→ Use cache + registry/index.json
                     (Lightweight discovery)
    
install-skill ───→ Manages AI model folders
```

---

## Best Practices for File Management

1. **Never manually edit `<installPath>/components.json`** - Let CLI manage it via add/remove commands.
2. **Backup `.shadcn/config.json`** before major changes; it controls entire project setup.
3. **Use `flutter_shadcn doctor`** to validate setup before troubleshooting issues.
4. **Clear cache with `--refresh`** if discovering new components in development.
5. **Use `dry-run` before `add`** to preview dependencies and understand scope.
6. **Keep `components.schema.json` in sync** with registry updates for validation to work.
7. **Use `--force` remove sparingly** - dependency checking prevents broken states.

