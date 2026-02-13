# validate

## Purpose
Validate registry integrity and schema correctness.

## Syntax

```bash
flutter_shadcn validate [--json]
```

## Options

- `--json`: Output machine-readable JSON (pretty-printed).
- `--offline`: Disable network calls and use cached registry data only.

## What It Checks

- `components.json` matches JSON Schema.
- Each `files.source` path exists in the registry.
- Each `dependsOn` component id exists.
- Each `files.dependsOn` path exists (required vs optional).

## JSON Output

```bash
flutter_shadcn validate --json
```

Returns the standard JSON envelope with schema errors, missing files, and dependency issues.

## Exit Codes

- `20` schema invalid
- `30` component missing
- `31` file missing
- `41` offline cache unavailable
- `50` validation failed (multiple categories)
