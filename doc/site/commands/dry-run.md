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

## Behavior Details

- Computes dependency graph
- Shows shared items, assets, fonts, and platform changes

## Examples

```bash
flutter_shadcn dry-run button
flutter_shadcn dry-run --all
```

JSON output:

```bash
flutter_shadcn dry-run button --json
```
