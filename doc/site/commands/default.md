# default

## Purpose
Set or show default registry namespace.

## Syntax

```bash
flutter_shadcn default
flutter_shadcn default <namespace>
```

## Behavior Details

- With no argument, prints current default namespace.
- With `<namespace>`, updates `.shadcn/config.json` `defaultNamespace`.
- If namespace exists only in the registries directory, it is imported into config before being set as default.

## Examples

```bash
flutter_shadcn default
flutter_shadcn default shadcn
flutter_shadcn default orient
```
