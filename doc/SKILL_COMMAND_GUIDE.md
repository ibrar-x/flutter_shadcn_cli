# install-skill Command - Complete Guide

## Overview

The `install-skill` command manages AI model skills for shadcn Flutter development. It automatically discovers AI model folders (`.claude/`, `.gpt4/`, `.cursor/`, etc.) and installs skill files to enable AI-assisted component development.

## Command Signature

```bash
flutter_shadcn install-skill [--skill <id>] [--model <name>] [options]
```

## What It Does

1. **Discovers AI Model Folders**: Automatically finds hidden folders starting with `.` in your project root (e.g., `.claude`, `.gpt4`, `.cursor`, `.gemini`)
2. **Copies Skill Files**: Installs skill documentation files from the registry to model-specific directories
3. **Manages Installations**: Lists, installs, updates, and removes skills per model
4. **Supports Symlinks**: Can install to one model and create symlinks for others (saves disk space)

## Installation Modes

### Interactive Mode (Recommended)

```bash
# Prompts for skill ID and shows model selection menu
flutter_shadcn install-skill
```

**Flow:**
1. Enter skill ID (e.g., `flutter-shadcn-ui`)
2. See numbered list of discovered AI models
3. Select models (comma-separated numbers or "all")
4. Choose installation mode (copy or symlink)

### Direct Installation

```bash
# Install to specific model
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .claude

# Install with interactive model selection
flutter_shadcn install-skill --skill flutter-shadcn-ui
```

### List Installed Skills

```bash
flutter_shadcn install-skill --list
```

**Output:**
```
📚 Installed Skills

  Shared Skills:
    (none)

  Model-Specific Skills:
    .claude:
      • flutter-shadcn-ui
    .cursor:
      • flutter-shadcn-ui
```

### Uninstall Skill

```bash
flutter_shadcn install-skill --uninstall flutter-shadcn-ui --model .claude
```

### Symlink Mode

```bash
# Install to .claude and create symlinks for other models
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .claude --symlink
```

This will:
1. Install skill files to `.claude/skills/flutter-shadcn-ui/`
2. Prompt to select target models for symlinks
3. Create symlinks: `.gpt4/skills/flutter-shadcn-ui` → `.claude/skills/flutter-shadcn-ui`

## Files Copied

Based on `skill.json` (which stays in registry for CLI management), the command copies:

- **SKILL.md** - Main skill docsumentation (AI instructions)
- **INSTALLATION.md** - Installation guide
- **README.md** - Skill overview (if exists)
- **references/commands.md** - CLI command reference
- **references/examples.md** - Usage examples

**Note:** Management files (`skill.json`, `skill.yaml`, `schemas.md`) remain in the source registry for CLI use and are NOT copied to model folders.

## Directory Structure

After installation:

```
your-project/
├── .claude/
│   └── skills/
│       └── flutter-shadcn-ui/
│           ├── SKILL.md
│           ├── INSTALLATION.md
│           └── references/
│               ├── commands.md
│               └── examples.md
├── .cursor/
│   └── skills/
│       └── flutter-shadcn-ui/  (symlink or copy)
└── lib/
    └── (your Flutter code)
```

## How It Finds Skills

The CLI searches for skill source files in this order:

1. **Local Kit Registry**: `shadcn_flutter_kit/flutter_shadcn_kit/skills/{skillId}/`
2. **Parent Directory Skills**: `../skills/{skillId}/` (traverses up)
3. **Project Root Skills**: `./skills/{skillId}/`
4. **Fallback**: Creates placeholder (if none found)

## Advanced Options

### Custom Skills URL

```bash
flutter_shadcn install-skill --skill my-skill --skills-url /path/to/skills
```

Override the default skill source location.

### Model Auto-Discovery

The CLI automatically detects these AI model folders:

- `.claude` - Claude AI (Anthropic)
- `.cursor` - Cursor AI
- `.gpt4` / `.chatgpt` - ChatGPT
- `.gemini` - Google Gemini
- `.cline` - Cline
- `.continue` - Continue
- `.windsurf` - Windsurf
- And 20+ more AI coding assistants

If a model folder doesn't exist, the CLI creates it automatically.

## Usage Examples

### Example 1: First-Time Installation

```bash
# Navigate to your Flutter project
cd my-flutter-app

# Install skill interactively
flutter_shadcn install-skill

# When prompted:
# 1. Enter: flutter-shadcn-ui
# 2. Select models (e.g., "1,3,5" for Claude, GPT-4, Cursor)
# 3. Choose: 1 (Copy to each model)
```

