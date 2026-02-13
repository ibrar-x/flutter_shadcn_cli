# audit

## Purpose
Audit installed components against registry metadata and local files.

## Syntax

```bash
flutter_shadcn audit [--json]
```

## Options

- `--json`: Output machine-readable JSON (pretty-printed).

## What It Checks

- Installed component manifests vs registry versions/tags.
- Missing component files on disk.
- Missing per-component manifests.

## JSON Output

```bash
flutter_shadcn audit --json
```

Returns the standard JSON envelope with mismatches and missing files.

## Exit Codes

- `50` validation failed (missing files or registry mismatches)
