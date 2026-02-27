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
