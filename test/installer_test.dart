import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/installer.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';

void main() {
  group('Installer', () {
    late Directory tempRoot;
    late Directory registryRoot;
    late Directory targetRoot;

    setUp(() async {
      tempRoot = Directory.systemTemp.createTempSync('shadcn_cli_test_');
      registryRoot = Directory(p.join(tempRoot.path, 'registry'))..createSync();
      targetRoot = Directory(p.join(tempRoot.path, 'app'))..createSync();
      _writeRegistryFixtures(registryRoot);
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('installs component files with optional filters', () async {
      await _writeConfig(
        targetRoot,
        const ShadcnConfig(
          installPath: 'lib/ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeReadme: false,
          includeMeta: true,
          includePreview: false,
        ),
      );
      _writePubspec(targetRoot);

      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.addComponent('button');

      final installDir = p.join(
        targetRoot.path,
        'lib',
        'ui',
        'shadcn',
        'components',
        'button',
      );

      expect(File(p.join(installDir, 'button.dart')).existsSync(), isTrue);
      expect(File(p.join(installDir, 'meta.json')).existsSync(), isTrue);
      expect(File(p.join(installDir, 'README.md')).existsSync(), isFalse);
      expect(File(p.join(installDir, 'preview.dart')).existsSync(), isFalse);
    });

    test('supports @alias paths for install locations', () async {
      await _writeConfig(
        targetRoot,
        const ShadcnConfig(
          installPath: '@ui/shadcn',
          sharedPath: '@ui/shadcn/shared',
          includeMeta: true,
          pathAliases: {
            'ui': 'lib/ui',
          },
        ),
      );
      _writePubspec(targetRoot);

      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.addComponent('button');

      final installDir = p.join(
        targetRoot.path,
        'lib',
        'ui',
        'shadcn',
        'components',
        'button',
      );

      expect(File(p.join(installDir, 'button.dart')).existsSync(), isTrue);
    });

    test('adds missing dependencies to pubspec.yaml', () async {
      await _writeConfig(
        targetRoot,
        const ShadcnConfig(
          installPath: 'lib/ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeMeta: true,
        ),
      );
      _writePubspec(targetRoot, dependencies: const {'flutter': 'sdk: flutter'});

      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.addComponent('button');

      final pubspec = File(p.join(targetRoot.path, 'pubspec.yaml'))
          .readAsStringSync();
      expect(pubspec.contains('skeletonizer: ^2.1.0+1'), isTrue);

      await installer.addComponent('button');
      final pubspecAgain = File(p.join(targetRoot.path, 'pubspec.yaml'))
          .readAsStringSync();
      expect(pubspecAgain.contains('skeletonizer: ^2.1.0+1'), isTrue);
    });

    test('inserts dependencies when section missing', () async {
      await _writeConfig(
        targetRoot,
        const ShadcnConfig(
          installPath: 'lib/ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeMeta: true,
        ),
      );
      File(p.join(targetRoot.path, 'pubspec.yaml')).writeAsStringSync(
        'name: test_app\nversion: 1.0.0\n',
      );

      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.addComponent('button');

      final pubspec = File(p.join(targetRoot.path, 'pubspec.yaml'))
          .readAsStringSync();
      expect(pubspec.contains('dependencies:'), isTrue);
      expect(pubspec.contains('skeletonizer: ^2.1.0+1'), isTrue);
    });

    test('does not duplicate dependency present in dev_dependencies', () async {
      await _writeConfig(
        targetRoot,
        const ShadcnConfig(
          installPath: 'lib/ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeMeta: true,
        ),
      );
      File(p.join(targetRoot.path, 'pubspec.yaml')).writeAsStringSync(
        [
          'name: test_app',
          'environment:',
          '  sdk: ">=3.3.0 <4.0.0"',
          'dependencies:',
          '  flutter: sdk: flutter',
          'dev_dependencies:',
          '  skeletonizer: ^2.1.0+1',
        ].join('\n'),
      );

      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.addComponent('button');

      final pubspec = File(p.join(targetRoot.path, 'pubspec.yaml'))
          .readAsStringSync();
      final occurrences = RegExp('skeletonizer:').allMatches(pubspec).length;
      expect(occurrences, 1);
    });

    test('skips meta.json when includeMeta is false', () async {
      await _writeConfig(
        targetRoot,
        const ShadcnConfig(
          installPath: 'lib/ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeMeta: false,
        ),
      );
      _writePubspec(targetRoot);

      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.addComponent('button');

      final installDir = p.join(
        targetRoot.path,
        'lib',
        'ui',
        'shadcn',
        'components',
        'button',
      );

      expect(File(p.join(installDir, 'meta.json')).existsSync(), isFalse);
    });

    test('installs dependencies before component', () async {
      await _writeConfig(
        targetRoot,
        const ShadcnConfig(
          installPath: 'lib/ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeMeta: true,
        ),
      );
      _writePubspec(targetRoot);

      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.addComponent('dialog');

      final buttonFile = File(
        p.join(
          targetRoot.path,
          'lib',
          'ui',
          'shadcn',
          'components',
          'button',
          'button.dart',
        ),
      );
      final dialogFile = File(
        p.join(
          targetRoot.path,
          'lib',
          'ui',
          'shadcn',
          'components',
          'dialog',
          'dialog.dart',
        ),
      );

      expect(buttonFile.existsSync(), isTrue);
      expect(dialogFile.existsSync(), isTrue);
    });

    test('remove blocks when dependents exist', () async {
      await _writeConfig(
        targetRoot,
        const ShadcnConfig(
          installPath: 'lib/ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeMeta: true,
        ),
      );
      _writePubspec(targetRoot);

      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.addComponent('dialog');
      await installer.removeComponent('button');

      final buttonFile = File(
        p.join(
          targetRoot.path,
          'lib',
          'ui',
          'shadcn',
          'components',
          'button',
          'button.dart',
        ),
      );
      expect(buttonFile.existsSync(), isTrue);
    });

    test('force remove deletes component files', () async {
      await _writeConfig(
        targetRoot,
        const ShadcnConfig(
          installPath: 'lib/ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeMeta: true,
        ),
      );
      _writePubspec(targetRoot);

      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.addComponent('dialog');
      await installer.removeComponent('button', force: true);

      final buttonFile = File(
        p.join(
          targetRoot.path,
          'lib',
          'ui',
          'shadcn',
          'components',
          'button',
          'button.dart',
        ),
      );
      expect(buttonFile.existsSync(), isFalse);
    });

    test('init with overrides normalizes paths and aliases', () async {
      final registry = await Registry.load(
        registryRoot: RegistryLocation.local(registryRoot.path),
        sourceRoot: RegistryLocation.local(p.dirname(registryRoot.path)),
      );

      final installer = Installer(
        registry: registry,
        targetDir: targetRoot.path,
          logger: CliLogger(),
      );

      await installer.init(
        skipPrompts: true,
        configOverrides: const InitConfigOverrides(
          installPath: 'ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeReadme: false,
          includeMeta: true,
          includePreview: false,
          classPrefix: 'App',
          pathAliases: {'ui': 'lib/ui'},
        ),
      );

      final config = await ShadcnConfig.load(targetRoot.path);
      expect(config.installPath, 'lib/ui/shadcn');
      expect(config.sharedPath, 'lib/ui/shadcn/shared');
      expect(config.pathAliases?['ui'], 'ui');
    });
  });
}

void _writeRegistryFixtures(Directory registryRoot) {
  final root = p.dirname(registryRoot.path);
  final componentsDir = Directory(p.join(root, 'registry', 'components', 'button'))
    ..createSync(recursive: true);
  final dialogDir = Directory(p.join(root, 'registry', 'components', 'dialog'))
    ..createSync(recursive: true);
  final sharedThemeDir = Directory(p.join(root, 'registry', 'shared', 'theme'))
    ..createSync(recursive: true);
  final sharedUtilDir = Directory(p.join(root, 'registry', 'shared', 'util'))
    ..createSync(recursive: true);

  File(p.join(componentsDir.path, 'button.dart'))
      .writeAsStringSync('class Button {}');
  File(p.join(componentsDir.path, 'README.md'))
      .writeAsStringSync('# Button');
  File(p.join(componentsDir.path, 'meta.json'))
      .writeAsStringSync('{"id":"button"}');
  File(p.join(componentsDir.path, 'preview.dart'))
      .writeAsStringSync('void main() {}');

    File(p.join(dialogDir.path, 'dialog.dart'))
      .writeAsStringSync('class Dialog {}');
    File(p.join(dialogDir.path, 'meta.json'))
      .writeAsStringSync('{"id":"dialog"}');

      File(p.join(sharedThemeDir.path, 'theme.dart'))
        .writeAsStringSync('class ThemeHelper {}');
      File(p.join(sharedUtilDir.path, 'util.dart'))
        .writeAsStringSync('class UtilHelper {}');

  final registryJson = {
    'defaults': {
      'installPath': 'lib/ui/shadcn',
      'sharedPath': 'lib/ui/shadcn/shared',
    },
    'shared': [
      {
        'id': 'theme',
        'files': [
          {
            'source': 'registry/shared/theme/theme.dart',
            'destination': '{sharedPath}/theme/theme.dart'
          }
        ]
      },
      {
        'id': 'util',
        'files': [
          {
            'source': 'registry/shared/util/util.dart',
            'destination': '{sharedPath}/util/util.dart'
          }
        ]
      }
    ],
    'components': [
      {
        'id': 'button',
        'name': 'Button',
        'files': [
          {
            'source': 'registry/components/button/button.dart',
            'destination': '{installPath}/components/button/button.dart'
          },
          {
            'source': 'registry/components/button/README.md',
            'destination': '{installPath}/components/button/README.md'
          },
          {
            'source': 'registry/components/button/meta.json',
            'destination': '{installPath}/components/button/meta.json'
          },
          {
            'source': 'registry/components/button/preview.dart',
            'destination': '{installPath}/components/button/preview.dart'
          }
        ],
        'shared': [],
        'dependsOn': [],
        'pubspec': {
          'dependencies': {
            'skeletonizer': '^2.1.0+1'
          }
        }
      },
      {
        'id': 'dialog',
        'name': 'Dialog',
        'files': [
          {
            'source': 'registry/components/dialog/dialog.dart',
            'destination': '{installPath}/components/dialog/dialog.dart'
          },
          {
            'source': 'registry/components/dialog/meta.json',
            'destination': '{installPath}/components/dialog/meta.json'
          }
        ],
        'shared': [],
        'dependsOn': ['button'],
        'pubspec': {
          'dependencies': {}
        }
      }
    ]
  };

  File(p.join(registryRoot.path, 'components.json'))
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(registryJson));
}

void _writePubspec(Directory targetRoot, {Map<String, String>? dependencies}) {
  final buffer = StringBuffer()
    ..writeln('name: test_app')
    ..writeln('environment:')
    ..writeln('  sdk: ">=3.3.0 <4.0.0"')
    ..writeln('dependencies:');
  final deps = dependencies ?? {
    'flutter': 'sdk: flutter',
  };
  deps.forEach((key, value) {
    buffer.writeln('  $key: $value');
  });
  File(p.join(targetRoot.path, 'pubspec.yaml')).writeAsStringSync(buffer.toString());
}

Future<void> _writeConfig(Directory targetRoot, ShadcnConfig config) async {
  await ShadcnConfig.save(targetRoot.path, config);
}
