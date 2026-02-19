import 'dart:convert';
import 'dart:io';

import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_manager.dart';
import 'package:flutter_shadcn_cli/src/registry_directory.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('MultiRegistryManager', () {
    late Directory tempRoot;
    late Directory appRoot;
    late Directory registryBaseA;
    late Directory registryBaseB;

    setUp(() async {
      tempRoot = Directory.systemTemp.createTempSync('shadcn_multi_mgr_');
      appRoot = Directory(p.join(tempRoot.path, 'app'))..createSync();
      registryBaseA = Directory(p.join(tempRoot.path, 'reg_a'))..createSync();
      registryBaseB = Directory(p.join(tempRoot.path, 'reg_b'))..createSync();
      _writeSimpleRegistry(registryBaseA, marker: 'A');
      _writeSimpleRegistry(registryBaseB, marker: 'B');
      File(p.join(appRoot.path, 'pubspec.yaml')).writeAsStringSync(
        [
          'name: test_app',
          'dependencies:',
          '  flutter: sdk: flutter',
        ].join('\n'),
      );
      await ShadcnConfig.save(
        appRoot.path,
        ShadcnConfig(
          defaultNamespace: 'shadcn',
          includeMeta: true,
          registries: {
            'shadcn': RegistryConfigEntry(
              registryMode: 'local',
              registryPath: p.join(registryBaseA.path, 'registry'),
              installPath: 'lib/ui/shadcn',
              sharedPath: 'lib/ui/shadcn/shared',
              enabled: true,
            ),
            'alt': RegistryConfigEntry(
              registryMode: 'local',
              registryPath: p.join(registryBaseB.path, 'registry'),
              installPath: 'lib/ui/alt',
              sharedPath: 'lib/ui/alt/shared',
              enabled: true,
            ),
          },
        ),
      );
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('unqualified add fails when component is ambiguous', () async {
      final current = await ShadcnConfig.load(appRoot.path);
      await ShadcnConfig.save(
        appRoot.path,
        current.copyWith(defaultNamespace: 'unknown'),
      );
      final manager = MultiRegistryManager(
        targetDir: appRoot.path,
        offline: true,
        logger: CliLogger(),
      );
      await expectLater(
        () => manager.runAdd(['button']),
        throwsA(isA<MultiRegistryException>()),
      );
    });

    test('unqualified add uses default registry when available', () async {
      final manager = MultiRegistryManager(
        targetDir: appRoot.path,
        offline: true,
        logger: CliLogger(),
      );
      await manager.runAdd(['button']);
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
      expect(
        File(
          p.join(
            appRoot.path,
            'lib',
            'ui',
            'alt',
            'components',
            'button',
            'button.dart',
          ),
        ).existsSync(),
        isFalse,
      );
    });

    test('qualified @namespace/component installs from selected registry',
        () async {
      final manager = MultiRegistryManager(
        targetDir: appRoot.path,
        offline: true,
        logger: CliLogger(),
      );
      await manager.runAdd(['@alt/button']);
      expect(
        File(
          p.join(
            appRoot.path,
            'lib',
            'ui',
            'alt',
            'components',
            'button',
            'button.dart',
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test('setDefaultRegistry updates config and list reflects default',
        () async {
      final manager = MultiRegistryManager(
        targetDir: appRoot.path,
        offline: true,
        logger: CliLogger(),
      );
      final updated = await manager.setDefaultRegistry('alt');
      expect(updated.effectiveDefaultNamespace, 'alt');

      final listed = await manager.listRegistries();
      final alt = listed.firstWhere((entry) => entry.namespace == 'alt');
      expect(alt.isDefault, isTrue);
    });

    test('inline assets install and rollback use registry actions', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        final path = request.uri.path;
        if (path == '/registries.json') {
          request.response.write(
            jsonEncode({
              'schemaVersion': 1,
              'registries': [
                {
                  'id': 'shadcn_entry',
                  'displayName': 'Shadcn',
                  'maintainers': ['team'],
                  'repo': 'https://example.com/repo',
                  'license': 'MIT',
                  'minCliVersion': '0.1.0',
                  'baseUrl': 'https://example.com/registry/',
                  'paths': {'componentsJson': 'components.json'},
                  'install': {'namespace': 'shadcn', 'root': 'lib/ui/shadcn'},
                  'init': {
                    'version': 1,
                    'actions': [
                      {
                        'type': 'ensureDirs',
                        'dirs': ['assets/fonts']
                      },
                      {
                        'type': 'copyFiles',
                        'base': 'registry',
                        'destBase': 'lib/ui/shadcn',
                        'files': ['registry/shared/fonts/typography_fonts.dart']
                      },
                      {
                        'type': 'mergePubspec',
                        'dependencies': {'google_fonts': '^6.2.1'},
                        'flutterAssets': ['assets/fonts/GeistSans-Regular.ttf'],
                        'flutterFonts': [
                          {
                            'family': 'GeistSans',
                            'fonts': [
                              {
                                'asset': 'assets/fonts/GeistSans-Regular.ttf',
                                'weight': 400
                              }
                            ]
                          }
                        ]
                      },
                      {
                        'type': 'ensureDirs',
                        'dirs': ['assets/icons']
                      },
                    ]
                  }
                }
              ]
            }),
          );
          await request.response.close();
          return;
        }
        if (path == '/registry/shared/fonts/typography_fonts.dart') {
          request.response.write('class TypographyFonts {}');
          await request.response.close();
          return;
        }
        if (path == '/components.json') {
          request.response.write(
            jsonEncode({
              'schemaVersion': 1,
              'name': 'inline_assets',
              'flutter': {'minSdk': '3.0.0'},
              'defaults': {
                'installPath': 'lib/ui/shadcn',
                'sharedPath': 'lib/ui/shadcn/shared',
              },
              'shared': [],
              'components': [],
            }),
          );
          await request.response.close();
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      });

      final manager = MultiRegistryManager(
        targetDir: appRoot.path,
        offline: false,
        logger: CliLogger(verbose: true),
        directoryUrl:
            'http://${server.address.host}:${server.port}/registries.json',
      );
      final loadedDirectory = await RegistryDirectoryClient().load(
        projectRoot: appRoot.path,
        directoryUrl:
            'http://${server.address.host}:${server.port}/registries.json',
        offline: false,
        currentCliVersion: '0.1.8',
      );
      expect(
          loadedDirectory.registries
              .any((entry) => entry.namespace == 'shadcn'),
          isTrue);
      await ShadcnConfig.save(
        appRoot.path,
        ShadcnConfig(
          defaultNamespace: 'shadcn',
          registries: {
            'shadcn': RegistryConfigEntry(
              registryMode: 'remote',
              registryUrl: 'http://${server.address.host}:${server.port}/',
              baseUrl: 'http://${server.address.host}:${server.port}/',
              installPath: 'lib/ui/shadcn',
              sharedPath: 'lib/ui/shadcn/shared',
              enabled: true,
            ),
            'alt': RegistryConfigEntry(
              registryMode: 'local',
              registryPath: p.join(registryBaseB.path, 'registry'),
              installPath: 'lib/ui/alt',
              sharedPath: 'lib/ui/alt/shared',
              enabled: true,
            ),
          },
        ),
      );
      final applied = await manager.runInlineAssets(
        namespace: 'shadcn',
        installIcons: false,
        installTypography: true,
        installAll: false,
      );
      expect(applied, isTrue);
      expect(
        File(
          p.join(
            appRoot.path,
            'lib',
            'ui',
            'shadcn',
            'shared',
            'fonts',
            'typography_fonts.dart',
          ),
        ).existsSync(),
        isTrue,
      );
      final pubspecBeforeRollback =
          File(p.join(appRoot.path, 'pubspec.yaml')).readAsStringSync();
      expect(pubspecBeforeRollback.contains('google_fonts: ^6.2.1'), isTrue);
      expect(pubspecBeforeRollback.contains('family: GeistSans'), isTrue);

      final rolledBack = await manager.rollbackInlineAssets(
        namespace: 'shadcn',
        removeIcons: false,
        removeTypography: true,
        removeAll: false,
      );
      expect(rolledBack, isTrue);
      expect(
        File(
          p.join(
            appRoot.path,
            'lib',
            'ui',
            'shadcn',
            'shared',
            'fonts',
            'typography_fonts.dart',
          ),
        ).existsSync(),
        isFalse,
      );
      final pubspecAfterRollback =
          File(p.join(appRoot.path, 'pubspec.yaml')).readAsStringSync();
      expect(pubspecAfterRollback.contains('google_fonts: ^6.2.1'), isFalse);
      expect(pubspecAfterRollback.contains('family: GeistSans'), isFalse);
    });
  });
}

void _writeSimpleRegistry(Directory baseDir, {required String marker}) {
  final registryRoot = Directory(p.join(baseDir.path, 'registry'))
    ..createSync(recursive: true);
  final componentDir = Directory(
    p.join(baseDir.path, 'registry', 'components', 'button'),
  )..createSync(recursive: true);
  File(p.join(componentDir.path, 'button.dart'))
      .writeAsStringSync('class Button$marker {}');
  File(p.join(registryRoot.path, 'components.json')).writeAsStringSync(
    jsonEncode({
      'schemaVersion': 1,
      'name': 'registry_$marker',
      'flutter': {'minSdk': '3.0.0'},
      'defaults': {
        'installPath': 'lib/ui/$marker',
        'sharedPath': 'lib/ui/$marker/shared',
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
              'destination': 'components/button/button.dart',
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
}
