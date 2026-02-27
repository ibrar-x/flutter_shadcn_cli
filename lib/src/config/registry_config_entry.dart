class RegistryConfigEntry {
  final String? registryMode;
  final String? registryPath;
  final String? registryUrl;
  final String? baseUrl;
  final String? componentsPath;
  final String? componentsSchemaPath;
  final String? indexPath;
  final String? installPath;
  final String? sharedPath;
  final bool? includeReadme;
  final bool? includeMeta;
  final bool? includePreview;
  final List<String>? includeFiles;
  final List<String>? excludeFiles;
  final bool enabled;

  const RegistryConfigEntry({
    this.registryMode,
    this.registryPath,
    this.registryUrl,
    this.baseUrl,
    this.componentsPath,
    this.componentsSchemaPath,
    this.indexPath,
    this.installPath,
    this.sharedPath,
    this.includeReadme,
    this.includeMeta,
    this.includePreview,
    this.includeFiles,
    this.excludeFiles,
    this.enabled = true,
  });

  factory RegistryConfigEntry.fromJson(Map<String, dynamic> json) {
    return RegistryConfigEntry(
      registryMode: json['registryMode'] as String?,
      registryPath: json['registryPath'] as String?,
      registryUrl: json['registryUrl'] as String?,
      baseUrl: json['baseUrl'] as String?,
      componentsPath: json['componentsPath'] as String?,
      componentsSchemaPath: json['componentsSchemaPath'] as String?,
      indexPath: json['indexPath'] as String?,
      installPath: json['installPath'] as String?,
      sharedPath: json['sharedPath'] as String?,
      includeReadme: json['includeReadme'] as bool?,
      includeMeta: json['includeMeta'] as bool?,
      includePreview: json['includePreview'] as bool?,
      includeFiles: _stringListOrNull(json['includeFiles']),
      excludeFiles: _stringListOrNull(json['excludeFiles']),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registryMode': registryMode,
      'registryPath': registryPath,
      'registryUrl': registryUrl,
      'baseUrl': baseUrl,
      'componentsPath': componentsPath,
      'componentsSchemaPath': componentsSchemaPath,
      'indexPath': indexPath,
      'installPath': installPath,
      'sharedPath': sharedPath,
      'includeReadme': includeReadme,
      'includeMeta': includeMeta,
      'includePreview': includePreview,
      'includeFiles': includeFiles,
      'excludeFiles': excludeFiles,
      'enabled': enabled,
    };
  }

  RegistryConfigEntry copyWith({
    String? registryMode,
    String? registryPath,
    String? registryUrl,
    String? baseUrl,
    String? componentsPath,
    String? componentsSchemaPath,
    String? indexPath,
    String? installPath,
    String? sharedPath,
    bool? includeReadme,
    bool? includeMeta,
    bool? includePreview,
    List<String>? includeFiles,
    List<String>? excludeFiles,
    bool? enabled,
  }) {
    return RegistryConfigEntry(
      registryMode: registryMode ?? this.registryMode,
      registryPath: registryPath ?? this.registryPath,
      registryUrl: registryUrl ?? this.registryUrl,
      baseUrl: baseUrl ?? this.baseUrl,
      componentsPath: componentsPath ?? this.componentsPath,
      componentsSchemaPath: componentsSchemaPath ?? this.componentsSchemaPath,
      indexPath: indexPath ?? this.indexPath,
      installPath: installPath ?? this.installPath,
      sharedPath: sharedPath ?? this.sharedPath,
      includeReadme: includeReadme ?? this.includeReadme,
      includeMeta: includeMeta ?? this.includeMeta,
      includePreview: includePreview ?? this.includePreview,
      includeFiles: includeFiles ?? this.includeFiles,
      excludeFiles: excludeFiles ?? this.excludeFiles,
      enabled: enabled ?? this.enabled,
    );
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
