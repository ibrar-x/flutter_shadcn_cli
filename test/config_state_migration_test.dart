import 'dart:convert';
import 'dart:io';

import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/state.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('legacy migration', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('shadcn_migrate_test_');
      Directory(p.join(tempDir.path, '.shadcn')).createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('migrates old config format to registries map', () async {
      final oldConfig =
          File('test/fixtures/old_config.json').readAsStringSync();
      final configFile = File(p.join(tempDir.path, '.shadcn', 'config.json'));
      configFile.writeAsStringSync(oldConfig);

      final config = await ShadcnConfig.load(tempDir.path);
      expect(config.effectiveDefaultNamespace, 'shadcn');
      expect(config.registries, isNotNull);
      expect(config.registries!.containsKey('shadcn'), isTrue);
      expect(config.registryUrl, 'https://example.com/registry');
      expect(config.installPath, 'lib/ui/shadcn');
      expect(config.sharedPath, 'lib/ui/shadcn/shared');
      expect(config.includeFiles, ['meta']);
      expect(config.excludeFiles, ['preview']);

      final migratedJson =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      expect(migratedJson['registries'], isA<Map>());
      expect(migratedJson['defaultNamespace'], 'shadcn');
      final shadcn = (migratedJson['registries'] as Map)['shadcn'] as Map;
      expect(shadcn['registryUrl'], 'https://example.com/registry');
      expect(shadcn['includeFiles'], ['meta']);
      expect(shadcn['excludeFiles'], ['preview']);
    });

    test('loads new config format fixture', () async {
      final newConfig =
          File('test/fixtures/new_config.json').readAsStringSync();
      final configFile = File(p.join(tempDir.path, '.shadcn', 'config.json'));
      configFile.writeAsStringSync(newConfig);

      final config = await ShadcnConfig.load(tempDir.path);
      expect(config.registries, isNotNull);
      expect(config.registries!['shadcn']?.enabled, isTrue);
      expect(config.installPath, 'lib/ui/shadcn');
      expect(config.sharedPath, 'lib/ui/shadcn/shared');
      expect(config.includeFiles, ['meta']);
      expect(config.excludeFiles, ['preview']);
    });

    test('migrates old state format to registries map', () async {
      final oldState = File('test/fixtures/old_state.json').readAsStringSync();
      final stateFile = File(p.join(tempDir.path, '.shadcn', 'state.json'));
      stateFile.writeAsStringSync(oldState);

      final state = await ShadcnState.load(tempDir.path);
      expect(state.registries, isNotNull);
      expect(state.registries!['shadcn'], isNotNull);
      expect(state.installPath, 'lib/ui/shadcn');
      expect(state.sharedPath, 'lib/ui/shadcn/shared');
      expect(state.managedDependencies, containsAll(['gap', 'data_widget']));

      final migratedJson =
          jsonDecode(stateFile.readAsStringSync()) as Map<String, dynamic>;
      expect(migratedJson['registries'], isA<Map>());
      expect(
        ((migratedJson['registries'] as Map)['shadcn'] as Map)['installPath'],
        'lib/ui/shadcn',
      );
      expect(
        migratedJson['managedDependencies'],
        containsAll(['gap', 'data_widget']),
      );
    });

    test('loads new state format fixture', () async {
      final newState = File('test/fixtures/new_state.json').readAsStringSync();
      final stateFile = File(p.join(tempDir.path, '.shadcn', 'state.json'));
      stateFile.writeAsStringSync(newState);

      final state = await ShadcnState.load(tempDir.path);
      expect(state.registries, isNotNull);
      expect(state.registries!['shadcn']?.themeId, 'modern-minimal');
      expect(state.managedDependencies, containsAll(['gap', 'data_widget']));
    });
  });
}
