> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

# platform

## Purpose
Configure platform target file paths for platform-specific changes.

## Syntax

```bash
flutter_shadcn platform [--set key=value] [--reset key] [--list]
```

## Options

- `--set`: set a platform target path
- `--reset`: remove override
- `--list`: show targets

## Examples

```bash
flutter_shadcn platform --list
flutter_shadcn platform --set ios.infoPlist=ios/Runner/Info.plist
```
