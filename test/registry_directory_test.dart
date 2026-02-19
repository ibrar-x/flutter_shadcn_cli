import 'dart:convert';
import 'dart:io';

import 'package:flutter_shadcn_cli/src/registry_directory.dart';
import 'package:test/test.dart';

void main() {
  group('RegistryDirectoryClient', () {
    late Directory tempProject;

    setUp(() {
      tempProject =
          Directory.systemTemp.createTempSync('shadcn_registry_dir_test_');
    });

    tearDown(() {
      if (tempProject.existsSync()) {
        tempProject.deleteSync(recursive: true);
      }
    });

    test('fetches directory, validates schema, and reuses ETag cache',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var sawIfNoneMatch = false;
      final body = jsonEncode({
        'schemaVersion': 1,
        'registries': [
          {
            'id': 'shadcn',
            'displayName': 'Shadcn',
            'maintainers': ['team'],
            'repo': 'https://github.com/example/repo',
            'license': 'MIT',
            'minCliVersion': '0.1.0',
            'baseUrl': 'https://example.com/registry/',
            'paths': {'componentsJson': 'components.json'},
            'install': {'namespace': 'shadcn', 'root': 'lib/ui/shadcn'}
          },
          {
            'id': 'future_kit',
            'displayName': 'Future Kit',
            'maintainers': ['team'],
            'repo': 'https://github.com/example/future',
            'license': 'MIT',
            'minCliVersion': '9.9.0',
            'baseUrl': 'https://example.com/future/',
            'paths': {'componentsJson': 'components.json'},
            'install': {'namespace': 'future', 'root': 'lib/ui/future'}
          }
        ]
      });

      server.listen((request) async {
        if (request.uri.path != '/registries.json') {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        final match = request.headers.value('if-none-match');
        if (match == 'v1') {
          sawIfNoneMatch = true;
          request.response.statusCode = 304;
          await request.response.close();
          return;
        }
        request.response.statusCode = 200;
        request.response.headers.set('etag', 'v1');
        request.response.write(body);
        await request.response.close();
      });

      final client = RegistryDirectoryClient();
      final url =
          'http://${server.address.host}:${server.port}/registries.json';
      final first = await client.load(
        projectRoot: tempProject.path,
        directoryUrl: url,
        currentCliVersion: '0.1.8',
      );
      expect(first.registries.length, 1);
      expect(first.registries.first.namespace, 'shadcn');

      final second = await client.load(
        projectRoot: tempProject.path,
        directoryUrl: url,
        currentCliVersion: '0.1.8',
      );
      expect(second.registries.length, 1);
      expect(sawIfNoneMatch, isTrue);

      final offline = await client.load(
        projectRoot: tempProject.path,
        directoryUrl: url,
        currentCliVersion: '0.1.8',
        offline: true,
      );
      expect(offline.registries.length, 1);
      expect(
        File('${tempProject.path}/.shadcn/cache/registries.json').existsSync(),
        isTrue,
      );
    });

    test('loads and caches components.json with ETag', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var sawIfNoneMatch = false;
      server.listen((request) async {
        if (request.uri.path != '/registry/components.json') {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }
        final match = request.headers.value('if-none-match');
        if (match == 'comp-v1') {
          sawIfNoneMatch = true;
          request.response.statusCode = 304;
          await request.response.close();
          return;
        }
        request.response.statusCode = 200;
        request.response.headers.set('etag', 'comp-v1');
        request.response.write(jsonEncode({'components': []}));
        await request.response.close();
      });

      final client = RegistryDirectoryClient();
      final entry = RegistryDirectoryEntry(
        id: 'shadcn',
        displayName: 'Shadcn',
        minCliVersion: '0.1.0',
        baseUrl: 'http://${server.address.host}:${server.port}/registry',
        namespace: 'shadcn',
        installRoot: 'lib/ui/shadcn',
        paths: {'componentsJson': 'components.json'},
        init: null,
        raw: const {},
      );

      final first = await client.loadComponentsJson(
        projectRoot: tempProject.path,
        registry: entry,
      );
      expect(first, contains('"components"'));

      final second = await client.loadComponentsJson(
        projectRoot: tempProject.path,
        registry: entry,
      );
      expect(second, contains('"components"'));
      expect(sawIfNoneMatch, isTrue);
    });

    test('loads registries directory from local file path', () async {
      final localFile = File(
        '${tempProject.path}/local_dev/registries.json',
      )..createSync(recursive: true);
      localFile.writeAsStringSync(
        jsonEncode({
          'schemaVersion': 1,
          'registries': [
            {
              'id': 'local_shadcn',
              'displayName': 'Local Shadcn',
              'maintainers': ['team'],
              'repo': 'https://github.com/example/local',
              'license': 'MIT',
              'minCliVersion': '0.1.0',
              'baseUrl': 'https://example.com/local/',
              'paths': {'componentsJson': 'components.json'},
              'install': {'namespace': 'local_shadcn', 'root': 'lib/ui/local'}
            }
          ]
        }),
      );

      final client = RegistryDirectoryClient();
      final result = await client.load(
        projectRoot: tempProject.path,
        directoryPath: localFile.path,
        currentCliVersion: '0.1.8',
      );

      expect(result.registries.length, 1);
      expect(result.registries.first.namespace, 'local_shadcn');
    });

    test('loads registries directory from local directory path', () async {
      final localDir = Directory('${tempProject.path}/dev_registry_dir')
        ..createSync(recursive: true);
      File('${localDir.path}/registries.json').writeAsStringSync(
        jsonEncode({
          'schemaVersion': 1,
          'registries': [
            {
              'id': 'orient_ui',
              'displayName': 'Orient UI',
              'maintainers': ['team'],
              'repo': 'https://github.com/example/orient',
              'license': 'MIT',
              'minCliVersion': '0.1.0',
              'baseUrl': 'https://example.com/orient/',
              'paths': {'componentsJson': 'components.json'},
              'install': {'namespace': 'orient_ui', 'root': 'lib/ui/orient'}
            }
          ]
        }),
      );

      final client = RegistryDirectoryClient();
      final result = await client.load(
        projectRoot: tempProject.path,
        directoryPath: 'dev_registry_dir',
        currentCliVersion: '0.1.8',
      );

      expect(result.registries.length, 1);
      expect(result.registries.first.namespace, 'orient_ui');
    });

    test('rejects invalid registries schema', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        request.response.statusCode = 200;
        request.response.write(jsonEncode({'invalid': true}));
        await request.response.close();
      });

      final client = RegistryDirectoryClient();
      final url =
          'http://${server.address.host}:${server.port}/registries.json';
      await expectLater(
        () => client.load(
          projectRoot: tempProject.path,
          directoryUrl: url,
          currentCliVersion: '0.1.8',
        ),
        throwsA(isA<RegistryDirectoryException>()),
      );
    });
  });
}
