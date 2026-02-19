import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class RegistryStateEntry {
  final String? installPath;
  final String? sharedPath;
  final String? themeId;

  const RegistryStateEntry({
    this.installPath,
    this.sharedPath,
    this.themeId,
  });

  factory RegistryStateEntry.fromJson(Map<String, dynamic> json) {
    return RegistryStateEntry(
      installPath: json['installPath'] as String?,
      sharedPath: json['sharedPath'] as String?,
      themeId: json['themeId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'installPath': installPath,
      'sharedPath': sharedPath,
      'themeId': themeId,
    };
  }
}

class ShadcnState {
  static const String legacyDefaultNamespace = 'shadcn';

  final String? installPath;
  final String? sharedPath;
  final String? themeId;
  final List<String>? managedDependencies;
  final Map<String, RegistryStateEntry>? registries;

  const ShadcnState({
    this.installPath,
    this.sharedPath,
    this.themeId,
    this.managedDependencies,
    this.registries,
  });

  factory ShadcnState.fromJson(Map<String, dynamic> json) {
    final parsedRegistries = _parseRegistries(json['registries']);
    final defaultNamespace = _resolveDefaultNamespace(
      requestedDefaultNamespace: json['defaultNamespace'] as String?,
      registries: parsedRegistries,
    );
    final activeRegistry = parsedRegistries?[defaultNamespace];

    return ShadcnState(
      installPath:
          json['installPath'] as String? ?? activeRegistry?.installPath,
      sharedPath: json['sharedPath'] as String? ?? activeRegistry?.sharedPath,
      themeId: json['themeId'] as String? ?? activeRegistry?.themeId,
      managedDependencies: (json['managedDependencies'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      registries: parsedRegistries,
    );
  }

  Map<String, dynamic> toJson() {
    final defaultNamespace = _resolveDefaultNamespace(
      requestedDefaultNamespace: null,
      registries: registries,
    );
    final active = registries?[defaultNamespace];
    return {
      'installPath': installPath ?? active?.installPath,
      'sharedPath': sharedPath ?? active?.sharedPath,
      'themeId': themeId ?? active?.themeId,
      'managedDependencies': managedDependencies,
      'defaultNamespace': defaultNamespace,
      'registries': registries?.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  static File stateFile(String targetDir) {
    return File(p.join(targetDir, '.shadcn', 'state.json'));
  }

  static Future<ShadcnState> load(
    String targetDir, {
    String defaultNamespace = legacyDefaultNamespace,
  }) async {
    final file = stateFile(targetDir);
    if (!await file.exists()) {
      return const ShadcnState();
    }
    try {
      final content = await file.readAsString();
      final raw = jsonDecode(content) as Map<String, dynamic>;
      final migrated = _migrateLegacyState(
        raw,
        defaultNamespace: defaultNamespace,
      );
      final state = ShadcnState.fromJson(migrated);
      if (_needsLegacyMigration(raw)) {
        await save(targetDir, state);
      }
      return state;
    } catch (_) {
      return const ShadcnState();
    }
  }

  static Future<void> save(String targetDir, ShadcnState state) async {
    final file = stateFile(targetDir);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(state.toJson()));
  }

  RegistryStateEntry? registryState([String? namespace]) {
    final key = namespace?.trim().isNotEmpty == true
        ? namespace!.trim()
        : _resolveDefaultNamespace(
            requestedDefaultNamespace: null,
            registries: registries,
          );
    return registries?[key];
  }

  ShadcnState withRegistryState(String namespace, RegistryStateEntry entry) {
    final next = Map<String, RegistryStateEntry>.from(registries ?? const {});
    next[namespace] = entry;
    return ShadcnState(
      installPath: installPath ?? entry.installPath,
      sharedPath: sharedPath ?? entry.sharedPath,
      themeId: themeId ?? entry.themeId,
      managedDependencies: managedDependencies,
      registries: next,
    );
  }

  static Map<String, RegistryStateEntry>? _parseRegistries(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final parsed = <String, RegistryStateEntry>{};
    raw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsed[key.toString()] = RegistryStateEntry.fromJson(value);
        return;
      }
      if (value is Map) {
        parsed[key.toString()] = RegistryStateEntry.fromJson(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    });
    return parsed.isEmpty ? null : parsed;
  }

  static String _resolveDefaultNamespace({
    required String? requestedDefaultNamespace,
    required Map<String, RegistryStateEntry>? registries,
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
        raw.containsKey('themeId');
  }

  static Map<String, dynamic> _migrateLegacyState(
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
    migrated['defaultNamespace'] = namespace;
    migrated['registries'] = {
      namespace: {
        'installPath': raw['installPath'],
        'sharedPath': raw['sharedPath'],
        'themeId': raw['themeId'],
      },
    };
    return migrated;
  }
}
