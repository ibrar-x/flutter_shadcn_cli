import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_shadcn_cli/src/logger.dart';

class CommandDocMeta {
  final String name;
  final String description;
  final List<String> aliases;

  const CommandDocMeta({
    required this.name,
    required this.description,
    this.aliases = const [],
  });
}

const _commandDocs = <CommandDocMeta>[
  CommandDocMeta(name: 'init', description: 'Initialize the project.'),
  CommandDocMeta(name: 'add', description: 'Install components.'),
  CommandDocMeta(
      name: 'remove',
      description: 'Remove installed components.',
      aliases: ['rm']),
  CommandDocMeta(
      name: 'dry-run', description: 'Preview what would be installed.'),
  CommandDocMeta(name: 'assets', description: 'Install font/icon assets.'),
  CommandDocMeta(
      name: 'platform', description: 'Manage platform target files.'),
  CommandDocMeta(
      name: 'registries', description: 'List available/configured registries.'),
  CommandDocMeta(
      name: 'default', description: 'Set or show default registry namespace.'),
  CommandDocMeta(name: 'theme', description: 'Manage theme presets.'),
  CommandDocMeta(
      name: 'sync', description: 'Sync paths and theme from config.'),
  CommandDocMeta(name: 'doctor', description: 'Registry diagnostics.'),
  CommandDocMeta(name: 'validate', description: 'Validate registry integrity.'),
  CommandDocMeta(name: 'audit', description: 'Audit installed components.'),
  CommandDocMeta(
      name: 'deps', description: 'Compare registry deps vs pubspec.'),
  CommandDocMeta(
      name: 'list', description: 'List available components.', aliases: ['ls']),
  CommandDocMeta(name: 'search', description: 'Search for components.'),
  CommandDocMeta(
      name: 'info', description: 'Show component details.', aliases: ['i']),
  CommandDocMeta(name: 'install-skill', description: 'Install AI skills.'),
  CommandDocMeta(name: 'version', description: 'Show CLI version.'),
  CommandDocMeta(
      name: 'upgrade', description: 'Upgrade CLI to latest version.'),
  CommandDocMeta(name: 'feedback', description: 'Submit feedback.'),
  CommandDocMeta(name: 'docs', description: 'Regenerate documentation site.'),
];

Future<void> generateDocsSite({
  required String cliRoot,
  required CliLogger logger,
}) async {
  final siteRoot = Directory(p.join(cliRoot, 'doc', 'site'));
  final commandsDir = Directory(p.join(siteRoot.path, 'commands'));
  if (!siteRoot.existsSync()) {
    logger.warn('Docs site not found at ${siteRoot.path}');
    return;
  }
  if (!commandsDir.existsSync()) {
    commandsDir.createSync(recursive: true);
  }

  for (final command in _commandDocs) {
    final docPath = p.join(commandsDir.path, '${command.name}.md');
    final file = File(docPath);
    if (!file.existsSync()) {
      final aliasLine = command.aliases.isNotEmpty
          ? '\n## Alias\n\n- ${command.aliases.join(', ')}\n'
          : '';
      file.writeAsStringSync(
        '# ${command.name}\n\n'
        '## Purpose\n${command.description}\n\n'
        '## Syntax\n\n'
        '```bash\n'
        'flutter_shadcn ${command.name}\n'
        '```\n'
        '$aliasLine',
      );
      logger.info('Created ${file.path}');
    }
  }

  final indexPath = p.join(commandsDir.path, 'index.md');
  final indexLines = <String>[
    '# Command Reference',
    '',
    'Each command is documented with purpose, syntax, options, behavior flow, files used, and examples.',
    '',
  ];
  final aliasNotes = _commandDocs
      .where((c) => c.aliases.isNotEmpty)
      .map((c) => '${c.aliases.join(', ')} → ${c.name}')
      .toList();
  if (aliasNotes.isNotEmpty) {
    indexLines.add('Aliases: ${aliasNotes.join(', ')}.');
    indexLines.add('');
  }
  for (final command in _commandDocs) {
    indexLines.add('- [${command.name}](${command.name}.md)');
  }
  File(indexPath).writeAsStringSync(indexLines.join('\n'));

  logger.success('Docs site regenerated.');
}
