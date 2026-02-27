import 'dart:convert';
import 'dart:io';

import 'package:flutter_shadcn_cli/src/registry/registry_location.dart';
import 'package:flutter_shadcn_cli/src/registry/schema_source.dart';
import 'package:flutter_shadcn_cli/src/registry/schema_validation_result.dart';
import 'package:http/http.dart' as http;
import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;

class ComponentsSchemaValidator {
  static SchemaSource? resolveSchemaSource({
    required Map<String, dynamic> data,
    required RegistryLocation registryRoot,
    String? schemaPathOverride,
  }) {
    final override = schemaPathOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return _schemaSourceFromString(override, registryRoot);
    }

    final schemaRef = data[r'$schema'];
    if (schemaRef is String && schemaRef.trim().isNotEmpty) {
      final resolved = _schemaSourceFromString(schemaRef.trim(), registryRoot);
      if (resolved != null) {
        return resolved;
      }
    }

    return SchemaSource(
      label: registryRoot.describe('components.schema.json'),
      read: () => registryRoot.readString('components.schema.json'),
    );
  }

  static Future<SchemaValidationResult> validateWithJsonSchema(
    dynamic data,
    SchemaSource schemaSource,
  ) async {
    try {
      final schemaContent = await schemaSource.read();
      final schemaData = jsonDecode(schemaContent);
      final schema = JsonSchema.create(schemaData);
      final result = schema.validate(data);
      final errors = result.errors.map((e) => e.toString()).toList();
      return SchemaValidationResult(isValid: result.isValid, errors: errors);
    } catch (e) {
      return SchemaValidationResult(
        isValid: false,
        errors: ['Failed to validate schema: $e'],
      );
    }
  }

  static SchemaValidationResult validateLegacy(
    dynamic data,
    String schemaPath,
  ) {
    final errors = <String>[];

    if (!File(schemaPath).existsSync()) {
      errors.add('Schema file not found: $schemaPath');
      return SchemaValidationResult(isValid: false, errors: errors);
    }

    if (data is! Map<String, dynamic>) {
      errors.add('Root must be a JSON object');
      return SchemaValidationResult(isValid: false, errors: errors);
    }

    void requireKey(String key) {
      if (!data.containsKey(key)) {
        errors.add('Missing required key: $key');
      }
    }

    requireKey('schemaVersion');
    requireKey('name');
    requireKey('flutter');
    requireKey('defaults');
    requireKey('shared');
    requireKey('components');

    if (data['schemaVersion'] is! int || (data['schemaVersion'] as int) < 1) {
      errors.add('schemaVersion must be an integer >= 1');
    }
    if (data['name'] is! String) {
      errors.add('name must be a string');
    }

    final flutter = data['flutter'];
    if (flutter is! Map<String, dynamic>) {
      errors.add('flutter must be an object');
    } else if (flutter['minSdk'] is! String) {
      errors.add('flutter.minSdk must be a string');
    }

    final defaults = data['defaults'];
    if (defaults is! Map<String, dynamic>) {
      errors.add('defaults must be an object');
    } else {
      if (defaults['installPath'] is! String) {
        errors.add('defaults.installPath must be a string');
      }
      if (defaults['sharedPath'] is! String) {
        errors.add('defaults.sharedPath must be a string');
      }
    }

    final shared = data['shared'];
    if (shared is! List) {
      errors.add('shared must be an array');
    } else {
      for (var i = 0; i < shared.length; i++) {
        final entry = shared[i];
        if (entry is! Map<String, dynamic>) {
          errors.add('shared[$i] must be an object');
          continue;
        }
        if (entry['id'] is! String) {
          errors.add('shared[$i].id must be a string');
        }
        final files = entry['files'];
        if (files is! List) {
          errors.add('shared[$i].files must be an array');
        } else {
          _validateFileMappings(files, errors, 'shared[$i].files');
        }
      }
    }

    final components = data['components'];
    if (components is! List) {
      errors.add('components must be an array');
    } else {
      for (var i = 0; i < components.length; i++) {
        final entry = components[i];
        if (entry is! Map<String, dynamic>) {
          errors.add('components[$i] must be an object');
          continue;
        }
        _validateComponent(entry, errors, 'components[$i]');
      }
    }

    return SchemaValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  static SchemaSource? _schemaSourceFromString(
    String value,
    RegistryLocation registryRoot,
  ) {
    final trimmed = value.trim();
    if (_isHttpUrl(trimmed)) {
      return SchemaSource(
        label: trimmed,
        read: () async {
          final response = await http.get(Uri.parse(trimmed));
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception(
              'Failed to fetch schema ($trimmed) (${response.statusCode})',
            );
          }
          return response.body;
        },
      );
    }

    if (File(trimmed).existsSync()) {
      return SchemaSource(
        label: trimmed,
        read: () => File(trimmed).readAsString(),
      );
    }

    final relative = _normalizeSchemaPath(trimmed);
    return SchemaSource(
      label: registryRoot.describe(relative),
      read: () => registryRoot.readString(relative),
    );
  }

  static bool _isHttpUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String _normalizeSchemaPath(String value) {
    var normalized = value.replaceAll('\\', '/');
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
    return p.posix.normalize(normalized);
  }

  static void _validateComponent(
    Map<String, dynamic> entry,
    List<String> errors,
    String path,
  ) {
    void requireField(String key) {
      if (!entry.containsKey(key)) {
        errors.add('$path missing required key: $key');
      }
    }

    requireField('id');
    requireField('name');
    requireField('description');
    requireField('category');
    requireField('files');
    requireField('shared');
    requireField('dependsOn');
    requireField('pubspec');
    requireField('assets');
    requireField('postInstall');

    if (entry['id'] is! String) {
      errors.add('$path.id must be a string');
    }
    if (entry['name'] is! String) {
      errors.add('$path.name must be a string');
    }
    if (entry['description'] is! String) {
      errors.add('$path.description must be a string');
    }
    if (entry['category'] is! String) {
      errors.add('$path.category must be a string');
    }

    final files = entry['files'];
    if (files is! List) {
      errors.add('$path.files must be an array');
    } else {
      _validateFileMappings(files, errors, '$path.files');
    }

    if (!_isStringList(entry['shared'])) {
      errors.add('$path.shared must be an array of strings');
    }
    if (!_isStringList(entry['dependsOn'])) {
      errors.add('$path.dependsOn must be an array of strings');
    }
    if (!_isStringList(entry['assets'])) {
      errors.add('$path.assets must be an array of strings');
    }
    if (!_isStringList(entry['postInstall'])) {
      errors.add('$path.postInstall must be an array of strings');
    }

    final pubspec = entry['pubspec'];
    if (pubspec is! Map<String, dynamic>) {
      errors.add('$path.pubspec must be an object');
    } else {
      if (pubspec['dependencies'] is! Map) {
        errors.add('$path.pubspec.dependencies must be an object');
      } else if (!_isStringMap(pubspec['dependencies'])) {
        errors.add('$path.pubspec.dependencies values must be strings');
      }
      if (pubspec['dev_dependencies'] != null &&
          !_isStringMap(pubspec['dev_dependencies'])) {
        errors.add('$path.pubspec.dev_dependencies values must be strings');
      }
    }

    final fonts = entry['fonts'];
    if (fonts != null) {
      if (fonts is! List) {
        errors.add('$path.fonts must be an array');
      } else {
        for (var i = 0; i < fonts.length; i++) {
          final fontEntry = fonts[i];
          if (fontEntry is! Map<String, dynamic>) {
            errors.add('$path.fonts[$i] must be an object');
            continue;
          }
          if (fontEntry['family'] is! String) {
            errors.add('$path.fonts[$i].family must be a string');
          }
          final fontFiles = fontEntry['fonts'];
          if (fontFiles is! List) {
            errors.add('$path.fonts[$i].fonts must be an array');
          } else {
            for (var j = 0; j < fontFiles.length; j++) {
              final file = fontFiles[j];
              if (file is! Map<String, dynamic>) {
                errors.add('$path.fonts[$i].fonts[$j] must be an object');
                continue;
              }
              if (file['asset'] is! String) {
                errors.add('$path.fonts[$i].fonts[$j].asset must be a string');
              }
              if (file['weight'] != null && file['weight'] is! int) {
                errors
                    .add('$path.fonts[$i].fonts[$j].weight must be an integer');
              }
              if (file['style'] != null && file['style'] is! String) {
                errors.add('$path.fonts[$i].fonts[$j].style must be a string');
              }
            }
          }
        }
      }
    }

    final platform = entry['platform'];
    if (platform != null) {
      if (platform is! Map) {
        errors.add('$path.platform must be an object');
      } else {
        platform.forEach((key, value) {
          if (value is! Map) {
            errors.add('$path.platform.$key must be an object');
            return;
          }
          if (!_isStringList(value['permissions'] ?? const [])) {
            errors.add(
                '$path.platform.$key.permissions must be an array of strings');
          }
          if (!_isStringList(value['entitlements'] ?? const [])) {
            errors.add(
                '$path.platform.$key.entitlements must be an array of strings');
          }
          if (!_isStringList(value['podfile'] ?? const [])) {
            errors
                .add('$path.platform.$key.podfile must be an array of strings');
          }
          if (!_isStringList(value['gradle'] ?? const [])) {
            errors
                .add('$path.platform.$key.gradle must be an array of strings');
          }
          if (!_isStringList(value['config'] ?? const [])) {
            errors
                .add('$path.platform.$key.config must be an array of strings');
          }
          if (!_isStringList(value['notes'] ?? const [])) {
            errors.add('$path.platform.$key.notes must be an array of strings');
          }
          if (value['infoPlist'] != null && !_isStringMap(value['infoPlist'])) {
            errors.add(
                '$path.platform.$key.infoPlist must be an object of strings');
          }
        });
      }
    }
  }

  static void _validateFileMappings(
    List<dynamic> files,
    List<String> errors,
    String path,
  ) {
    for (var i = 0; i < files.length; i++) {
      final entry = files[i];
      if (entry is String) {
        continue;
      }
      if (entry is! Map<String, dynamic>) {
        errors.add('$path[$i] must be a string or object');
        continue;
      }
      if (entry['source'] is! String) {
        errors.add('$path[$i].source must be a string');
      }
      if (entry['destination'] is! String) {
        errors.add('$path[$i].destination must be a string');
      }
      final dependsOn = entry['dependsOn'];
      if (dependsOn != null) {
        if (dependsOn is! List) {
          errors.add('$path[$i].dependsOn must be an array');
        } else {
          for (var j = 0; j < dependsOn.length; j++) {
            final dep = dependsOn[j];
            if (dep is String) {
              continue;
            }
            if (dep is! Map<String, dynamic>) {
              errors.add('$path[$i].dependsOn[$j] must be a string or object');
              continue;
            }
            if (dep['source'] is! String) {
              errors.add('$path[$i].dependsOn[$j].source must be a string');
            }
            if (dep['optional'] != null && dep['optional'] is! bool) {
              errors.add('$path[$i].dependsOn[$j].optional must be a boolean');
            }
          }
        }
      }
    }
  }

  static bool _isStringList(dynamic value) {
    if (value is! List) {
      return false;
    }
    return value.every((item) => item is String);
  }

  static bool _isStringMap(dynamic value) {
    if (value is! Map) {
      return false;
    }
    return value.values.every((item) => item is String);
  }
}
