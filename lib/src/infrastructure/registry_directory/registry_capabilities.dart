class RegistryCapabilities {
  final bool sharedGroups;
  final bool composites;
  final bool theme;

  const RegistryCapabilities({
    this.sharedGroups = false,
    this.composites = false,
    this.theme = false,
  });

  factory RegistryCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const RegistryCapabilities();
    }
    return RegistryCapabilities(
      sharedGroups: json['sharedGroups'] as bool? ?? false,
      composites: json['composites'] as bool? ?? false,
      theme: json['theme'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sharedGroups': sharedGroups,
      'composites': composites,
      'theme': theme,
    };
  }
}
