# assets

## Purpose
Install icon or typography assets.

## Syntax

```bash
flutter_shadcn assets [--icons|--fonts|--typography|--all]
```

## Options

- `--icons`: install icon font assets
- `--fonts` or `--typography`: install typography fonts
- `--all`: install everything

## Behavior Details

- Tries inline registry actions first (from `registries.json`) for selected/default namespace.
- Falls back to legacy component installs (`icon_fonts`, `typography_fonts`) when no inline asset actions match.
- Writes and tracks inline execution records for rollback.

## Examples

```bash
flutter_shadcn assets --icons
flutter_shadcn assets --fonts
flutter_shadcn assets --all
```
