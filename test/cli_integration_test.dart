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

    test('add installs component via CLI main', () async {
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

      final aliasFile = File(
        p.join(appRoot.path, 'lib', 'ui', 'shadcn', 'app_components.dart'),
      );
      expect(aliasFile.existsSync(), isTrue);
      expect(aliasFile.readAsStringSync().contains('typedef AppButton = Button;'),
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
  });
}

void _writeRegistryFixtures(Directory registryRoot) {
  final root = p.dirname(registryRoot.path);
  final componentsDir = Directory(p.join(root, 'registry', 'components', 'button'))
    ..createSync(recursive: true);

  File(p.join(componentsDir.path, 'button.dart'))
      .writeAsStringSync('class Button {}');
  File(p.join(componentsDir.path, 'meta.json'))
      .writeAsStringSync('{"id":"button"}');

  final registryJson = {
    'defaults': {
      'installPath': 'lib/ui/shadcn',
      'sharedPath': 'lib/ui/shadcn/shared',
    },
    'shared': [],
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
            'source': 'registry/components/button/meta.json',
            'destination': '{installPath}/components/button/meta.json'
          }
        ],
        'shared': [],
        'dependsOn': [],
        'pubspec': {
          'dependencies': {}
        }
      }
    ]
  };

  File(p.join(registryRoot.path, 'components.json'))
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(registryJson));
}

void _writePubspec(Directory targetRoot) {
  final buffer = StringBuffer()
    ..writeln('name: test_app')
    ..writeln('environment:')
    ..writeln('  sdk: ">=3.3.0 <4.0.0"')
    ..writeln('dependencies:')
    ..writeln('  flutter:')
    ..writeln('    sdk: flutter');

  File(p.join(targetRoot.path, 'pubspec.yaml')).writeAsStringSync(buffer.toString());
}
