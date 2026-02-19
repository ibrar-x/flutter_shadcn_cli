# info

## Purpose
Show detailed component info from index.json.

## Syntax

```bash
flutter_shadcn info <component-id> [--refresh] [--json]
flutter_shadcn info @<namespace>/<component-id> [--refresh] [--json]
```

## Options

- `--refresh`: Refresh cache from remote.
- `--json`: Output machine-readable JSON (pretty-printed).
- `--registry-name`: Resolve using a specific registry namespace.

## Global Flags

- `--offline`: Disable network calls and use cached registry/index data only.

## Alias

- `i`

## JSON Output

```bash
flutter_shadcn info button --json
flutter_shadcn info @shadcn/button --json
```

Outputs a JSON object with the component metadata.
