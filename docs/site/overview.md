# Overview

`flutter_shadcn_cli` is a CLI installer that copies shadcn Flutter components and shared helpers into a Flutter project. It supports local registries (for development) and remote registries (for production/consumption). It manages dependencies, applies themes, and tracks installed components.

## What It Does

- Initializes a project with shared helpers and config
- Installs components and their dependencies
- Updates `pubspec.yaml` dependencies in batches
- Applies theme presets to `color_scheme.dart`
- Tracks installed components and per-component manifests
- Provides discovery (list/search/info) and skill installation

## What It Does Not Do

- It does not compile or build your Flutter app
- It does not rewrite component source code beyond copying files
- It does not manage your Git state

## Typical Workflow

1. `flutter_shadcn init`
2. `flutter_shadcn add button`
3. `flutter_shadcn sync` (if config changes)
4. `flutter_shadcn remove button` (if needed)
