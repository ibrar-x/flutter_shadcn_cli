import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/resolver_v1.dart';
import 'package:http/http.dart' as http;
import 'package:json_schema/json_schema.dart';
import 'package:path/path.dart' as p;

const String defaultRegistriesDirectoryUrl =
    'https://flutter-shadcn.github.io/registry-directory/registries/registries.json';

class RegistryDirectoryException implements Exception {
  final String message;

  RegistryDirectoryException(this.message);

  @override
  String toString() => message;
}

class RegistryDirectory {
  final int schemaVersion;
  final List<RegistryDirectoryEntry> registries;
  final Map<String, dynamic> raw;

  const RegistryDirectory({
    required this.schemaVersion,
    required this.registries,
    required this.raw,
  });

  factory RegistryDirectory.fromJson(Map<String, dynamic> json) {
    final items = (json['registries'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (entry) => RegistryDirectoryEntry.fromJson(
            entry.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
    return RegistryDirectory(
      schemaVersion: json['schemaVersion'] as int? ?? 0,
      registries: items,
      raw: json,
    );
  }
}

class RegistryDirectoryEntry {
  final String id;
  final String displayName;
  final String minCliVersion;
  final String baseUrl;
  final String namespace;
  final String installRoot;
  final Map<String, String> paths;
  final Map<String, dynamic>? init;
  final Map<String, dynamic> raw;

  const RegistryDirectoryEntry({
    required this.id,
    required this.displayName,
    required this.minCliVersion,
    required this.baseUrl,
    required this.namespace,
    required this.installRoot,
    required this.paths,
    required this.init,
    required this.raw,
  });

  factory RegistryDirectoryEntry.fromJson(Map<String, dynamic> json) {
    final install = (json['install'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value),
        ) ??
        const <String, dynamic>{};
    final paths = (json['paths'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ) ??
        const <String, String>{};
    return RegistryDirectoryEntry(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      minCliVersion: json['minCliVersion']?.toString() ?? '0.0.0',
      baseUrl: json['baseUrl']?.toString() ?? '',
      namespace: install['namespace']?.toString() ?? '',
      installRoot: install['root']?.toString() ?? '',
      paths: paths,
      init: (json['init'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      raw: json,
    );
  }

  String get componentsPath => paths['componentsJson'] ?? 'components.json';
  String? get componentsSchemaPath => paths['componentsSchemaJson'];
  String? get indexPath => paths['indexJson'];

  bool get hasInlineInit {
    final initMap = init;
    if (initMap == null) {
      return false;
    }
    return initMap['version'] == 1 && initMap['actions'] is List;
  }
}

class RegistryDirectoryClient {
  final http.Client _client;
  final String _schemaPath;

  RegistryDirectoryClient({
    http.Client? client,
    String schemaPath = 'lib/src/schemas/registries.schema.json',
  })  : _client = client ?? http.Client(),
        _schemaPath = schemaPath;

  void close() {
    _client.close();
  }

  Future<RegistryDirectory> load({
    required String projectRoot,
    String directoryUrl = defaultRegistriesDirectoryUrl,
    String? directoryPath,
    bool offline = false,
    String? currentCliVersion,
    CliLogger? logger,
  }) async {
    final String response;
    final localPath = directoryPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      response = await _readLocalDirectoryFile(
        projectRoot: projectRoot,
        directoryPath: localPath,
      );
    } else {
      final cacheBody = _cacheFile(projectRoot, 'registries.json');
      final cacheMeta = _cacheFile(projectRoot, 'registries.meta.json');
      response = await _fetchWithEtag(
        url: Uri.parse(directoryUrl),
        bodyCacheFile: cacheBody,
        metaCacheFile: cacheMeta,
        offline: offline,
        logger: logger,
      );
    }
    final decoded = jsonDecode(response) as Map<String, dynamic>;
    await _validateSchema(decoded);

    final directory = RegistryDirectory.fromJson(decoded);
    if (currentCliVersion == null || currentCliVersion.trim().isEmpty) {
      return directory;
    }

    final filtered = directory.registries
        .where(
          (entry) => _isVersionAtLeast(
            currentCliVersion.trim(),
            entry.minCliVersion.trim(),
          ),
        )
        .toList();
    return RegistryDirectory(
      schemaVersion: directory.schemaVersion,
      registries: filtered,
      raw: directory.raw,
    );
  }

  Future<String> _readLocalDirectoryFile({
    required String projectRoot,
    required String directoryPath,
  }) async {
    final resolved = _resolveDirectoryPath(projectRoot, directoryPath);
    final direct = File(resolved);
    final dir = Directory(resolved);
    final candidate =
        dir.existsSync() ? File(p.join(resolved, 'registries.json')) : direct;
    if (!await candidate.exists()) {
      throw RegistryDirectoryException(
        'Local registries.json not found: ${candidate.path}',
      );
    }
    return candidate.readAsString();
  }

  String _resolveDirectoryPath(String projectRoot, String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (p.isAbsolute(trimmed)) {
      return p.normalize(trimmed);
    }
    return p.normalize(p.join(projectRoot, trimmed));
  }

  Future<String> loadComponentsJson({
    required String projectRoot,
    required RegistryDirectoryEntry registry,
    bool offline = false,
    CliLogger? logger,
  }) async {
    final key = _sanitizeCacheKey('components_${registry.namespace}');
    final cacheBody = _cacheFile(projectRoot, '$key.json');
    final cacheMeta = _cacheFile(projectRoot, '$key.meta.json');
    final uri =
        ResolverV1.resolveUrl(registry.baseUrl, registry.componentsPath);
    return _fetchWithEtag(
      url: uri,
      bodyCacheFile: cacheBody,
      metaCacheFile: cacheMeta,
      offline: offline,
      logger: logger,
    );
  }

  Future<String> _fetchWithEtag({
    required Uri url,
    required File bodyCacheFile,
    required File metaCacheFile,
    required bool offline,
    required CliLogger? logger,
  }) async {
    if (offline) {
      if (!await bodyCacheFile.exists()) {
        throw RegistryDirectoryException(
          'Offline mode: cache not found for ${url.toString()}',
        );
      }
      return bodyCacheFile.readAsString();
    }

    final etag = await _readEtag(metaCacheFile);
    final headers = <String, String>{};
    if (etag != null && etag.isNotEmpty) {
      headers['If-None-Match'] = etag;
    }

    try {
      final response = await _client.get(url, headers: headers);
      if (response.statusCode == 304) {
        if (!await bodyCacheFile.exists()) {
          throw RegistryDirectoryException(
            'Received 304 but cache body missing for ${url.toString()}',
          );
        }
        return bodyCacheFile.readAsString();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RegistryDirectoryException(
          'Failed to fetch ${url.toString()} (${response.statusCode})',
        );
      }
      await _writeCache(
        bodyCacheFile: bodyCacheFile,
        metaCacheFile: metaCacheFile,
        body: response.body,
        etag: response.headers['etag'],
      );
      return response.body;
    } catch (e) {
      if (await bodyCacheFile.exists()) {
        logger?.warn(
          'Using stale cache after fetch failure for ${url.toString()}: $e',
        );
        return bodyCacheFile.readAsString();
      }
      rethrow;
    }
  }

  Future<void> _validateSchema(Map<String, dynamic> directoryJson) async {
    final schemaFile = await _resolveSchemaFile();
    if (!schemaFile.existsSync()) {
      throw RegistryDirectoryException(
        'Schema file not found: ${schemaFile.path}',
      );
    }
    final schemaData = jsonDecode(await schemaFile.readAsString());
    final schema = JsonSchema.create(schemaData);
    final result = schema.validate(directoryJson);
    if (!result.isValid) {
      final errors = result.errors.map((e) => e.toString()).join('; ');
      throw RegistryDirectoryException(
          'registries.json schema invalid: $errors');
    }
  }

  Future<File> _resolveSchemaFile() async {
    final direct = File(_schemaPath);
    if (direct.existsSync()) {
      return direct;
    }

    final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:flutter_shadcn_cli/flutter_shadcn_cli.dart'),
    );
    if (packageUri != null) {
      final libFile = File.fromUri(packageUri);
      final packageRoot = libFile.parent.parent.path;
      final fallback = File(
        p.join(packageRoot, 'lib', 'src', 'schemas', 'registries.schema.json'),
      );
      if (fallback.existsSync()) {
        return fallback;
      }
    }

    return direct;
  }

  File _cacheFile(String projectRoot, String name) {
    return File(p.join(projectRoot, '.shadcn', 'cache', name));
  }

  Future<String?> _readEtag(File metaCacheFile) async {
    if (!await metaCacheFile.exists()) {
      return null;
    }
    try {
      final raw = jsonDecode(await metaCacheFile.readAsString());
      if (raw is Map<String, dynamic>) {
        return raw['etag'] as String?;
      }
      if (raw is Map) {
        return raw['etag']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeCache({
    required File bodyCacheFile,
    required File metaCacheFile,
    required String body,
    required String? etag,
  }) async {
    if (!await bodyCacheFile.parent.exists()) {
      await bodyCacheFile.parent.create(recursive: true);
    }
    await bodyCacheFile.writeAsString(body);
    await metaCacheFile.writeAsString(
      jsonEncode({
        'etag': etag,
      }),
    );
  }

  static String _sanitizeCacheKey(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}

bool _isVersionAtLeast(String currentVersion, String minimumVersion) {
  final current = _parseSemVerCore(currentVersion);
  final minimum = _parseSemVerCore(minimumVersion);
  if (current == null || minimum == null) {
    return false;
  }

  for (var i = 0; i < 3; i++) {
    if (current[i] > minimum[i]) {
      return true;
    }
    if (current[i] < minimum[i]) {
      return false;
    }
  }
  return true;
}

List<int>? _parseSemVerCore(String version) {
  final core = version.split(RegExp(r'[-+]')).first.trim();
  final parts = core.split('.');
  if (parts.length != 3) {
    return null;
  }
  final parsed = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value < 0) {
      return null;
    }
    parsed.add(value);
  }
  return parsed;
}
