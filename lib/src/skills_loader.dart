import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// Manages loading of skills.json index for skill discovery.
class SkillsLoader {
  final String skillsBasePath;

  SkillsLoader({required this.skillsBasePath});

  /// Loads skills.json from the local registry.
  ///
  /// Searches for skills.json in:
  /// 1. {skillsBasePath}/skills.json
  /// 2. {skillsBasePath}/../skills.json
  /// 3. {projectRoot}/shadcn_flutter_kit/flutter_shadcn_kit/skills/skills.json
  Future<SkillsIndex?> load() async {
    final candidates = _findSkillsJsonPaths();

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          return SkillsIndex.fromJson(json);
        } catch (e) {
          // Try next candidate
          continue;
        }
      }
    }

    return null;
  }

  List<String> _findSkillsJsonPaths() {
    final candidates = <String>[
      p.join(skillsBasePath, 'skills.json'),
      p.join(skillsBasePath, '..', 'skills.json'),
    ];

    // Try to find shadcn_flutter_kit
    var current = Directory(skillsBasePath);
    for (var i = 0; i < 5; i++) {
      final kitCandidate = p.join(
        current.path,
        'shadcn_flutter_kit',
        'flutter_shadcn_kit',
        'skills',
        'skills.json',
      );
      candidates.add(kitCandidate);

      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }

    return candidates;
  }
}

/// Represents the skills.json index.
class SkillsIndex {
  final int schemaVersion;
  final String generatedAt;
  final String scope;
  final String description;
  final List<SkillEntry> skills;

  SkillsIndex({
    required this.schemaVersion,
    required this.generatedAt,
    required this.scope,
    required this.description,
    required this.skills,
  });

  factory SkillsIndex.fromJson(Map<String, dynamic> json) {
    return SkillsIndex(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      generatedAt: json['generatedAt'] as String? ?? '',
      scope: json['scope'] as String? ?? '',
      description: json['description'] as String? ?? '',
      skills: (json['skills'] as List?)
              ?.map((s) => SkillEntry.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Represents a single skill entry in skills.json.
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
