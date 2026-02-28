# Getting Started (v0.2.0)

## Install

```bash
dart pub global activate flutter_shadcn_cli
```

## Initialize

```bash
flutter_shadcn init --yes
```

Namespace bootstrap from directory inline init:

```bash
flutter_shadcn init shadcn
```

## Install Components

Default namespace / enabled registry resolution:

```bash
flutter_shadcn add button
```

Explicit namespace selection:

```bash
flutter_shadcn add @shadcn/button
flutter_shadcn add orient_ui:card
```

Optional file filters:

```bash
flutter_shadcn add @shadcn/button --include-files=preview
flutter_shadcn add @shadcn/button --exclude-files=readme,meta
```

## Registry Management

```bash
flutter_shadcn registries
flutter_shadcn default shadcn
```

## Migration Reference

- Legacy docs: [v0.1.9](../v0.1.9/README.md)
