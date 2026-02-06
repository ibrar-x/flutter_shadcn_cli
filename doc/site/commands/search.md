# search

## Purpose
Search components by name, description, and tags.

## Syntax

```bash
flutter_shadcn search <query> [--refresh] [--json]
```

## Options

- `--refresh`: Refresh cache from remote.
- `--json`: Output machine-readable JSON (pretty-printed).

## JSON Output

```bash
flutter_shadcn search button --json
```

Outputs a JSON object with `results` and relevance scores.
