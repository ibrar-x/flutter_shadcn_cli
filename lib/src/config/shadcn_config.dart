import 'dart:convert';
import 'dart:io';

import 'package:flutter_shadcn_cli/src/config/registry_config_entry.dart';
import 'package:path/path.dart' as p;

class ShadcnConfig {
  static const String legacyDefaultNamespace = 'shadcn';

  final String? classPrefix;
  final String? themeId;
  final String? registryMode;
  final String? registryPath;
  final String? registryUrl;
  final String? installPath;
  final String? sharedPath;
  final bool? includeReadme;
  final bool? includeMeta;
  final bool? includePreview;
  final List<String>? includeFiles;
  final List<String>? excludeFiles;
  final bool? checkUpdates;
  final Map<String, String>? pathAliases;
  final Map<String, Map<String, String>>? platformTargets;
  final String? defaultNamespace;
  final Map<String, RegistryConfigEntry>? registries;

  const ShadcnConfig({
    this.classPrefix,
    this.themeId,
    this.registryMode,
    this.registryPath,
    this.registryUrl,
    this.installPath,
    this.sharedPath,
    this.includeReadme,
    this.includeMeta,
    this.includePreview,
    this.includeFiles,
    this.excludeFiles,
    this.checkUpdates = true,
    this.pathAliases,
    this.platformTargets,
    this.defaultNamespace,
    this.registries,
  });

