import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../bin/shadcn.dart' as cli;
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';

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

    test('init installs typography fonts when requested', () async {
      await cli.main([
        'init',
        '--yes',
        '--install-fonts',
        '--registry',
        'local',
        '--registry-path',
        registryRoot.path,
      ]);

      final typographyFile = File(
        p.join(
          appRoot.path,
          'lib',
          'ui',
          'shadcn',
          'components',
          'typography_fonts',
          'typography_fonts.dart',
        ),
      );
      expect(typographyFile.existsSync(), isTrue);
    });

    test('validate reports schema failures', () async {
      exitCode = 0;
      final invalidRegistry =
          Directory(p.join(tempRoot.path, 'invalid_registry'))
            ..createSync(recursive: true);
      File(p.join(invalidRegistry.path, 'components.json'))
          .writeAsStringSync('{"schemaVersion":1}');

      await cli.main([
        'validate',
        '--registry',
        'local',
        '--registry-path',
        invalidRegistry.path,
      ]);

      expect(exitCode, ExitCodes.schemaInvalid);
    });

    test('sync preserves component manifests', () async {
      await cli.main([
        'add',
        'button',
        '--registry',
        'local',
        '--registry-path',
        registryRoot.path,
      ]);

      await cli.main([
        'sync',
      ]);

      final manifestFile = File(
        p.join(appRoot.path, '.shadcn', 'components', 'button.json'),
      );
      expect(manifestFile.existsSync(), isTrue);
    });

    test('offline list uses cached index', () async {
      exitCode = 0;
      final registryUrl = 'https://example.com/registry';
      final registryId =
          registryUrl.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          tempRoot.path;
      final cacheDir = Directory(
        p.join(home, '.flutter_shadcn', 'cache', registryId),
      );
      cacheDir.createSync(recursive: true);
      File(p.join(cacheDir.path, 'index.json')).writeAsStringSync(
        jsonEncode({'components': []}),
      );

      await cli.main([
        'list',
        '--registry',
        'remote',
        '--registry-url',
        registryUrl,
        '--offline',
        '--json',
      ]);

      expect(exitCode, ExitCodes.success);
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
  final typographyDir =
      Directory(p.join(root, 'registry', 'components', 'typography_fonts'))
        ..createSync(recursive: true);
  final iconDir =
      Directory(p.join(root, 'registry', 'components', 'icon_fonts'))
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

  File(p.join(typographyDir.path, 'typography_fonts.dart'))
      .writeAsStringSync('class TypographyFonts {}');
  File(p.join(typographyDir.path, 'meta.json'))
      .writeAsStringSync('{"id":"typography_fonts"}');
  File(p.join(iconDir.path, 'icon_fonts.dart'))
      .writeAsStringSync('class IconFonts {}');
  File(p.join(iconDir.path, 'meta.json'))
      .writeAsStringSync('{"id":"icon_fonts"}');

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
      },
      {
        'id': 'typography_fonts',
        'name': 'Typography Fonts',
        'description': 'Typography font assets',
        'category': 'utility',
        'version': '1.0.0',
        'tags': ['assets'],
        'files': [
          {
            'source':
                'registry/components/typography_fonts/typography_fonts.dart',
            'destination':
                '{installPath}/components/typography_fonts/typography_fonts.dart'
          },
          {
            'source': 'registry/components/typography_fonts/meta.json',
            'destination': '{installPath}/components/typography_fonts/meta.json'
          }
        ],
        'shared': [],
        'dependsOn': [],
        'pubspec': {'dependencies': {}},
        'assets': [],
        'postInstall': []
      },
      {
        'id': 'icon_fonts',
        'name': 'Icon Fonts',
        'description': 'Icon font assets',
        'category': 'utility',
        'version': '1.0.0',
        'tags': ['assets'],
        'files': [
          {
            'source': 'registry/components/icon_fonts/icon_fonts.dart',
            'destination': '{installPath}/components/icon_fonts/icon_fonts.dart'
          },
          {
            'source': 'registry/components/icon_fonts/meta.json',
            'destination': '{installPath}/components/icon_fonts/meta.json'
          }
        ],
        'shared': [],
        'dependsOn': [],
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
