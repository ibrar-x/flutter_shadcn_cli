import 'dart:convert';
import 'dart:io';

import 'package:flutter_shadcn_cli/src/registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('components.json validates against schema', () async {
    final registryDir = p.join(
      Directory.current.path,
      '..',
      'shadcn_flutter_kit',
      'flutter_shadcn_kit',
      'lib',
      'registry',
    );
    final registryRoot = RegistryLocation.local(registryDir);
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
    final registryDir = p.join(
      Directory.current.path,
      '..',
      'shadcn_flutter_kit',
      'flutter_shadcn_kit',
      'lib',
      'registry',
    );
    final registryRoot = RegistryLocation.local(registryDir);
    final schemaSource = ComponentsSchemaValidator.resolveSchemaSource(
      data: const {},
      registryRoot: registryRoot,
    );
    expect(schemaSource, isNotNull);

    final invalid = {
      'schemaVersion': 1,
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
