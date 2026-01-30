# Changelog

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
