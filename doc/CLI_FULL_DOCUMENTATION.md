# CLI Markdown Documentation (shadcn_flutter_cli)

Scope: Markdown files under shadcn_flutter_cli only.

## Tree (Markdown Files Only)

```
shadcn_flutter_cli/
  CHANGELOG.md
  FEEDBACK_FEATURE.md
  README.md
  .dart_tool/extension_discovery/README.md
  doc/
    DOCUMENTATION.md
    FEATURE_SUMMARY.md
    FULL_COMMANDS_DOCS.md
    MANIFEST_REQUIREMENT.md
    SKILLS_JSON_DISCOVERY.md
    SKILL_COMMAND_GUIDE.md
    SKILL_COMMAND_IMPLEMENTATION.md
  test/
    README.md
```

## Definitions and Examples

### shadcn_flutter_cli/README.md
Definition: Primary entrypoint for users. It explains installation, quick start, configuration, commands, and troubleshooting for the CLI.
Example:
```bash
flutter_shadcn init --yes
```

### shadcn_flutter_cli/CHANGELOG.md
Definition: Versioned change history of the CLI with release notes and feature summaries.
Example:
```text
Check the Unreleased section for upcoming changes before publishing.
```

### shadcn_flutter_cli/FEEDBACK_FEATURE.md
Definition: Detailed specification of the feedback command, including categories, templates, and GitHub issue behavior.
Example:
```bash
flutter_shadcn feedback
```

### shadcn_flutter_cli/.dart_tool/extension_discovery/README.md
Definition: Cache readme for extension discovery. It warns not to depend on this folder and describes cache behavior.
Example:
```bash
rm -rf shadcn_flutter_cli/.dart_tool/extension_discovery
```

### shadcn_flutter_cli/doc/DOCUMENTATION.md
Definition: High-level CLI documentation covering architecture, flow, commands, and key concepts like registry, manifest, and state.
Example:
```bash
flutter_shadcn doctor
```

### shadcn_flutter_cli/doc/FEATURE_SUMMARY.md
Definition: Implementation summary of component discovery and skill installation features, including architecture notes and examples.
Example:
```bash
flutter_shadcn search button
```

### shadcn_flutter_cli/doc/FULL_COMMANDS_DOCS.md
Definition: Comprehensive documentation for every CLI command, including inputs, outputs, file usage, and rationale.
Example:
```bash
flutter_shadcn dry-run button
```

### shadcn_flutter_cli/doc/MANIFEST_REQUIREMENT.md
Definition: Explains the skill.json or skill.yaml requirement for install-skill, with examples and error cases.
Example:
```bash
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .claude
```

### shadcn_flutter_cli/doc/SKILLS_JSON_DISCOVERY.md
Definition: Describes the skills.json discovery index, interactive multi-skill install flow, and AI model display names.
Example:
```bash
flutter_shadcn install-skill --available
```

### shadcn_flutter_cli/doc/SKILL_COMMAND_GUIDE.md
Definition: End-to-end user guide for install-skill, including modes, discovery, symlinks, and troubleshooting.
Example:
```bash
flutter_shadcn install-skill --skill flutter-shadcn-ui --symlink --model .claude
```

### shadcn_flutter_cli/doc/SKILL_COMMAND_IMPLEMENTATION.md
Definition: Implementation-focused summary of install-skill behavior, file copying, and search algorithm.
Example:
```bash
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .claude
```

### shadcn_flutter_cli/test/README.md
Definition: Overview of the CLI test suite, coverage areas, and how to run tests.
Example:
```bash
cd shadcn_flutter_cli
flutter test test/cli_integration_test.dart
```
