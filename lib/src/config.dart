import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ShadcnConfig {
  final String? classPrefix;
  final String? themeId;
  final String? registryMode;
  final String? registryPath;
  final String? registryUrl;
  final String? installPath;
  final String? sharedPath;
  final bool? includeReadme;
  final bool? includeMeta;
  final bool? includePreview;
  final Map<String, String>? pathAliases;

  const ShadcnConfig({
    this.classPrefix,
    this.themeId,
    this.registryMode,
    this.registryPath,
    this.registryUrl,
    this.installPath,
    this.sharedPath,
    this.includeReadme,
    this.includeMeta,
    this.includePreview,
    this.pathAliases,
  });

  factory ShadcnConfig.fromJson(Map<String, dynamic> json) {
    return ShadcnConfig(
      classPrefix: json['classPrefix'] as String?,
      themeId: json['themeId'] as String?,
      registryMode: json['registryMode'] as String?,
      registryPath: json['registryPath'] as String?,
      registryUrl: json['registryUrl'] as String?,
      installPath: json['installPath'] as String?,
      sharedPath: json['sharedPath'] as String?,
      includeReadme: json['includeReadme'] as bool?,
      includeMeta: json['includeMeta'] as bool?,
      includePreview: json['includePreview'] as bool?,
      pathAliases: (json['pathAliases'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classPrefix': classPrefix,
      'themeId': themeId,
      'registryMode': registryMode,
      'registryPath': registryPath,
      'registryUrl': registryUrl,
      'installPath': installPath,
      'sharedPath': sharedPath,
      'includeReadme': includeReadme,
      'includeMeta': includeMeta,
      'includePreview': includePreview,
      'pathAliases': pathAliases,
    };
  }

  static File configFile(String targetDir) {
    return File(p.join(targetDir, '.shadcn', 'config.json'));
  }

  static Future<ShadcnConfig> load(String targetDir) async {
    final file = configFile(targetDir);
    if (!await file.exists()) {
      return const ShadcnConfig();
    }
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ShadcnConfig.fromJson(json);
    } catch (_) {
      return const ShadcnConfig();
    }
  }

  static Future<void> save(String targetDir, ShadcnConfig config) async {
    final file = configFile(targetDir);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(config.toJson()));
  }

  ShadcnConfig copyWith({
    String? classPrefix,
    String? themeId,
    String? registryMode,
    String? registryPath,
    String? registryUrl,
    String? installPath,
    String? sharedPath,
    bool? includeReadme,
    bool? includeMeta,
    bool? includePreview,
    Map<String, String>? pathAliases,
  }) {
    return ShadcnConfig(
      classPrefix: classPrefix ?? this.classPrefix,
      themeId: themeId ?? this.themeId,
      registryMode: registryMode ?? this.registryMode,
      registryPath: registryPath ?? this.registryPath,
      registryUrl: registryUrl ?? this.registryUrl,
      installPath: installPath ?? this.installPath,
      sharedPath: sharedPath ?? this.sharedPath,
      includeReadme: includeReadme ?? this.includeReadme,
      includeMeta: includeMeta ?? this.includeMeta,
      includePreview: includePreview ?? this.includePreview,
      pathAliases: pathAliases ?? this.pathAliases,
    );
  }
}
