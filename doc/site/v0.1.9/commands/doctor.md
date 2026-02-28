> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

# doctor

## Purpose
Run diagnostics for registry resolution and schema validation.

## Syntax

```bash
flutter_shadcn doctor [--json]
```

## Checks

- Registry resolution (local/remote)
- Schema validation status
- Config path validity (install/shared)
- Missing `color_scheme.dart`
- Alias path validity

## Options

- `--json`: Output machine-readable JSON (pretty-printed).

## Global Flags

- `--offline`: Disable network calls and use cached registry data only.

## JSON Output

```bash
flutter_shadcn doctor --json
```

Outputs environment, registry resolution details, schema status, and platform targets.
