import 'dart:convert';
import 'dart:io';

import 'package:flutter_shadcn_cli/src/registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  Future<Directory> createSchemaFixtureDir() async {
    final dir = await Directory.systemTemp.createTemp('schema_validation_test_');
    final schemaFile = File(p.join(dir.path, 'components.schema.json'));
    final componentsFile = File(p.join(dir.path, 'components.json'));

    await schemaFile.writeAsString(
      jsonEncode({
        r'$schema': 'https://json-schema.org/draft/2020-12/schema',
        'type': 'object',
        'required': ['schemaVersion', 'name', 'defaults'],
        'properties': {
          'schemaVersion': {'type': 'integer'},
          'name': {'type': 'string'},
          'defaults': {'type': 'object'},
        },
      }),
    );

    await componentsFile.writeAsString(
      jsonEncode({
        r'$schema': './components.schema.json',
        'schemaVersion': 1,
        'name': 'fixture_registry',
        'defaults': {'installPath': 'lib/ui/shadcn'},
      }),
    );

    return dir;
  }

  test('components.json validates against schema', () async {
    final fixtureDir = await createSchemaFixtureDir();
    addTearDown(() => fixtureDir.delete(recursive: true));

    final registryRoot = RegistryLocation.local(fixtureDir.path);
    final content = await registryRoot.readString('components.json');
    final data = jsonDecode(content);
    expect(data, isA<Map<String, dynamic>>());

    final schemaSource = ComponentsSchemaValidator.resolveSchemaSource(
      data: data as Map<String, dynamic>,
      registryRoot: registryRoot,
    );
    expect(schemaSource, isNotNull);

    final result = await ComponentsSchemaValidator.validateWithJsonSchema(
      data,
      schemaSource!,
    );
    expect(
      result.isValid,
      isTrue,
      reason: result.errors.take(5).join('\n'),
    );
  });

  test('invalid fixture fails schema validation', () async {
    final fixtureDir = await createSchemaFixtureDir();
    addTearDown(() => fixtureDir.delete(recursive: true));

    final registryRoot = RegistryLocation.local(fixtureDir.path);
    final schemaSource = ComponentsSchemaValidator.resolveSchemaSource(
      data: const {},
      registryRoot: registryRoot,
    );
    expect(schemaSource, isNotNull);

    final invalid = {
      'schemaVersion': '1',
      'name': 'invalid_registry',
      'defaults': {},
    };

    final result = await ComponentsSchemaValidator.validateWithJsonSchema(
      invalid,
      schemaSource!,
    );
    expect(result.isValid, isFalse);
  });
}