  factory ShadcnConfig.fromJson(Map<String, dynamic> json) {
    final parsedRegistries = _parseRegistries(json['registries']);
    final resolvedNamespace = _resolveDefaultNamespace(
      requestedDefaultNamespace: json['defaultNamespace'] as String?,
      registries: parsedRegistries,
    );
    final activeRegistry = parsedRegistries?[resolvedNamespace];

    return ShadcnConfig(
      classPrefix: json['classPrefix'] as String?,
      themeId: json['themeId'] as String?,
      registryMode:
          json['registryMode'] as String? ?? activeRegistry?.registryMode,
      registryPath:
          json['registryPath'] as String? ?? activeRegistry?.registryPath,
      registryUrl: json['registryUrl'] as String? ??
          activeRegistry?.registryUrl ??
          activeRegistry?.baseUrl,
      installPath:
          json['installPath'] as String? ?? activeRegistry?.installPath,
      sharedPath: json['sharedPath'] as String? ?? activeRegistry?.sharedPath,
      includeReadme:
          json['includeReadme'] as bool? ?? activeRegistry?.includeReadme,
      checkUpdates: json['checkUpdates'] as bool? ?? true,
      includeMeta: json['includeMeta'] as bool? ?? activeRegistry?.includeMeta,
      includePreview:
          json['includePreview'] as bool? ?? activeRegistry?.includePreview,
      includeFiles: _stringListOrNull(json['includeFiles']) ??
          activeRegistry?.includeFiles,
      excludeFiles: _stringListOrNull(json['excludeFiles']) ??
          activeRegistry?.excludeFiles,
      pathAliases: (json['pathAliases'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      platformTargets: (json['platformTargets'] as Map?)?.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as Map).map(
            (innerKey, innerValue) =>
                MapEntry(innerKey.toString(), innerValue.toString()),
          ),
        ),
      ),
      defaultNamespace: resolvedNamespace,
      registries: parsedRegistries,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classPrefix': classPrefix,
      'themeId': themeId,
      'registryMode': registryMode,
      'registryPath': registryPath,
      'registryUrl': registryUrl,
      'installPath': installPath,
      'sharedPath': sharedPath,
      'includeReadme': includeReadme,
      'includeMeta': includeMeta,
      'checkUpdates': checkUpdates,
      'includePreview': includePreview,
      'includeFiles': includeFiles,
      'excludeFiles': excludeFiles,
      'pathAliases': pathAliases,
      'platformTargets': platformTargets,
      'defaultNamespace': effectiveDefaultNamespace,
      'registries': registries?.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  bool get hasRegistries => registries != null && registries!.isNotEmpty;

  String get effectiveDefaultNamespace {
    return _resolveDefaultNamespace(
      requestedDefaultNamespace: defaultNamespace,
      registries: registries,
    );
  }

  RegistryConfigEntry? registryConfig([String? namespace]) {
    final key = namespace?.trim().isNotEmpty == true
        ? namespace!.trim()
        : effectiveDefaultNamespace;
    return registries?[key];
  }

  ShadcnConfig withRegistry(String namespace, RegistryConfigEntry entry) {
    final next = Map<String, RegistryConfigEntry>.from(registries ?? const {});
    next[namespace] = entry;
    final defaultNs = defaultNamespace ?? namespace;
    final active = next[defaultNs];
    return copyWith(
      defaultNamespace: defaultNs,
      registries: next,
      registryMode: active?.registryMode ?? registryMode,
      registryPath: active?.registryPath ?? registryPath,
      registryUrl: active?.registryUrl ?? active?.baseUrl ?? registryUrl,
      installPath: active?.installPath ?? installPath,
      sharedPath: active?.sharedPath ?? sharedPath,
      includeReadme: active?.includeReadme ?? includeReadme,
      includeMeta: active?.includeMeta ?? includeMeta,
      includePreview: active?.includePreview ?? includePreview,
      includeFiles: active?.includeFiles ?? includeFiles,
      excludeFiles: active?.excludeFiles ?? excludeFiles,
    );
  }

  static File configFile(String targetDir) {
    return File(p.join(targetDir, '.shadcn', 'config.json'));
  }

  static Future<ShadcnConfig> load(
    String targetDir, {
    String defaultNamespace = legacyDefaultNamespace,
  }) async {
    final file = configFile(targetDir);
    if (!await file.exists()) {
      return const ShadcnConfig();
    }
    try {
      final content = await file.readAsString();
      final raw = jsonDecode(content) as Map<String, dynamic>;
      final migrated = _migrateLegacyConfig(
        raw,
        defaultNamespace: defaultNamespace,
      );
      final config = ShadcnConfig.fromJson(migrated);
      if (_needsLegacyMigration(raw)) {
        await save(targetDir, config);
      }
      return config;
    } catch (_) {
      return const ShadcnConfig();
    }
  }

  static Future<void> save(String targetDir, ShadcnConfig config) async {
    final file = configFile(targetDir);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  ShadcnConfig copyWith({
    String? classPrefix,
    String? themeId,
    String? registryMode,
    String? registryPath,
    String? registryUrl,
    String? installPath,
    String? sharedPath,
    bool? includeReadme,
    bool? includeMeta,
    bool? includePreview,
    List<String>? includeFiles,
    List<String>? excludeFiles,
    bool? checkUpdates,
    Map<String, String>? pathAliases,
    Map<String, Map<String, String>>? platformTargets,
    String? defaultNamespace,
    Map<String, RegistryConfigEntry>? registries,
  }) {
    return ShadcnConfig(
      classPrefix: classPrefix ?? this.classPrefix,
      themeId: themeId ?? this.themeId,
      registryMode: registryMode ?? this.registryMode,
      registryPath: registryPath ?? this.registryPath,
      registryUrl: registryUrl ?? this.registryUrl,
      installPath: installPath ?? this.installPath,
      sharedPath: sharedPath ?? this.sharedPath,
      includeReadme: includeReadme ?? this.includeReadme,
      includeMeta: includeMeta ?? this.includeMeta,
      includePreview: includePreview ?? this.includePreview,
      includeFiles: includeFiles ?? this.includeFiles,
      excludeFiles: excludeFiles ?? this.excludeFiles,
      checkUpdates: checkUpdates ?? this.checkUpdates,
      pathAliases: pathAliases ?? this.pathAliases,
      platformTargets: platformTargets ?? this.platformTargets,
      defaultNamespace: defaultNamespace ?? this.defaultNamespace,
      registries: registries ?? this.registries,
    );
  }

  static Map<String, RegistryConfigEntry>? _parseRegistries(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final parsed = <String, RegistryConfigEntry>{};
    raw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsed[key.toString()] = RegistryConfigEntry.fromJson(value);
        return;
      }
      if (value is Map) {
        parsed[key.toString()] = RegistryConfigEntry.fromJson(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    });
    return parsed.isEmpty ? null : parsed;
  }

  static String _resolveDefaultNamespace({
    required String? requestedDefaultNamespace,
    required Map<String, RegistryConfigEntry>? registries,
  }) {
    final trimmed = requestedDefaultNamespace?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    if (registries != null && registries.isNotEmpty) {
      return registries.keys.first;
    }
    return legacyDefaultNamespace;
  }

  static bool _needsLegacyMigration(Map<String, dynamic> raw) {
    if (raw['registries'] is Map) {
      return false;
    }
    return raw.containsKey('installPath') ||
        raw.containsKey('sharedPath') ||
        raw.containsKey('registryMode') ||
        raw.containsKey('registryPath') ||
        raw.containsKey('registryUrl');
  }

  static Map<String, dynamic> _migrateLegacyConfig(
    Map<String, dynamic> raw, {
    required String defaultNamespace,
  }) {
    if (!_needsLegacyMigration(raw)) {
      return raw;
    }

    final namespace =
        (raw['defaultNamespace'] as String?)?.trim().isNotEmpty == true
            ? (raw['defaultNamespace'] as String).trim()
            : defaultNamespace;

    final migrated = Map<String, dynamic>.from(raw);
    final registries = <String, dynamic>{
      namespace: {
        'registryMode': raw['registryMode'],
        'registryPath': raw['registryPath'],
        'registryUrl': raw['registryUrl'],
        'installPath': raw['installPath'],
        'sharedPath': raw['sharedPath'],
        'includeReadme': raw['includeReadme'],
        'includeMeta': raw['includeMeta'],
        'includePreview': raw['includePreview'],
        'includeFiles': raw['includeFiles'],
        'excludeFiles': raw['excludeFiles'],
        'enabled': true,
      },
    };
    migrated['defaultNamespace'] = namespace;
    migrated['registries'] = registries;
    return migrated;
  }
}

List<String>? _stringListOrNull(dynamic raw) {
  if (raw is! List) {
    return null;
  }
  final values = raw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
  return values.isEmpty ? null : values;
}
