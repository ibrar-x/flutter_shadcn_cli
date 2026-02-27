class IndexComponent {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<String> tags;
  final String install;
  final String import_;
  final String importPath;
  final Map<String, dynamic> api;
  final Map<String, dynamic> examples;
  final Map<String, dynamic> dependencies;
  final List<String> related;

  const IndexComponent({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.tags,
    required this.install,
    required this.import_,
    required this.importPath,
    required this.api,
    required this.examples,
    required this.dependencies,
    required this.related,
  });

  factory IndexComponent.fromJson(Map<String, dynamic> json) {
    return IndexComponent(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      tags: List<String>.from(json['tags'] as List? ?? []),
      install: json['install'] as String? ?? '',
      import_: json['import'] as String? ?? '',
      importPath: json['importPath'] as String? ?? '',
      api: json['api'] as Map<String, dynamic>? ?? {},
      examples: json['examples'] as Map<String, dynamic>? ?? {},
      dependencies: json['dependencies'] as Map<String, dynamic>? ?? {},
      related: List<String>.from(json['related'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'tags': tags,
      'install': install,
      'import': import_,
      'importPath': importPath,
      'api': api,
      'examples': examples,
      'dependencies': dependencies,
      'related': related,
    };
  }

  bool matches(String query) {
    final lower = query.toLowerCase();
    return id.contains(lower) ||
        name.toLowerCase().contains(lower) ||
        description.toLowerCase().contains(lower) ||
        tags.any((tag) => tag.toLowerCase().contains(lower)) ||
        related.any((rel) => rel.toLowerCase().contains(lower));
  }

  int relevanceScore(String query) {
    final lower = query.toLowerCase();
    var score = 0;

    if (id.toLowerCase() == lower) score += 100;
    if (id.toLowerCase().contains(lower)) score += 50;
    if (name.toLowerCase() == lower) score += 80;
    if (name.toLowerCase().contains(lower)) score += 40;
    if (tags.contains(lower)) score += 60;
    if (description.toLowerCase().contains(lower)) score += 10;

    return score;
  }
}
