class ThemeIndexEntry {
  final String id;
  final String name;
  final String file;
  final Map<String, dynamic>? preview;

  const ThemeIndexEntry({
    required this.id,
    required this.name,
    required this.file,
    this.preview,
  });

  factory ThemeIndexEntry.fromJson(Map<String, dynamic> json) {
    return ThemeIndexEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      file: json['file']?.toString() ?? '',
      preview: (json['preview'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  bool get isValid => id.trim().isNotEmpty && file.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'file': file,
      if (preview != null) 'preview': preview,
    };
  }
}
