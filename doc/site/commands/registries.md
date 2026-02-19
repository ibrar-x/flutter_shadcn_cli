# registries

## Purpose
List configured and discoverable registries.

## Syntax

```bash
flutter_shadcn registries
flutter_shadcn registries --json
```

## Options

- `--json`: Output machine-readable JSON.

## Behavior Details

- Reads `.shadcn/config.json` registries map when present.
- Merges directory-backed registries from `registries.json` when available.
- Marks the current default namespace.
- Shows source (`config`, `directory`, or `config+directory`) and enablement state.

## Examples

```bash
flutter_shadcn registries
flutter_shadcn registries --json --offline
```
