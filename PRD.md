# Product Requirements Document (PRD)

## Product Name
flutter_shadcn_cli

## Problem Statement
Flutter developers want a fast, consistent way to copy registry components into their apps while keeping shared helpers and dependencies in sync. Manual copy/paste is error‑prone and hard to maintain.

## Goals
- Provide a reliable CLI to install/remove components and shared helpers.
- Keep dependencies and local manifests synchronized.
- Support both local (dev) and remote (CDN) registries.
- Offer a clear, guided init workflow.

## Non‑Goals
- Building a visual editor or live component preview system.
- Hosting or serving the registry.
- Replacing Flutter package managers.

## Target Users
- Flutter developers consuming the shadcn Flutter registry.
- Maintainers contributing new components.
- Internal teams validating registry output.

## User Stories
1. As a developer, I can initialize the CLI in a project and choose install paths.
2. As a developer, I can add/remove multiple components quickly.
3. As a developer, I can apply a theme preset to my app’s color scheme.
4. As a maintainer, I can test components using a local registry.
5. As a contributor, I can understand registry structure and CLI behavior from docs.

## Functional Requirements
- Init with prompts and `--yes` non‑interactive mode.
- Install/remove components and composites.
- Track installed components in a manifest file.
- Sync dependencies using `dart pub add/remove`.
- Apply theme presets to `color_scheme.dart`.
- Support local and remote registry modes.
- Provide a `sync` command for config changes.

## UX Requirements
- Clear, plain‑language prompts.
- Safe defaults.
- Concise logs with a `--verbose` option.

## Success Metrics
- >95% successful installs without manual edits.
- <5% of installs require manual dependency fixes.
- Init flow completion under 60 seconds.

## Risks & Mitigations
- **Theme file format drift**: Keep `theme_css.dart` robust and add tests.
- **Registry schema changes**: Validate via registry schema and CLI guards.
- **Dependency conflicts**: Track managed deps and batch updates.

## Open Questions
- Should dependency updates be optional with a flag?
- Should the CLI support dry‑run mode?
