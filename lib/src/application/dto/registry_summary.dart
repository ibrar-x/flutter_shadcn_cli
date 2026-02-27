class RegistrySummary {
  final String namespace;
  final String displayName;
  final bool isDefault;
  final bool enabled;
  final String source;
  final String? mode;
  final String? baseUrl;
  final String? registryPath;
  final String? installRoot;
  final bool? capabilitySharedGroups;
  final bool? capabilityComposites;
  final bool? capabilityTheme;

  const RegistrySummary({
    required this.namespace,
    required this.displayName,
    required this.isDefault,
    required this.enabled,
    required this.source,
    required this.mode,
    required this.baseUrl,
    required this.registryPath,
    required this.installRoot,
    required this.capabilitySharedGroups,
    required this.capabilityComposites,
    required this.capabilityTheme,
  });

  Map<String, dynamic> toJson() {
    return {
      'namespace': namespace,
      'displayName': displayName,
      'isDefault': isDefault,
      'enabled': enabled,
      'source': source,
      'mode': mode,
      'baseUrl': baseUrl,
      'registryPath': registryPath,
      'installRoot': installRoot,
      'capabilitySharedGroups': capabilitySharedGroups,
      'capabilityComposites': capabilityComposites,
      'capabilityTheme': capabilityTheme,
    };
  }
}
