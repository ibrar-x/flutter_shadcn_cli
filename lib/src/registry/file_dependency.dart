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
