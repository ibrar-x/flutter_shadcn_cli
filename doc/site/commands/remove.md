# remove

## Purpose
Remove installed components and clean up manifest entries.

## Syntax

```bash
flutter_shadcn remove <component> [options]
```

## Options

- `--all`: remove all components
- `--force`: remove even if dependents exist

## Alias

- `rm`

## Behavior Details

- Prevents removing components required by others unless `--force`
- Deletes component files
- Updates manifests and dependencies

## Flow

```mermaid
flowchart TD
  A[Start] --> B[Check dependents]
  B -->|blocked| C[Warn and exit]
  B -->|ok| D[Delete files]
  D --> E[Update manifests]
  E --> F[Sync dependencies]
```

## Examples

```bash
flutter_shadcn remove button
flutter_shadcn remove button --force
flutter_shadcn remove --all
```

## Common Errors

- Component required by others: use `--force` if safe
