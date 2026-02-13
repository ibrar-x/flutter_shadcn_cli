# docs

## Purpose
Regenerate the web-friendly documentation site under `/doc/site`.

## Syntax

```bash
flutter_shadcn docs [--generate]
```

## Options

- `--generate, -g`: Regenerate the documentation site (default).

## Behavior Details

- Ensures command docs exist for every CLI command.
- Rebuilds `doc/site/commands/index.md` from command metadata.

## Exit Codes

- `70` IO error (unable to write docs)
