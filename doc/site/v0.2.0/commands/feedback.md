# feedback

## Purpose
Submit feedback or bug reports via GitHub.

## Syntax

```bash
flutter_shadcn feedback [--type ... --title ... --body ...]
flutter_shadcn feedback @<namespace> [--type ... --title ... --body ...]
```

## Notes

- `@<namespace>` is optional and adds registry context to the generated feedback issue.
- Generated issue bodies include:
  - pre-issue checklist
  - dynamic environment context (CLI version, OS, Dart, UTC report date)
  - optional registry namespace and URL/path context