### Example 2: Install to Multiple Models with Symlinks

```bash
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .claude

# Then create symlinks
flutter_shadcn install-skill --skill flutter-shadcn-ui --symlink --model .claude
# Select target models when prompted
```

### Example 3: Verify Installation

```bash
# List all installed skills
flutter_shadcn install-skill --list

# Check files were copied
ls -la .claude/skills/flutter-shadcn-ui/
```

### Example 4: Update an Installed Skill

```bash
# Reinstall to update (overwrites existing files)
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .claude
```

### Example 5: Remove Skill

```bash
# Remove from specific model
flutter_shadcn install-skill --uninstall flutter-shadcn-ui --model .claude

# Verify removal
flutter_shadcn install-skill --list
```

## Integration with AI Models

After installation, AI models can access skill files to:

1. **Understand CLI Commands**: Reference complete command documentation
2. **Generate Components**: Follow best practices and patterns
3. **Debug Issues**: Use troubleshooting guides
4. **Configure Projects**: Apply theme presets and settings
5. **Resolve Dependencies**: Handle component dependencies correctly

## Skill Structure (skill.json)

The `skill.json` manifest defines which files to copy:

```json
{
  "id": "flutter-shadcn-ui",
  "name": "Flutter Shadcn UI",
  "version": "1.0.0",
  "files": {
    "main": "SKILL.md",
    "installation": "INSTALLATION.md",
    "readme": "README.md",
    "references": {
      "commands": "references/commands.md",
      "schemas": "references/schemas.md",
      "examples": "references/examples.md"
    }
  },
  "compatibility": {
    "aiModels": ["claude", "chatgpt", "cursor", "gemini", "any"],
    "platforms": ["ios", "android", "macos", "windows", "web", "linux"]
  }
}
```

## Troubleshooting

### Skill Not Found

**Error:** `Skill not found: flutter-shadcn-ui`

**Solution:**
```bash
# Ensure you're in a project with access to the kit registry
# Or specify custom skills path
flutter_shadcn install-skill --skill flutter-shadcn-ui --skills-url /path/to/registry/skills
```

### No Model Folders Detected

**Error:** `No AI model folders could be discovered or created`

**Solution:** The CLI will auto-create standard model folders. If this fails, manually create one:
```bash
mkdir .claude
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .claude
```

### Permission Denied

**Error:** `Permission denied` when creating directories

**Solution:**
```bash
# Ensure write permissions in project directory
chmod -R u+w .
```

### Symlink Already Exists

**Info:** `Symlink already exists: .cursor/skills/flutter-shadcn-ui`

This is normal - the skill is already linked. To refresh:
```bash
# Remove symlink
rm .cursor/skills/flutter-shadcn-ui
# Recreate
flutter_shadcn install-skill --skill flutter-shadcn-ui --symlink --model .claude
```

## Best Practices

1. **Use Symlinks for Multiple Models**: Save disk space when installing to many AI assistants
2. **Install Early**: Add skills before starting component development
3. **Update Regularly**: Reinstall skills when registry updates
4. **List Before Installing**: Check what's already installed with `--list`
5. **One Primary Model**: Install to one model, symlink to others

## Implementation Details

### File Copying Logic

The `skill_manager.dart` implementation:

1. Parses `skill.json` to get file list
2. Resolves source paths from local registry
3. Maintains directory structure during copy
4. Creates parent directories as needed
5. Logs each file copied for transparency

### Local Registry Search

Searches in order:
1. `shadcn_flutter_kit/flutter_shadcn_kit/skills/{skillId}`
2. Parent directories for `skills/{skillId}`
3. Project root `skills/{skillId}`
4. Falls back to placeholder

### Model Folder Discovery

- Lists all directories starting with `.` in project root
- Filters out `.git`, `.dart_tool`, etc.
- Merges with template list of known AI assistants
- Auto-creates missing folders

## Related Commands

- `flutter_shadcn init` - Initialize project (run before installing skills)
- `flutter_shadcn add <component>` - Install components (uses skill knowledge)
- `flutter_shadcn doctor` - Diagnose setup issues

## Version History

- **v0.1.8**: Added install-skill command with auto-discovery and symlink support
- **v0.1.9**: Enhanced local registry detection and file copying

## See Also

- [cli-skill-command.md](./cli-skill-command.md) - Detailed implementation guide
- [FULL_COMMANDS_DOCS.md](./FULL_COMMANDS_DOCS.md) - All CLI commands
- [SKILL.md](../shadcn_flutter_kit/flutter_shadcn_kit/skills/flutter-shadcn-ui/SKILL.md) - The actual skill content
