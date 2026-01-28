import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class Registry {
  final Map<String, dynamic> data;
  final RegistryLocation registryRoot;
  final RegistryLocation sourceRoot;

  Registry(this.data, this.registryRoot, this.sourceRoot);

  static Future<Registry> load({
    required RegistryLocation registryRoot,
    required RegistryLocation sourceRoot,
  }) async {
    final content = await registryRoot.readString('components.json');
    return Registry(jsonDecode(content), registryRoot, sourceRoot);
  }

  Map<String, String> get defaults {
    return Map<String, String>.from(data['defaults'] ?? {});
  }

  List<SharedItem> get shared {
    return (data['shared'] as List).map((e) => SharedItem.fromJson(e)).toList();
  }

  List<Component> get components {
    return (data['components'] as List)
        .map((e) => Component.fromJson(e))
        .toList();
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
}

class RegistryLocation {
  final String root;
  final bool isRemote;
  final http.Client _client;

  RegistryLocation.local(this.root)
      : isRemote = false,
        _client = http.Client();

  RegistryLocation.remote(this.root)
      : isRemote = true,
        _client = http.Client();

  Future<List<int>> readBytes(String relativePath) async {
    if (isRemote) {
      final uri = _resolveRemote(relativePath);
      final response = await _client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to fetch $uri (${response.statusCode})');
      }
      return response.bodyBytes;
    }
    final file = File(p.join(root, relativePath));
    if (!await file.exists()) {
      throw Exception('File not found: ${file.path}');
    }
    return file.readAsBytes();
  }

  Future<String> readString(String relativePath) async {
    final bytes = await readBytes(relativePath);
    return utf8.decode(bytes);
  }

  String describe(String relativePath) {
    if (isRemote) {
      return _resolveRemote(relativePath).toString();
    }
    return p.join(root, relativePath);
  }

  Uri _resolveRemote(String relativePath) {
    final normalized = relativePath.replaceFirst(RegExp(r'^/+'), '');
    final base = root.endsWith('/') ? root : '$root/';
    return Uri.parse(base).resolve(normalized);
  }
}

class SharedItem {
  final String id;
  final List<RegistryFile> files;

  SharedItem.fromJson(Map<String, dynamic> json)
      : id = json['id'],
      files = (json['files'] as List)
        .map((e) => RegistryFile.fromJson(e))
        .toList();
}

class Component {
  final String id;
  final String name;
  final String? category;
  final List<RegistryFile> files;
  final List<String> shared;
  final List<String> dependsOn;
  final List<String> assets;
  final List<FontEntry> fonts;
  final Map<String, dynamic> pubspec;
  final List<String> postInstall;
  final Map<String, PlatformEntry> platform;

  Component.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        category = json['category'] as String?,
        files = (json['files'] as List)
            .map((e) => RegistryFile.fromJson(e))
            .toList(),
        shared = List<String>.from(json['shared'] ?? []),
        dependsOn = List<String>.from(json['dependsOn'] ?? []),
        assets = List<String>.from(json['assets'] ?? []),
        fonts = (json['fonts'] as List<dynamic>? ?? const [])
            .map((e) => FontEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      pubspec = json['pubspec'] ?? {},
      postInstall = List<String>.from(json['postInstall'] ?? []),
      platform = (json['platform'] as Map<String, dynamic>? ?? const {})
        .map((key, value) => MapEntry(
            key,
            PlatformEntry.fromJson(value as Map<String, dynamic>),
          ));
}

class RegistryFile {
  final String source;
  final String destination;
  final List<FileDependency> dependsOn;

  RegistryFile({
    required this.source,
    required this.destination,
    this.dependsOn = const [],
  });

  factory RegistryFile.fromJson(dynamic json) {
    if (json is String) {
      return RegistryFile(source: json, destination: json);
    }
    final map = json as Map<String, dynamic>;
    final deps = (map['dependsOn'] as List<dynamic>? ?? const [])
        .map((e) => FileDependency.fromJson(e))
        .toList();
    return RegistryFile(
      source: map['source'] as String,
      destination: map['destination'] as String,
      dependsOn: deps,
    );
  }
}

class FileDependency {
  final String source;
  final bool optional;

  const FileDependency({required this.source, this.optional = false});

  factory FileDependency.fromJson(dynamic json) {
    if (json is String) {
      return FileDependency(source: json);
    }
    final map = json as Map<String, dynamic>;
    return FileDependency(
      source: map['source'] as String,
      optional: map['optional'] as bool? ?? false,
    );
  }
}

class PlatformEntry {
  final List<String> permissions;
  final Map<String, String> infoPlist;
  final List<String> entitlements;
  final List<String> podfile;
  final List<String> gradle;
  final List<String> config;
  final List<String> notes;

  PlatformEntry({
    this.permissions = const [],
    this.infoPlist = const {},
    this.entitlements = const [],
    this.podfile = const [],
    this.gradle = const [],
    this.config = const [],
    this.notes = const [],
  });

  factory PlatformEntry.fromJson(Map<String, dynamic> json) {
    return PlatformEntry(
      permissions: List<String>.from(json['permissions'] ?? const []),
      infoPlist: (json['infoPlist'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
      entitlements: List<String>.from(json['entitlements'] ?? const []),
      podfile: List<String>.from(json['podfile'] ?? const []),
      gradle: List<String>.from(json['gradle'] ?? const []),
      config: List<String>.from(json['config'] ?? const []),
      notes: List<String>.from(json['notes'] ?? const []),
    );
  }
}

class FontEntry {
  final String family;
  final List<FontAsset> fonts;

  FontEntry.fromJson(Map<String, dynamic> json)
      : family = json['family'] as String,
        fonts = (json['fonts'] as List<dynamic>? ?? const [])
            .map((e) => FontAsset.fromJson(e as Map<String, dynamic>))
            .toList();
}

class FontAsset {
  final String asset;
  final int? weight;
  final String? style;

  FontAsset.fromJson(Map<String, dynamic> json)
      : asset = json['asset'] as String,
        weight = json['weight'] as int?,
        style = json['style'] as String?;
}
