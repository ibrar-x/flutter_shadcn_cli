import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Command matrix', () {
    late Directory tempRoot;
    late Directory appRoot;
    late Directory legacyRegistryBase;
    late String packageRoot;
    late String cliEntrypoint;

    setUp(() {
      packageRoot = Directory.current.path;
      cliEntrypoint = p.join(packageRoot, 'bin', 'shadcn.dart');
      tempRoot = Directory.systemTemp.createTempSync('shadcn_cmd_matrix_');
      appRoot = Directory(p.join(tempRoot.path, 'app'))..createSync();
      legacyRegistryBase = Directory(p.join(tempRoot.path, 'legacy_registry'))
        ..createSync();
      _writePubspec(appRoot);
      _writeMinimalRegistry(legacyRegistryBase);
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('documented command set stays in sync', () {
      final docsCommands = _loadDocCommandIds(packageRoot);
      expect(
        docsCommands,
        unorderedEquals(_documentedCliCommands),
      );
      expect(
          File(p.join(packageRoot, 'doc', 'site', 'commands', 'index.md'))
              .existsSync(),
          isTrue);
    });

    test('all documented commands resolve with --help', () async {
      final registryRoot = p.join(legacyRegistryBase.path, 'registry');
      final failures = <String>[];
      for (final command in _documentedCliCommands) {
        final result = await _runCli(
          cliEntrypoint: cliEntrypoint,
          cwd: appRoot.path,
          args: [
            '--offline',
            '--registry',
            'local',
            '--registry-path',
            registryRoot,
            command,
            '--help',
          ],
        );
        if (result.exitCode != 0) {
          failures.add(
            '$command => exit ${result.exitCode}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n\n'));
    });

    test('new registry commands resolve with --help', () async {
      for (final command in const ['registries', 'default']) {
        final result = await _runCli(
          cliEntrypoint: cliEntrypoint,
          cwd: appRoot.path,
          args: ['--offline', command, '--help'],
        );
        expect(
          result.exitCode,
          0,
          reason:
              '$command help failed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
      }
    });

    test('legacy config/state migrate and add shadcn:button', () async {
      _writeLegacyConfigAndState(
        packageRoot: packageRoot,
        appRoot: appRoot.path,
        registryPath: p.join(legacyRegistryBase.path, 'registry'),
      );
      final result = await _runCli(
        cliEntrypoint: cliEntrypoint,
        cwd: appRoot.path,
        args: ['--offline', 'add', 'shadcn:button'],
      );
      expect(
        result.exitCode,
        0,
        reason:
            'add shadcn:button failed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );

      final installed = File(
        p.join(
          appRoot.path,
          'lib',
          'ui',
          'shadcn',
          'components',
          'button',
          'button.dart',
        ),
      );
      expect(installed.existsSync(), isTrue);

      final migratedConfig = jsonDecode(
        File(p.join(appRoot.path, '.shadcn', 'config.json')).readAsStringSync(),
      ) as Map<String, dynamic>;
      final migratedState = jsonDecode(
        File(p.join(appRoot.path, '.shadcn', 'state.json')).readAsStringSync(),
      ) as Map<String, dynamic>;

      expect(migratedConfig['registries'], isA<Map>());
      expect(migratedState['registries'], isA<Map>());
      expect(
        migratedState['managedDependencies'],
        unorderedEquals(['gap', 'data_widget']),
      );
    });

    test('legacy config supports @namespace/component add syntax', () async {
      _writeLegacyConfigAndState(
        packageRoot: packageRoot,
        appRoot: appRoot.path,
        registryPath: p.join(legacyRegistryBase.path, 'registry'),
      );
      final result = await _runCli(
        cliEntrypoint: cliEntrypoint,
        cwd: appRoot.path,
        args: ['--offline', 'add', '@shadcn/button'],
      );
      expect(
        result.exitCode,
        0,
        reason:
            'add @shadcn/button failed\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );

      expect(
        File(
          p.join(
            appRoot.path,
            'lib',
            'ui',
            'shadcn',
            'components',
            'button',
            'button.dart',
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test('registry selector token works across command set', () async {
      final registryPath = p.join(legacyRegistryBase.path, 'registry');
      Directory(p.join(appRoot.path, '.shadcn')).createSync(recursive: true);
      File(p.join(appRoot.path, '.shadcn', 'config.json')).writeAsStringSync(
        jsonEncode({
          'defaultNamespace': 'orient_ui',
          'registries': {
            'shadcn': {
              'registryMode': 'local',
              'registryPath': registryPath,
              'installPath': 'lib/ui/shadcn',
              'sharedPath': 'lib/ui/shadcn/shared',
              'enabled': true
            },
            'orient_ui': {
              'registryMode': 'local',
              'registryPath': registryPath,
              'installPath': 'lib/ui/orient',
              'sharedPath': 'lib/ui/orient/shared',
              'enabled': true
            }
          }
        }),
      );

      final setup = await _runCli(
        cliEntrypoint: cliEntrypoint,
        cwd: appRoot.path,
        args: ['--offline', 'add', '@shadcn/button'],
      );
      expect(setup.exitCode, 0, reason: setup.stderr.toString());

      final commands = <List<String>>[
        ['--offline', 'list', '@shadcn', '--json'],
        ['--offline', 'search', '@shadcn', 'button', '--json'],
        ['--offline', 'theme', '@shadcn', '--list'],
        ['--offline', 'sync', '@shadcn'],
        ['--offline', 'validate', '@shadcn', '--json'],
        ['--offline', 'audit', '@shadcn', '--json'],
        ['--offline', 'deps', '@shadcn', '--json'],
        ['--offline', 'remove', '@shadcn/button', '--force'],
        [
          '--offline',
          'feedback',
          '@shadcn',
          '--type',
          'other',
          '--title',
          'registry context',
          '--body',
          'testing namespace context'
        ],
      ];

      final failures = <String>[];
      for (final args in commands) {
        final result = await _runCli(
          cliEntrypoint: cliEntrypoint,
          cwd: appRoot.path,
          args: args,
        );
        const invalidExitCodes = <int>{2, 10, 60};
        if (invalidExitCodes.contains(result.exitCode)) {
          failures.add(
            '${args.join(" ")} => exit ${result.exitCode}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n\n'));
    });
  });
}

const List<String> _documentedCliCommands = <String>[
  'add',
  'assets',
  'audit',
  'default',
  'deps',
  'docs',
  'doctor',
  'dry-run',
  'feedback',
  'info',
  'init',
  'install-skill',
  'list',
  'platform',
  'registries',
  'remove',
  'search',
  'sync',
  'theme',
  'upgrade',
  'validate',
  'version',
];

List<String> _loadDocCommandIds(String packageRoot) {
  final dir = Directory(p.join(packageRoot, 'doc', 'site', 'commands'));
  if (!dir.existsSync()) {
    throw StateError('Missing docs command directory: ${dir.path}');
  }
  final ids = dir
      .listSync()
      .whereType<File>()
      .map((file) => p.basenameWithoutExtension(file.path))
      .where((name) => name != 'index')
      .toList()
    ..sort();
  return ids;
}

void _writeLegacyConfigAndState({
  required String packageRoot,
  required String appRoot,
  required String registryPath,
}) {
  final oldConfig = jsonDecode(
    File(p.join(packageRoot, 'test', 'fixtures', 'old_config.json'))
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  oldConfig['registryMode'] = 'local';
  oldConfig['registryPath'] = registryPath;

  final shadcnDir = Directory(p.join(appRoot, '.shadcn'))..createSync();
  File(p.join(shadcnDir.path, 'config.json'))
      .writeAsStringSync(jsonEncode(oldConfig));
  File(p.join(shadcnDir.path, 'state.json')).writeAsStringSync(
    File(p.join(packageRoot, 'test', 'fixtures', 'old_state.json'))
        .readAsStringSync(),
  );
}

Future<ProcessResult> _runCli({
  required String cliEntrypoint,
  required String cwd,
  required List<String> args,
}) {
  return Process.run(
    Platform.resolvedExecutable,
    [cliEntrypoint, ...args],
    workingDirectory: cwd,
    environment: {
      ...Platform.environment,
      'CI': 'true',
    },
  );
}

void _writePubspec(Directory appRoot) {
  File(p.join(appRoot.path, 'pubspec.yaml')).writeAsStringSync(
    [
      'name: command_matrix_app',
      'environment:',
      '  sdk: ">=3.0.0 <4.0.0"',
      'dependencies:',
      '  flutter:',
      '    sdk: flutter',
    ].join('\n'),
  );
}

void _writeMinimalRegistry(Directory baseDir) {
  final registryRoot = Directory(p.join(baseDir.path, 'registry'))
    ..createSync(recursive: true);
  final componentDir = Directory(
    p.join(baseDir.path, 'registry', 'components', 'button'),
  )..createSync(recursive: true);
  File(p.join(componentDir.path, 'button.dart'))
      .writeAsStringSync('class Button {}');
  File(p.join(registryRoot.path, 'components.json')).writeAsStringSync(
    jsonEncode({
      'schemaVersion': 1,
      'name': 'legacy_registry',
      'flutter': {'minSdk': '3.0.0'},
      'defaults': {
        'installPath': 'lib/ui/shadcn',
        'sharedPath': 'lib/ui/shadcn/shared',
      },
      'shared': [],
      'components': [
        {
          'id': 'button',
          'name': 'Button',
          'description': 'button',
          'category': 'core',
          'files': [
            {
              'source': 'registry/components/button/button.dart',
              'destination': '{installPath}/components/button/button.dart',
            }
          ],
          'shared': [],
          'dependsOn': [],
          'pubspec': {
            'dependencies': {},
          },
          'assets': [],
          'postInstall': [],
        }
      ],
    }),
  );
  File(p.join(registryRoot.path, 'index.json')).writeAsStringSync(
    jsonEncode({
      'components': [
        {
          'id': 'button',
          'name': 'Button',
          'category': 'core',
          'description': 'button',
          'tags': ['core'],
          'install': 'flutter_shadcn add button',
          'import': 'package:test_app/ui/shadcn/components/button/button.dart',
          'importPath': 'ui/shadcn/components/button/button.dart',
          'api': {},
          'examples': {},
          'dependencies': {},
          'related': [],
        }
      ]
    }),
  );
}
