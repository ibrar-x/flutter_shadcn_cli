> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

# dry-run

## Purpose
Preview installation steps without writing files.

## Syntax

```bash
flutter_shadcn dry-run <component> [--json]
flutter_shadcn dry-run --all [--json]
```

## Options

- `--all`: Preview all components.
- `--json`: Output machine-readable JSON (pretty-printed).

## Global Flags

- `--offline`: Disable network calls and use cached registry data only.

## Behavior Details

- Computes dependency graph
- Shows shared items, assets, fonts, and platform changes
- Includes per-file destinations
- Includes per-component manifest preview

## Examples

```bash
flutter_shadcn dry-run button
flutter_shadcn dry-run --all
```

JSON output:

```bash
flutter_shadcn dry-run button --json
```
