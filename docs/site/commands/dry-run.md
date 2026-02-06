# dry-run

## Purpose
Preview installation steps without writing files.

## Syntax

```bash
flutter_shadcn dry-run <component> [options]
```

## Options

- `--all`: preview all components

## Behavior Details

- Computes dependency graph
- Shows shared items, assets, fonts, and platform changes

## Examples

```bash
flutter_shadcn dry-run button
flutter_shadcn dry-run --all
```
