# Skill Installation Manifest Requirement

## Overview

The `install-skill` command now **requires** either a `skill.json` or `skill.yaml` manifest file to be present in the skill directory. This ensures consistent, predictable skill installations driven by explicit configuration rather than implicit file discovery.

## Manifest Files

### Priority
1. **skill.json** - Checked first (preferred)
2. **skill.yaml** - Checked if skill.json not found

### Location
Manifest files must be in the skill's root directory:
```
skills/
  └── flutter-shadcn-ui/
      ├── skill.json          ← Required (or skill.yaml)
      ├── SKILL.md
      ├── INSTALLATION.md
      ├── README.md
      └── references/
          ├── commands.md
          ├── examples.md
          └── schemas.md
```

### Purpose
- **CLI Management**: Manifests stay in the CLI registry for management
- **File Selection**: The `files` key determines which files get copied to AI model folders
- **Structure Definition**: Defines the skill's metadata and file organization

## The `files` Key

The manifest's `files` object specifies which files to copy during installation:

```json
{
  "files": {
    "main": "SKILL.md",
    "readme": "README.md",
    "installation": "INSTALLATION.md",
    "references": {
      "commands": "references/commands.md",
      "schemas": "references/schemas.md",    // Excluded automatically
      "examples": "references/examples.md"
    }
  }
}
```

### Copied Files
Based on the example above, these files are copied to AI model folders:
- ✅ `SKILL.md` (main)
- ✅ `README.md` (readme)
- ✅ `INSTALLATION.md` (installation)
- ✅ `references/commands.md` (references.commands)
- ✅ `references/examples.md` (references.examples)

### Excluded Files
These files remain in the CLI registry only:
- ❌ `skill.json` / `skill.yaml` (management files)
- ❌ `references/schemas.md` (excluded via 'schemas' key filter)

## Error Handling

### Missing Manifest
```bash
$ flutter_shadcn install-skill my-skill --model .claude
✗ No skill.json or skill.yaml found in /path/to/skills/my-skill
✗ Failed to install skill: Exception: Skill manifest (skill.json or skill.yaml) is required
```

### Empty Files Configuration
```bash
$ flutter_shadcn install-skill my-skill --model .claude
✗ No files configured in manifest to copy
✗ Failed to install skill: Exception: Manifest must specify files to copy in the "files" key
```

## Implementation Details

### Discovery Process
```dart
// Check for skill.json first
final skillJsonFile = File(p.join(sourcePath, 'skill.json'));
final skillYamlFile = File(p.join(sourcePath, 'skill.yaml'));

if (await skillJsonFile.exists()) {
  manifestFile = skillJsonFile;
} else if (await skillYamlFile.exists()) {
  manifestFile = skillYamlFile;
} else {
  throw Exception('Skill manifest (skill.json or skill.yaml) is required');
}
```

### File Copying Logic
```dart
final filesConfig = json['files'] as Map<String, dynamic>?;

if (filesConfig != null) {
  // Copy main file
  if (filesConfig['main'] != null) {
    files.add(File(p.join(sourcePath, filesConfig['main'])));
  }
  
  // Copy references (exclude 'schemas' key)
  if (filesConfig['references'] is Map) {
    final references = filesConfig['references'] as Map<String, dynamic>;
    for (final entry in references.entries) {
      if (entry.key != 'schemas' && entry.value is String) {
        files.add(File(p.join(sourcePath, entry.value)));
      }
    }
  }
}

if (files.isEmpty) {
  throw Exception('Manifest must specify files to copy in the "files" key');
}
```

## Benefits

1. **Explicit Configuration**: No guessing about which files to copy
2. **Consistent Installs**: Same files copied every time based on manifest
3. **Management Separation**: CLI management files stay in registry
4. **Error Prevention**: Clear errors when manifest missing or misconfigured
5. **Documentation**: Manifest serves as documentation of skill structure
6. **Future-Proof**: Easy to extend with new manifest features

## Testing

The implementation includes comprehensive tests:

```bash
# Test manifest requirement
test('requires skill.json or skill.yaml manifest')

# Test YAML alternative
test('accepts skill.yaml as alternative to skill.json')

# Run all skill manager tests
dart test test/skill_manager_test.dart
```

All 13 skill manager tests pass ✓

## Migration Guide

If you have existing skills without manifests:

1. Create `skill.json` in your skill's root directory
2. Add the `files` configuration
3. List all files you want copied to AI model folders
4. Exclude management files and schemas

Example minimal manifest:
```json
{
  "id": "my-skill",
  "name": "My Skill",
  "version": "1.0.0",
  "files": {
    "main": "SKILL.md"
  }
}
```

## See Also

- [skill.json example](../shadcn_flutter_kit/flutter_shadcn_kit/skills/flutter-shadcn-ui/skill.json)
- [SkillManager implementation](lib/src/skill_manager.dart)
- [Test coverage](test/skill_manager_test.dart)
- [CHANGELOG](CHANGELOG.md)
