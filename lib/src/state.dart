import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ShadcnState {
  final String? installPath;
  final String? sharedPath;
  final String? themeId;
  final List<String>? managedDependencies;

  const ShadcnState({
    this.installPath,
    this.sharedPath,
    this.themeId,
    this.managedDependencies,
  });

  factory ShadcnState.fromJson(Map<String, dynamic> json) {
    return ShadcnState(
      installPath: json['installPath'] as String?,
      sharedPath: json['sharedPath'] as String?,
      themeId: json['themeId'] as String?,
      managedDependencies: (json['managedDependencies'] as List?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'installPath': installPath,
      'sharedPath': sharedPath,
      'themeId': themeId,
      'managedDependencies': managedDependencies,
    };
  }

  static File stateFile(String targetDir) {
    return File(p.join(targetDir, '.shadcn', 'state.json'));
  }

  static Future<ShadcnState> load(String targetDir) async {
    final file = stateFile(targetDir);
    if (!await file.exists()) {
      return const ShadcnState();
    }
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ShadcnState.fromJson(json);
    } catch (_) {
      return const ShadcnState();
    }
  }

  static Future<void> save(String targetDir, ShadcnState state) async {
    final file = stateFile(targetDir);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(state.toJson()));
  }
}
