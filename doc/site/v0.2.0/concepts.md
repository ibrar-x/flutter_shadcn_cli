# Core Concepts

## Registry

The registry defines what components exist and which files they need. The CLI can load a local registry (for development) or a remote registry (for production).

## Install Path and Shared Path

- Install path: where components and composites are copied under `lib/`
- Shared path: where shared helpers are copied under `lib/`

Defaults are taken from `components.json` unless overridden in `.shadcn/config.json`.

## Config and State

- `.shadcn/config.json` stores user preferences (paths, flags, registry mode)
- `.shadcn/state.json` tracks managed dependencies and sync metadata

## Manifests

- `<installPath>/components.json` tracks installed components and metadata (version/tags)
- `.shadcn/components/<id>.json` tracks per-component install metadata

## Schema Validation

`components.json` is validated against `components.schema.json` (or `$schema` if provided) to ensure consistency.

## JSON Output

Commands that support `--json` return a standardized envelope:

- `status`: `ok` or `error`
- `command`: command name
- `data`: command-specific payload
- `errors`: list of structured errors
- `warnings`: list of structured warnings
- `meta`: metadata (timestamp, exitCode)

## Exit Codes

Common exit codes:

- `2` usage error
- `10` registry not found
- `20` schema invalid
- `30` component missing
- `31` file missing
- `40` network error
- `41` offline cache unavailable
- `50` validation failed
- `60` config invalid
- `70` IO error

## Offline Mode

Use `--offline` to disable network calls and rely on cached registry/index data.
