import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../bin/shadcn.dart' as cli;
import 'package:flutter_shadcn_cli/src/config.dart';

void main() {
  group('CLI integration', () {
    late Directory tempRoot;
    late Directory registryRoot;
    late Directory appRoot;
    late Directory originalCwd;

    setUp(() async {
      tempRoot = Directory.systemTemp.createTempSync('shadcn_cli_it_');
      registryRoot = Directory(p.join(tempRoot.path, 'registry'))..createSync();
      appRoot = Directory(p.join(tempRoot.path, 'app'))..createSync();
      _writeRegistryFixtures(registryRoot);
      _writePubspec(appRoot);
      await ShadcnConfig.save(
        appRoot.path,
        const ShadcnConfig(
          installPath: 'lib/ui/shadcn',
          sharedPath: 'lib/ui/shadcn/shared',
          includeMeta: true,
          classPrefix: 'App',
        ),
      );
      originalCwd = Directory.current;
      Directory.current = appRoot;
    });

    tearDown(() {
      Directory.current = originalCwd;
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('add installs component and writes manifests', () async {
      await cli.main([
        'add',
        'button',
        '--registry',
        'local',
        '--registry-path',
        registryRoot.path,
      ]);

      final installDir = p.join(
        appRoot.path,
        'lib',
        'ui',
        'shadcn',
        'components',
        'button',
      );
      expect(File(p.join(installDir, 'button.dart')).existsSync(), isTrue);
      expect(File(p.join(installDir, 'meta.json')).existsSync(), isTrue);
      expect(
        File(
          p.join(
            appRoot.path,
            'lib',
            'ui',
            'shadcn',
            'shared',
            'theme',
            'theme.dart',
          ),
        ).existsSync(),
        isTrue,
      );

      final manifestFile = File(
        p.join(appRoot.path, '.shadcn', 'components', 'button.json'),
      );
      expect(manifestFile.existsSync(), isTrue);
      final manifestData =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      expect(manifestData['id'], 'button');
      expect(manifestData['version'], '1.0.0');
      expect(manifestData['tags'], contains('core'));

      final installManifest = File(
        p.join(appRoot.path, 'lib', 'ui', 'shadcn', 'components.json'),
      );
      expect(installManifest.existsSync(), isTrue);
      final installData = jsonDecode(installManifest.readAsStringSync())
          as Map<String, dynamic>;
      final meta = installData['componentMeta'] as Map<String, dynamic>;
      final buttonMeta = meta['button'] as Map<String, dynamic>;
      expect(buttonMeta['version'], '1.0.0');
      expect(buttonMeta['tags'], contains('core'));

      final aliasFile = File(
        p.join(appRoot.path, 'lib', 'ui', 'shadcn', 'app_components.dart'),
      );
      expect(aliasFile.existsSync(), isTrue);
      expect(
          aliasFile.readAsStringSync().contains('typedef AppButton = Button;'),
          isTrue);
    });

    test('doctor runs without crashing', () async {
      await cli.main([
        'doctor',
        '--registry',
        'local',
        '--registry-path',
        registryRoot.path,
      ]);
    });

    test('init installs positional components', () async {
      await cli.main([
        'init',
        '--yes',
        'button',
        'dialog',
        '--registry',
        'local',
        '--registry-path',
        registryRoot.path,
      ]);

      final buttonFile = File(
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
      final dialogFile = File(
        p.join(
          appRoot.path,
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
  });
}

void _writeRegistryFixtures(Directory registryRoot) {
  final root = p.dirname(registryRoot.path);
  final componentsDir =
      Directory(p.join(root, 'registry', 'components', 'button'))
        ..createSync(recursive: true);
  final dialogDir = Directory(p.join(root, 'registry', 'components', 'dialog'))
    ..createSync(recursive: true);
  final sharedThemeDir = Directory(p.join(root, 'registry', 'shared', 'theme'))
    ..createSync(recursive: true);
  final sharedUtilDir = Directory(p.join(root, 'registry', 'shared', 'util'))
    ..createSync(recursive: true);

  File(p.join(componentsDir.path, 'button.dart'))
      .writeAsStringSync('class Button {}');
  File(p.join(componentsDir.path, 'meta.json'))
      .writeAsStringSync('{"id":"button"}');

  File(p.join(dialogDir.path, 'dialog.dart'))
      .writeAsStringSync('class Dialog {}');
  File(p.join(dialogDir.path, 'meta.json'))
      .writeAsStringSync('{"id":"dialog"}');

  File(p.join(sharedThemeDir.path, 'theme.dart'))
      .writeAsStringSync('class ThemeHelper {}');
  File(p.join(sharedUtilDir.path, 'util.dart'))
      .writeAsStringSync('class UtilHelper {}');

  final registryJson = {
    'schemaVersion': 1,
    'name': 'test_registry',
    'flutter': {'minSdk': '>=3.3.0'},
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
        'description': 'Button component',
        'category': 'control',
        'version': '1.0.0',
        'tags': ['core'],
        'files': [
          {
            'source': 'registry/components/button/button.dart',
            'destination': '{installPath}/components/button/button.dart',
            'dependsOn': ['registry/shared/theme/theme.dart']
          },
          {
            'source': 'registry/components/button/meta.json',
            'destination': '{installPath}/components/button/meta.json'
          }
        ],
        'shared': ['theme'],
        'dependsOn': [],
        'pubspec': {'dependencies': {}},
        'assets': [],
        'postInstall': []
      },
      {
        'id': 'dialog',
        'name': 'Dialog',
        'description': 'Dialog component',
        'category': 'overlay',
        'version': '0.1.0',
        'tags': ['overlay'],
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
        'pubspec': {'dependencies': {}},
        'assets': [],
        'postInstall': []
      }
    ]
  };

  File(p.join(registryRoot.path, 'components.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(registryJson));
}

void _writePubspec(Directory targetRoot) {
  final buffer = StringBuffer()
    ..writeln('name: test_app')
    ..writeln('environment:')
    ..writeln('  sdk: ">=3.3.0 <4.0.0"')
    ..writeln('dependencies:')
    ..writeln('  flutter:')
    ..writeln('    sdk: flutter');

  File(p.join(targetRoot.path, 'pubspec.yaml'))
      .writeAsStringSync(buffer.toString());
}
