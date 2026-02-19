# list

## Purpose
List available components using index.json.

## Syntax

```bash
flutter_shadcn list [--refresh] [--json]
flutter_shadcn list @<namespace> [--refresh] [--json]
```

## Options

- `--refresh`: Refresh cache from remote.
- `--json`: Output machine-readable JSON (pretty-printed).

## Global Flags

- `--offline`: Disable network calls and use cached registry/index data only.

## Alias

- `ls`

## JSON Output

```bash
flutter_shadcn list --json
```

Outputs a JSON object with `components` and registry metadata.
