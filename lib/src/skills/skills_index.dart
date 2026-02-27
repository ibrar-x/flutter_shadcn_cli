import 'package:flutter_shadcn_cli/src/skills/skill_entry.dart';

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
