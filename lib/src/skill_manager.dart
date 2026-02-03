import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_shadcn_cli/src/logger.dart';

/// Manages AI skill installation and management.
/// 
/// Skills are downloaded from GitHub and installed into AI model directories.
/// Supports:
/// - Interactive model selection from .{modelName}/ folders
/// - Install to all models (creates separate copies)
/// - Install to selected model
/// - Create symlinks for all models (if skill installed to one)
class SkillManager {
  final String projectRoot;
  final String skillsBasePath;
  final CliLogger logger;

  SkillManager({
    required this.projectRoot,
    required this.skillsBasePath,
    required this.logger,
  });

  /// GitHub base URL for skills repository.
  static const _skillsRepoUrl =
      'https://github.com/ibrar-x/shadcn_flutter_kit/tree/main/flutter_shadcn_kit/skill';

  /// Installs a skill from GitHub.
  /// 
  /// Can install for a specific AI model or as a shared skill (symlink).
  /// 
  /// [skillId]: Name of the skill folder to install
  /// [model]: Optional AI model name (e.g., 'gpt-4', 'claude'). If provided, installs
  ///          to skillsPath/models/{model}/. If null, installs to shared skillsPath/
  Future<void> installSkill({
    required String skillId,
    String? model,
  }) async {
    logger.section('🎯 Installing Skill: $skillId');

    if (skillId.isEmpty) {
      logger.error('Please provide a skill id.');
      throw Exception('Skill id cannot be empty');
    }

    // Determine installation path
    final installPath = _getInstallPath(skillId, model);
    final skillDir = Directory(installPath);

    try {
      // Create target directory
      if (!skillDir.existsSync()) {
        skillDir.createSync(recursive: true);
        logger.detail('Created skill directory: $installPath');
      }

      // Download skill files
      logger.detail('Downloading skill from $_skillsRepoUrl/$skillId');
      await _downloadSkillFiles(skillId, installPath);

      if (model != null) {
        logger.success('✓ Skill "$skillId" installed for model: $model');
      } else {
        logger.success('✓ Skill "$skillId" installed (shared)');
      }
    } catch (e) {
      logger.error('Failed to install skill: $e');
      rethrow;
    }
  }

  /// Symlinks a shared skill to a model-specific directory.
  /// 
  /// Useful for sharing a skill across multiple models without duplicating files.
  /// Creates symlinks from a source model to target models.
  /// 
  /// The source model must have the skill installed. Target models will have
  /// symlinks pointing to the source skill folder.
  /// 
  /// [skillId]: The skill to symlink
  /// [targetModel]: The model where the skill is installed (source)
  /// [model]: The model to create symlink in (destination)
  Future<void> symlinkSkill({
    required String skillId,
    required String targetModel,
    required String model,
  }) async {
    logger.section('🔗 Symlinking Skill: $skillId');

    try {
      final sourcePath = p.join(projectRoot, targetModel, 'skills', skillId);
      final targetPath = p.join(projectRoot, model, 'skills', skillId);

      final sourceDir = Directory(sourcePath);
      if (!sourceDir.existsSync()) {
        logger.error(
          'Skill "$skillId" not found in $targetModel. Install it first.',
        );
        throw Exception('Skill not found in source model: $skillId');
      }

      // Create parent directory if needed
      final parentDir = Directory(p.dirname(targetPath));
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      // Create symlink
      final link = Link(targetPath);
      if (await link.exists()) {
        logger.info('Symlink already exists: $targetPath');
        return;
      }

      await link.create(sourcePath, recursive: true);
      logger.success('✓ Symlinked "$skillId" from $targetModel -> $model');
    } catch (e) {
      logger.error('Failed to symlink skill: $e');
      rethrow;
    }
  }

