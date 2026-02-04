# Changelog

## 0.1.8

- **NEW**: Component discovery system with `list`, `search`, and `info` commands.
  - Browse components by category with `list`
  - Search with relevance scoring via `search <query>`
  - View detailed component info with `info <component-id>`
- **NEW**: Intelligent index.json caching system (24-hour staleness policy).
  - Cache location: `~/.flutter_shadcn/cache/{registryId}/index.json`
  - Use `--refresh` to force cache update from remote
- **NEW**: Interactive AI skill manager with `install-skill` command.
  - Works interactively by default - just run `flutter_shadcn install-skill` without flags
  - Auto-discovers AI model folders (`.claude`, `.gpt4`, `.cursor`, `.gemini`, etc.)
  - **Shows human-readable model names** (e.g., "Cursor", "Claude (Anthropic)", "Codex (OpenAI)")
  - Interactive numbered menu for model selection
  - **Only creates selected model folders**, not all template folders
  - Multiple installation modes: copy-per-model or install+symlink
  - List, uninstall, and symlink management for skills
  - **skills.json discovery index** for browsing available skills (like index.json for components)
  - `--available` / `-a` flag to list all available skills from registry
  - `--interactive` / `-i` flag for multi-skill, multi-model batch installation
  - Automatically searches for skills in local registry (`shadcn_flutter_kit/flutter_shadcn_kit/skills/`)
  - **Requires `skill.json` or `skill.yaml` manifest** for installation (throws error if missing)
  - Parses manifest's `files` key to determine which files to copy
  - Copies AI-focused documentation: SKILL.md, INSTALLATION.md, references/commands.md, references/examples.md
  - Management files (skill.json, skill.yaml, schemas.md) remain in registry for CLI use only
  - Multi-location skill discovery with graceful fallback
- **NEW**: Symlink support for sharing skills across models without duplication.
- **NEW**: Dry-run command to preview installs (deps, shared, assets, fonts, platform changes).
- **NEW**: Doctor validates components.json against components.schema.json and reports cache paths.
- **NEW**: Local index.json support with remote fallback for list/search/info.
- **NEW**: Skills URL override (`--skills-url`) with registry URL default.
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
- **NEW**: Comprehensive test coverage for skill manager and version manager.
  - Skill discovery tests (local kit registry, parent directories, manifest requirement, YAML support)
  - File copying tests (AI-focused files, manifest exclusion, directory structure)
  - Skill management tests (install, uninstall, list, symlinks)
  - Model discovery tests (auto-detection, auto-creation)
  - Version comparison tests (semver logic, pre-release handling)
  - Cache management tests (24-hour policy, timestamp handling)
  - Error handling tests (network failures, malformed responses, missing manifests)
  - **Total: 38 tests** (13 skill manager + 11 version manager + 14 existing)
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
