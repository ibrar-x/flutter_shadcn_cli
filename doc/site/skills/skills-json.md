# skills.json Discovery

`skills.json` is an index of installable skills, similar to `index.json` for components.

## Format

- `schemaVersion`
- `generatedAt`
- `skills[]`: list of skill metadata

## Example

```json
{
  "schemaVersion": 1,
  "skills": [
    {
      "id": "flutter-shadcn-ui",
      "name": "Flutter Shadcn UI",
      "version": "1.0.0",
      "path": "flutter-shadcn-ui",
      "manifest": "flutter-shadcn-ui/skill.json"
    }
  ]
}
```

## Usage

```bash
flutter_shadcn install-skill --available
```
