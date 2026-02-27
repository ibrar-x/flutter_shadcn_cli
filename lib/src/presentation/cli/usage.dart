import 'package:flutter_shadcn_cli/src/presentation/cli/command_registry.dart';

void printCliUsage() {
  print('');
  print('flutter_shadcn CLI');
  print('Usage: flutter_shadcn <command> [arguments]');
  print('');

  for (final category in cliCommandCategories) {
    _printUsageSection(
      category.name,
      category.commands.map((entry) => MapEntry(entry.id, entry.description)).toList(),
    );
  }

  print('Global flags');
  _printUsageFlagSection('General', const [
    MapEntry('--verbose', 'Verbose logging'),
    MapEntry('--offline', 'Disable network calls (use cache only)'),
    MapEntry('--wip', 'Enable WIP features'),
    MapEntry('--experimental', 'Enable experimental features'),
  ]);

  _printUsageFlagSection('Registry Selection', const [
    MapEntry('--registry', 'auto|local|remote (default: auto)'),
    MapEntry('--registry-name', 'Registry namespace (e.g. shadcn)'),
    MapEntry('--registry-path', 'Path to local registry folder'),
    MapEntry('--registry-url', 'Remote registry base URL'),
    MapEntry('--registries-url', 'Remote registries.json URL'),
    MapEntry('--registries-path', 'Local registries.json file/directory path'),
  ]);

  _printUsageFlagSection('Dev Mode', const [
    MapEntry('--dev', 'Persist local registry for dev mode'),
    MapEntry('--dev-path', 'Local registry path to persist for dev mode'),
  ]);

  print('');
}

void _printUsageSection(String title, List<MapEntry<String, String>> commands) {
  print(title);
  for (final entry in commands) {
    print(_formatUsageRow(entry.key, entry.value));
  }
  print('');
}

void _printUsageFlagSection(
  String title,
  List<MapEntry<String, String>> flags,
) {
  print('  $title:');
  for (final entry in flags) {
    print(_formatUsageRow(entry.key, entry.value, indent: '    '));
  }
  print('');
}

String _formatUsageRow(
  String name,
  String description, {
  String indent = '  ',
}) {
  const width = 24;
  final paddedName =
      name.length >= width ? '$name ' : name.padRight(width, ' ');
  return '$indent$paddedName$description';
}
