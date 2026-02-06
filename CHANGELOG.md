# Changelog

## Unreleased

- (empty)

## 0.1.9

### 🧭 Registry & Schema
- **IMPROVED**: components.json schema validation now uses JSON Schema with `$schema` resolution and local fallback to `components.schema.json`.

### 📦 Install Manifests
- **NEW**: Per-component install manifests at `.shadcn/components/<id>.json` (version/tags + audit data).
- **IMPROVED**: `<installPath>/components.json` now stores component metadata (version/tags).

### 🧰 Init & Install
- **CHANGED**: `init --add` removed; pass components positionally (e.g., `flutter_shadcn init button dialog`).
- **IMPROVED**: Shared dependency closure for init/shared installs, plus cross-registry file dependency resolution.

### 🧪 Tests
- **NEW**: Integration tests validating CLI install behavior and schema validation.

## 0.1.8

### 🎯 Component Discovery
- **NEW**: Component discovery system with `list`, `search`, and `info` commands.
  - Browse components by category with `list`
  - Search with relevance scoring via `search <query>`
  - View detailed component info with `info <component-id>`
- **NEW**: Intelligent index.json caching (24-hour staleness policy).
  - Cache location: `~/.flutter_shadcn/cache/{registryId}/index.json`
  - Local index.json support with remote fallback
  - Use `--refresh` flag to force cache update from remote

