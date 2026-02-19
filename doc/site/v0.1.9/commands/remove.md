> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

# remove (Legacy v0.1.9)

## Syntax

```bash
flutter_shadcn remove <component> [--force]
flutter_shadcn remove --all
```

## Behavior

- Removes installed components from the single registry install tree.
- Blocks removal if dependents exist unless `--force` is provided.
- Updates manifests and dependency state.
