import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/registry/component.dart';
import 'package:flutter_shadcn_cli/src/registry/components_schema_validator.dart';
import 'package:flutter_shadcn_cli/src/registry/registry_location.dart';
import 'package:flutter_shadcn_cli/src/registry/shared_item.dart';

class Registry {
  final Map<String, dynamic> data;
  final RegistryLocation registryRoot;
  final RegistryLocation sourceRoot;

  Registry(this.data, this.registryRoot, this.sourceRoot);

  static Future<Registry> load({
    required RegistryLocation registryRoot,
    required RegistryLocation sourceRoot,
    String? schemaPath,
    String? cachePath,
    String componentsPath = 'components.json',
    String? trustMode,
    String? trustSha256,
    bool skipIntegrity = false,
    bool offline = false,
    CliLogger? logger,
  }) async {
    String content;
    if (offline && registryRoot.isRemote) {
      if (cachePath == null) {
        throw Exception('Offline mode: cache path not available.');
      }
      final cacheFile = File(cachePath);
      if (!await cacheFile.exists()) {
        throw Exception('Offline mode: cached components.json not found.');
      }
      content = await cacheFile.readAsString();
    } else {
      content = await registryRoot.readString(componentsPath);
    }

    if (!offline && cachePath != null && registryRoot.isRemote) {
      try {
        final cacheFile = File(cachePath);
        if (!await cacheFile.parent.exists()) {
          await cacheFile.parent.create(recursive: true);
        }
        await cacheFile.writeAsString(content);
      } catch (e) {
        logger?.warn('Failed to cache components.json: $e');
      }
    }

    _verifyIntegrity(
      content: content,
      trustMode: trustMode,
      trustSha256: trustSha256,
      skipIntegrity: skipIntegrity,
      logger: logger,
    );

    return fromContent(
      content: content,
      registryRoot: registryRoot,
      sourceRoot: sourceRoot,
      schemaPath: schemaPath,
      logger: logger,
    );
  }

  static Future<Registry> fromContent({
    required String content,
    required RegistryLocation registryRoot,
    required RegistryLocation sourceRoot,
    String? schemaPath,
    CliLogger? logger,
  }) async {
    final data = jsonDecode(content);

    final schemaSource = ComponentsSchemaValidator.resolveSchemaSource(
      data: data is Map<String, dynamic> ? data : const {},
      registryRoot: registryRoot,
      schemaPathOverride: schemaPath,
    );
    if (schemaSource != null) {
      final result = await ComponentsSchemaValidator.validateWithJsonSchema(
        data,
        schemaSource,
      );
      if (!result.isValid) {
        logger?.warn(
          'components.json schema validation failed (${result.errors.length} issues).',
        );
      }
    }

    return Registry(data, registryRoot, sourceRoot);
  }

  Map<String, String> get defaults {
    return Map<String, String>.from(data['defaults'] ?? {});
  }

  List<SharedItem> get shared {
    final raw = data['shared'];
    if (raw is! List) {
      return [];
    }
    return raw.map((e) => SharedItem.fromJson(e)).toList();
  }

  List<Component> get components {
    final raw = data['components'];
    if (raw is! List) {
      return [];
    }
    return raw.map((e) => Component.fromJson(e)).toList();
  }

  Component? getComponent(String name) {
    try {
      return components.firstWhere(
        (c) => c.id == name || c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<int>> readSourceBytes(String relativePath) {
    return sourceRoot.readBytes(relativePath);
  }

  String describeSource(String relativePath) {
    return sourceRoot.describe(relativePath);
  }

  static void _verifyIntegrity({
    required String content,
    required String? trustMode,
    required String? trustSha256,
    required bool skipIntegrity,
    required CliLogger? logger,
  }) {
    if (skipIntegrity) {
      return;
    }
    if ((trustMode ?? '').trim().toLowerCase() != 'sha256') {
      return;
    }
    final expected = trustSha256?.trim().toLowerCase();
    if (expected == null || expected.isEmpty) {
      return;
    }
    final digest = sha256.convert(utf8.encode(content)).toString().toLowerCase();
    logger?.detail('components.json sha256: $digest');
    if (digest != expected) {
      throw Exception(
        'Integrity check failed: expected $expected but received $digest',
      );
    }
  }
}
