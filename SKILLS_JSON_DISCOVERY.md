# Skills.json Discovery & Interactive Installation

## Overview

The CLI now supports:
1. **skills.json index** - Like `index.json` for components, but for skills
2. **Interactive multi-skill installation** - Install multiple skills at once
3. **Human-readable AI model names** - "Cursor" instead of ".cursor"

## skills.json Format

Location: `{registry}/skills/skills.json`

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-02-04",
  "scope": "cli-registry",
  "description": "Canonical index of installable skills for flutter_shadcn CLI.",
  "skills": [
    {
      "id": "flutter-shadcn-ui",
      "name": "Flutter Shadcn UI",
      "version": "1.0.0",
      "description": "Build beautiful, production-ready Flutter UI components.",
      "status": "stable",
      "category": "ui-development",
      "path": "flutter-shadcn-ui",
      "entry": "flutter-shadcn-ui/SKILL.md",
      "manifest": "flutter-shadcn-ui/skill.json",
      "installation": {
        "supportedByCli": true
      }
    }
  ]
}
```

## AI Model Display Names

| Folder Name | Display Name |
|------------|--------------|
| `.claude` | Claude (Anthropic) |
| `.codex` | Codex (OpenAI) |
| `.cursor` | Cursor |
| `.gemini` | Gemini (Google) |
| `.gpt4` | GPT-4 (OpenAI) |
| _(and 25+ more)_ | |

## New Commands

### List Available Skills
```bash
flutter_shadcn install-skill --available
# or
flutter_shadcn install-skill -a
```

**Output:**
```
📚 Available Skills

  1. Flutter Shadcn UI (flutter-shadcn-ui)
     Build beautiful, production-ready Flutter UI components.
     Version: 1.0.0 | Status: stable

✓ 1 skills available.
```

### Interactive Multi-Skill Installation
```bash
flutter_shadcn install-skill --interactive
# or
flutter_shadcn install-skill -i
```

**Output:**
```
📚 Available Skills
  1. Flutter Shadcn UI - Build beautiful, production-ready Flutter UI components.
  2. All skills

Select skills to install (comma-separated numbers, or 2 for all): 1

🤖 Target AI Models
  1. Cursor
  2. Claude (Anthropic)
  3. Codex (OpenAI)
  4. Gemini (Google)
  5. All models

Select models (comma-separated numbers, or 5 for all): 1,2

🎯 Installing Skill: flutter-shadcn-ui
✓ ✓ Copied 4 skill files
✓ ✓ Skill "flutter-shadcn-ui" installed for model: .cursor

🎯 Installing Skill: flutter-shadcn-ui
✓ ✓ Copied 4 skill files
✓ ✓ Skill "flutter-shadcn-ui" installed for model: .claude

✓ Installed 1 skill(s) to 2 model(s)
```

### Traditional Single Skill Install (Now with Readable Names)
```bash
flutter_shadcn install-skill --skill flutter-shadcn-ui
```

**Output:**
```
🎯 Installing Skill: flutter-shadcn-ui
Available AI models:
  1. Cursor
  2. Claude (Anthropic)
  3. Codex (OpenAI)
  4. Gemini (Google)
  5. All models

Select models (comma-separated numbers, or 5 for all): 1

✓ ✓ Copied 4 skill files
✓ ✓ Skill "flutter-shadcn-ui" installed for model: .cursor
```

## Benefits

### Before (Folder Names)
```
Available AI models:
  1. .claude
  2. .codex
  3. .cursor
  4. .gemini
```

### After (Readable Names)
```
Available AI models:
  1. Claude (Anthropic)
  2. Codex (OpenAI)
  3. Cursor
  4. Gemini (Google)
```

## Implementation Details

### SkillsLoader
Similar to `IndexLoader` for components:
- Searches for `skills.json` in registry
- Parses skill entries with metadata
- Returns `SkillsIndex` object

### Display Name Mapping
```dart
const Map<String, String> aiModelDisplayNames = {
  '.claude': 'Claude (Anthropic)',
  '.codex': 'Codex (OpenAI)',
  '.cursor': 'Cursor',
  '.gemini': 'Gemini (Google)',
  // ... 30+ models
};
```

### New Methods in SkillManager

1. **`listAvailableSkills()`**
   - Loads skills.json
   - Shows all available skills with descriptions
   - Similar to `flutter_shadcn list` for components

2. **`installSkillsInteractive()`**
   - Multi-skill selection from skills.json
   - Multi-model selection
   - Batch installation

3. **Updated `installSkillInteractive()`**
   - Now shows readable model names
   - Uses `aiModelDisplayNames` mapping

## Workflow Comparison

### Components (index.json)
```bash
flutter_shadcn list        # Browse from index.json
flutter_shadcn search      # Search index.json
flutter_shadcn add button  # Install from components.json
```

### Skills (skills.json)
```bash
flutter_shadcn install-skill --available    # Browse from skills.json
flutter_shadcn install-skill --interactive  # Multi-install from skills.json
flutter_shadcn install-skill --skill <id>   # Install from skill.json manifest
```

## Files Structure

```
skills/
├── skills.json              ← Discovery index (like index.json)
└── flutter-shadcn-ui/
    ├── skill.json           ← Installation manifest (like components.json)
    ├── SKILL.md
    ├── INSTALLATION.md
    ├── README.md
    └── references/
        ├── commands.md
        ├── examples.md
        └── schemas.md       ← Excluded from AI model folders
```

## Usage Examples

### Quick Discovery
```bash
# See what's available
flutter_shadcn install-skill -a
```

### Interactive Installation
```bash
# Install multiple skills to multiple models
flutter_shadcn install-skill -i
# Follow prompts:
#  1. Select skills (1,2,3 or "all")
#  2. Select models (shows readable names)
#  3. Installs selected combinations
```

### Direct Installation
```bash
# Install specific skill to specific model
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .cursor
```

## Testing

The implementation includes:
- ✅ skills.json parsing and validation
- ✅ AI model display name mapping
- ✅ Multi-skill interactive flow
- ✅ Integration with existing skill manager
- ✅ Error handling for missing skills.json
- ✅ Fallback to folder names if display name not found

## Migration Notes

**No breaking changes** - All existing commands work as before, just enhanced:
- Model names now show as "Cursor" instead of ".cursor"
- New optional flags (`--available`, `--interactive`)
- skills.json is optional - CLI works without it