### 🤖 AI Skills Management
- **NEW**: Interactive multi-skill, multi-model AI skills manager with `install-skill` command.
  - **Default multi-skill interactive mode** - just run `flutter_shadcn install-skill` (no flags needed, see what's already installed)
  - Auto-discovers 28+ AI model folders (`.claude`, `.cursor`, `.gemini`, `.gpt4`, `.codex`, `.deepseek`, `.ollama`, etc.)
  - **Shows human-readable model names** (e.g., "Cursor", "Claude (Anthropic)", "OpenAI (Codex)", "Google Gemini")
  - **Intelligent duplicate detection**: Checks which models already have selected skills
    - Offers 3 options when skills exist: skip installed, overwrite all, or cancel
    - Only installs to models without the skill (smart selection)
  - **Context-aware installation modes**:
    - Detects existing installations automatically
    - When 2+ models selected: offers copy-per-model or install+symlink (saves disk space)
    - Detects existing installations and offers them as symlink sources
    - Only shows relevant options based on what's already installed
  - **Multi-model selection**: Pick individual models or "all models" option
  - **Only creates selected model folders** on demand (no template clutter)
  - Smart default selection: primary model + symlinks to others when space-saving makes sense
- **NEW**: skills.json discovery index (mirrors components.json pattern).
  - List available skills: `flutter_shadcn install-skill --available`
  - Install single skill: `flutter_shadcn install-skill --skill <id>`
  - Install to specific model: `flutter_shadcn install-skill --skill <id> --model <name>`
  - **Multi-location skill discovery**: Local kit registry → parent directories → project root (auto-fallback)
  - Custom registry: `--skills-url /path/or/url`
  - **Requires `skill.json` or `skill.yaml` manifest** for installation (throws helpful error if missing)
  - Copies AI-focused docs: SKILL.md, INSTALLATION.md, references/{commands,examples}.md
  - Management files (skill.json, skill.yaml, schemas.md) stay in registry (CLI-only)
- **NEW**: Interactive skill removal with `--uninstall-interactive`.
  - Menu-driven selection: choose which skills to remove
  - Model selection: remove from specific models or all models
  - Shows installation count per skill
  - Confirmation before removal
  - Graceful error handling for missing/already-deleted folders
- **IMPROVED**: Symlink handling for safe removal.
  - Auto-detects symlinks vs real directories
  - Removes only the symlink, preserves source files
  - Resolves symlink targets before deletion (prevents corruption)
  - Handles broken symlinks gracefully
  - Batch removal: safely removes from multiple models even if some don't have the skill

### 🔧 Project Management Commands
- **NEW**: Dry-run command to preview component installs (deps, shared, assets, fonts, platform changes).
- **NEW**: Doctor validates components.json against components.schema.json and reports cache paths.

### 📦 Version Management
- **NEW**: `version` command to show current CLI version and check for updates.
  - Use `flutter_shadcn version` to display current version
  - Use `flutter_shadcn version --check` to check for available updates
- **NEW**: `upgrade` command to upgrade CLI to the latest version.
  - Automatically fetches and installs the latest version from pub.dev
  - Use `--force` flag to force upgrade even if already on latest
- **NEW**: Automatic update checking on every CLI command.
  - Checks pub.dev once per 24 hours (rate-limited)
  - Shows subtle notification if newer version available
  - Cached in `~/.flutter_shadcn/cache/version_check.json`
  - Opt-out via `.shadcn/config.json`: set `"checkUpdates": false`

### 💬 User Feedback
- **NEW**: `feedback` command for submitting feedback and reporting issues.
  - Interactive menu with 6 feedback categories (bug, feature, docs, question, performance, other)
  - Opens GitHub with pre-filled issue templates
  - Auto-includes CLI version, OS, and Dart version for better context
  - Each feedback type has custom emoji, labels, and structured template
  - Cross-platform browser opening (macOS, Linux, Windows)

### 🧪 Testing & Quality
- **NEW**: Comprehensive test coverage for skill manager and version manager.
  - Skill discovery tests (local kit registry, parent directories, manifest requirement, YAML support)
  - File copying tests (AI-focused files, manifest exclusion, directory structure)
  - Skill management tests (install, uninstall, list, symlinks)
  - Model discovery tests (auto-detection, lazy folder creation)
  - Version comparison tests (semver logic, pre-release handling)
  - Cache management tests (24-hour policy, timestamp handling)
  - Error handling tests (network failures, malformed responses, missing manifests)
  - **Total: 38 tests** (13 skill manager + 11 version manager + 14 existing)

### 🐛 Bug Fixes
- **FIX**: Graceful error handling for component discovery failures.

## 0.1.7

- **BREAKING**: Complete theme preset overhaul with 42 new modern themes.
- New theme presets: amber-minimal, amethyst-haze, bold-tech, bubblegum, caffeine, candyland, catppuccin, claude, claymorphism, clean-slate, cosmic-night, cyberpunk, darkmatter, doom-64, elegant-luxury, graphite, kodama-grove, midnight-bloom, mocha-mousse, modern-minimal, mono, nature, neo-brutalism, northern-lights, notebook, ocean-breeze, pastel-dreams, perpetuity, quantum-rose, retro-arcade, sage-garden, soft-pop, solar-dusk, starry-night, sunset-horizon, supabase, t3-chat, tangerine, twitter, vercel, vintage-paper, violet-bloom.
- Fix repository URL in pubspec.yaml for pub.dev validation.
- Follow Dart file conventions for better code organization.
- Remove all previous theme presets in favor of new collection.

## 0.1.6

- Add Dartdoc for public APIs and export preset theme data.
- Add CLI example script for pub.dev package validation.
- Update dependency constraints to latest compatible versions.
- Refresh pubspec description and project links.

## 0.1.5

- Add file-level dependsOn support for component/shared files.
- Apply platform-specific instructions with configurable targets.
- Add platform command to set/reset target overrides.
- Report post-install notes for components.
- Prettify CLI output with colors and sections.

## 0.1.4

- Experimental theme install from JSON file/URL (gated by --experimental).
- WIP/experimental feature flags added to CLI.
- Batched dependency updates using dart pub add/remove.
- remove --all now cleans empty parent folders.
- Theme preset application bugfix (color hex replacement).
- Clearer init prompts and expanded help output.
- Added documentation, PRD, and example theme JSON.

## 0.1.3

- Add `sync` command to apply .shadcn/config.json changes (paths + theme).
- Track installed components in project components.json.
- Add `remove --all` and bulk removal support.
- Ensure init files are created before add/remove.

## 0.1.2

- Add dev registry mode and init one-shot flags.
- Improve README for end users and pub.dev.
- Add tests and integration coverage.
- Normalize install/shared paths and alias handling.
- Install core shared helpers + deps during init.