  /// Lists installed skills.
  /// 
  /// Shows shared skills and per-model installations.
  Future<void> listSkills() async {
    logger.section('📚 Installed Skills');

    final baseDir = Directory(skillsBasePath);
    if (!baseDir.existsSync()) {
      logger.info('No skills installed yet.');
      return;
    }

    // List shared skills
    final shared = <String>[];
    final models = <String, List<String>>{};

    for (final entity in baseDir.listSync()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);

        if (name == 'models') {
          // List model-specific skills
          for (final modelDir in entity.listSync()) {
            if (modelDir is Directory) {
              final modelName = p.basename(modelDir.path);
              final skillIds = <String>[];
              for (final skillEntity in modelDir.listSync()) {
                if (skillEntity is Directory || skillEntity is Link) {
                  skillIds.add(p.basename(skillEntity.path));
                }
              }
              if (skillIds.isNotEmpty) {
                models[modelName] = skillIds;
              }
            }
          }
        } else {
          // Shared skill
          shared.add(name);
        }
      }
    }

    if (shared.isNotEmpty) {
      print('\n  Shared Skills:');
      for (final skill in shared) {
        print('    • $skill');
      }
    }

    if (models.isNotEmpty) {
      print('\n  Model-Specific Skills:');
      for (final model in models.keys) {
        print('    $model:');
        for (final skill in models[model]!) {
          print('      • $skill');
        }
      }
    }

    if (shared.isEmpty && models.isEmpty) {
      logger.info('No skills installed.');
    }
  }

  /// Uninstalls a skill or model-specific skill.
  Future<void> uninstallSkill({
    required String skillId,
    String? model,
  }) async {
    final uninstallPath = _getInstallPath(skillId, model);
    final skillDir = Directory(uninstallPath);

    if (!skillDir.existsSync()) {
      logger.error('Skill not found: $uninstallPath');
      throw Exception('Skill not installed: $skillId');
    }

    try {
      await skillDir.delete(recursive: true);
      if (model != null) {
        logger.success('✓ Uninstalled "$skillId" for model: $model');
      } else {
        logger.success('✓ Uninstalled shared skill: $skillId');
      }
    } catch (e) {
      logger.error('Failed to uninstall skill: $e');
      rethrow;
    }
  }

  /// Gets the installation path for a skill.
  /// 
  /// Returns `{projectRoot}/{model}/skills/{skillId}` for model-specific installation.
  String _getInstallPath(String skillId, String? model) {
    if (model != null) {
      return p.join(projectRoot, model, 'skills', skillId);
    }
    // Fallback for shared skills (not typically used with AI models)
    return p.join(skillsBasePath, skillId);
  }

  /// Discovers all AI model folders in the project root.
  /// 
  /// Returns a list of folder names starting with '.' (e.g., .claude, .gpt4, .cursor).
  List<String> discoverModelFolders() {
    try {
      final projectDir = Directory(projectRoot);
      if (!projectDir.existsSync()) {
        return [];
      }

      final entities = projectDir.listSync();
      final models = <String>[];

      for (final entity in entities) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (name.startsWith('.') && name.length > 1) {
            models.add(name);
          }
        }
      }

      return models..sort();
    } catch (e) {
      logger.error('Error discovering model folders: $e');
      return [];
    }
  }

  /// Interactive installation flow.
  /// 
  /// Shows numbered menu of available AI models and guides user through
  /// selection and installation mode choice.
  Future<void> installSkillInteractive({required String skillId}) async {
    final models = discoverModelFolders();
    
    if (models.isEmpty) {
      logger.error(
        'No AI model folders found. Create folders like .claude, .gpt4, .cursor in project root.',
      );
      return;
    }

    logger.section('🎯 Installing Skill: $skillId');
    logger.detail('Available AI models:');
    for (var i = 0; i < models.length; i++) {
      print('  ${i + 1}. ${models[i]}');
    }
    print('  ${models.length + 1}. All models');

    stdout.write('\nSelect models (comma-separated numbers, or ${models.length + 1} for all): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    List<String> selectedModels = [];
    if (input == '${models.length + 1}' || input.toLowerCase() == 'all') {
      selectedModels = models;
    } else {
      final indices = input.split(',').map((i) => int.tryParse(i.trim()));
      for (final idx in indices) {
        if (idx != null && idx > 0 && idx <= models.length) {
          selectedModels.add(models[idx - 1]);
        }
      }
    }

    if (selectedModels.isEmpty) {
      logger.error('No models selected.');
      return;
    }

    if (selectedModels.length == 1) {
      // Install to single model
      await installSkill(skillId: skillId, model: selectedModels[0]);
    } else {
      // Multiple models - ask about installation mode
      logger.section('Installation Mode');
      print('1. Copy skill to each model (separate copies)');
      print('2. Install to first model + symlink to others');
      stdout.write('\nSelect mode (1 or 2): ');
      final mode = stdin.readLineSync()?.trim() ?? '1';

      if (mode == '2') {
        // Install to first model, symlink to others
        final sourceModel = selectedModels[0];
        await installSkill(skillId: skillId, model: sourceModel);
        
        for (var i = 1; i < selectedModels.length; i++) {
          await symlinkSkill(
            skillId: skillId,
            targetModel: sourceModel,
            model: selectedModels[i],
          );
        }
      } else {
        // Copy to each model
        for (final model in selectedModels) {
          await installSkill(skillId: skillId, model: model);
        }
      }
    }
  }

  /// Downloads skill files from GitHub.
  /// 
  /// This is a placeholder - in production, you'd use GitHub API or
  /// clone the repository.
  Future<void> _downloadSkillFiles(String skillId, String targetPath) async {
    // TODO: Implement actual file download from GitHub
    // For now, create a placeholder manifest
    final manifestFile = File(p.join(targetPath, 'manifest.json'));
    await manifestFile.writeAsString('''{
  "skill": {
    "id": "$skillId",
    "version": "1.0.0",
    "name": "Skill: $skillId",
    "description": "AI skill for $skillId",
    "models": ["gpt-4", "claude-3"],
    "createdAt": "${DateTime.now().toIso8601String()}"
  },
  "files": []
}
''');

    logger.detail('Placeholder skill manifest created at: ${manifestFile.path}');
  }
}
