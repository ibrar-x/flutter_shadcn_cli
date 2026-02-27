class SkillEntry {
  final String id;
  final String name;
  final String version;
  final String description;
  final String status;
  final String category;
  final String path;
  final String entry;
  final String manifest;
  final bool supportedByCli;

  SkillEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.status,
    required this.category,
    required this.path,
    required this.entry,
    required this.manifest,
    required this.supportedByCli,
  });

  factory SkillEntry.fromJson(Map<String, dynamic> json) {
    final installation = json['installation'] as Map<String, dynamic>? ?? {};
    return SkillEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'stable',
      category: json['category'] as String? ?? '',
      path: json['path'] as String? ?? json['id'],
      entry: json['entry'] as String? ?? '',
      manifest: json['manifest'] as String? ?? '',
      supportedByCli: installation['supportedByCli'] as bool? ?? true,
    );
  }
}
