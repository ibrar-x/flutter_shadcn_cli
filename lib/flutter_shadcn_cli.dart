/// CLI to install, sync, and update shadcn/ui components in Flutter apps.
///
/// This package provides command-line tools for managing shadcn_flutter
/// registry components in your Flutter projects. It supports:
///
/// - **Local + remote registry**: Auto-fallback between development and
///   production registries
/// - **Dependency-aware installs**: Automatically installs component
///   dependencies and updates pubspec.yaml
/// - **Interactive initialization**: Configure paths, themes, and optional
///   files
/// - **Component tracking**: Tracks installed components in a local manifest
///
/// ## Quick Start
///
/// ```bash
/// # Install the CLI
/// dart pub global activate flutter_shadcn_cli
///
/// # Initialize in your Flutter project
/// flutter_shadcn init
///
/// # Add components
/// flutter_shadcn add button dialog
/// ```
///
/// See the [README](https://pub.dev/packages/flutter_shadcn_cli) for full
/// documentation.
library flutter_shadcn_cli;

export 'registry/shared/theme/preset_theme_data.dart';
