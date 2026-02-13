# deps

## Purpose
Compare registry dependency requirements with the project's `pubspec.yaml`.

## Syntax

```bash
flutter_shadcn deps [--all] [--json]
```

## Options

- `--all, -a`: Compare all registry components (default is installed components).
- `--json`: Output machine-readable JSON (pretty-printed).

## JSON Output

```bash
flutter_shadcn deps --json
```

Returns the standard JSON envelope with dependency status (ok/missing/mismatch).

## Exit Codes

- `50` validation failed (missing or mismatched deps)
