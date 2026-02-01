# Changelog

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
