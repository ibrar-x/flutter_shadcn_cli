> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

# add (Legacy v0.1.9)

## Syntax

```bash
flutter_shadcn add <component> [more...] [--all]
```

## Behavior

- Installs components from the configured single registry.
- Resolves `dependsOn` and shared dependencies.
- Uses legacy optional file booleans from config:
  - `includeReadme`
  - `includePreview`
  - `includeMeta`
- Does not require namespace-qualified addressing.

## Examples

```bash
flutter_shadcn add button
flutter_shadcn add button dialog
flutter_shadcn add --all
```
