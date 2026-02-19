> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

# Skill Manifest (skill.json/skill.yaml)

The `install-skill` command requires a manifest to decide which files to copy.

## Required

- `id`, `name`, `version`
- `files` object

## files Key

Defines which files are copied into model folders:

```json
{
  "files": {
    "main": "SKILL.md",
    "installation": "INSTALLATION.md",
    "references": {
      "commands": "references/commands.md",
      "examples": "references/examples.md"
    }
  }
}
```

## Errors

- Missing manifest
- Manifest with no files
