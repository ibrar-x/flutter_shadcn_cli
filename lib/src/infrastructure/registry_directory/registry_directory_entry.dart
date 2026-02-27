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
