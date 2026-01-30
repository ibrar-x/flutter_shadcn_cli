/// Example usage of flutter_shadcn_cli.
///
/// This CLI is designed to be run from the command line, not imported
/// as a library. Below are the common commands you'll use.
///
/// ## Installation
///
/// ```bash
/// dart pub global activate flutter_shadcn_cli
/// ```
///
/// ## Initialize a project
///
/// Run this in your Flutter project root:
///
/// ```bash
/// flutter_shadcn init
/// ```
///
/// Or with all options:
///
/// ```bash
/// flutter_shadcn init \
///   --yes \
///   --install-path ui/shadcn \
///   --shared-path ui/shadcn/shared \
///   --theme blue
/// ```
///
/// ## Add components
///
/// ```bash
/// # Add a single component
/// flutter_shadcn add button
///
/// # Add multiple components
/// flutter_shadcn add button dialog accordion
///
/// # Add all components
/// flutter_shadcn add --all
/// ```
///
/// ## Remove components
///
/// ```bash
/// flutter_shadcn remove button
/// flutter_shadcn remove --all
/// ```
///
/// ## Check project status
///
/// ```bash
/// flutter_shadcn doctor
/// ```
///
/// ## Using theme presets programmatically
///
/// If you need to access theme data in your code:
library example;

import 'package:flutter_shadcn_cli/flutter_shadcn_cli.dart';

void main() {
  // List all available theme presets
  for (final preset in registryThemePresetsData) {
    print('Theme: ${preset.name} (${preset.id})');
    print('  Light primary: ${preset.light['primary']}');
    print('  Dark primary: ${preset.dark['primary']}');
  }

  // Find a specific theme
  final blueTheme = registryThemePresetsData.firstWhere(
    (preset) => preset.id == 'blue',
  );

  print('\nBlue theme colors:');
  print('  Background (light): ${blueTheme.light['background']}');
  print('  Background (dark): ${blueTheme.dark['background']}');
}
