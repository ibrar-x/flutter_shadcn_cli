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
  final List<RegistryFile> files;
  final List<String> shared;
  final List<String> dependsOn;
  final Map<String, dynamic> pubspec;

  Component.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        name = json['name'],
        files = (json['files'] as List)
            .map((e) => RegistryFile.fromJson(e))
            .toList(),
        shared = List<String>.from(json['shared'] ?? []),
        dependsOn = List<String>.from(json['dependsOn'] ?? []),
        pubspec = json['pubspec'] ?? {};
}

class RegistryFile {
  final String source;
  final String destination;

  RegistryFile.fromJson(Map<String, dynamic> json)
      : source = json['source'],
        destination = json['destination'];
}
