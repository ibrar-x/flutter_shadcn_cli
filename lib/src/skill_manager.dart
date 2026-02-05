import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/skills_loader.dart';

/// AI model folder to display name mapping.
const Map<String, String> aiModelDisplayNames = {
  '.claude': 'Claude (Anthropic)',
  '.cline': 'Cline',
  '.codebuddy': 'CodeBuddy',
  '.codex': 'Codex (OpenAI)',
  '.commandcode': 'CommandCode',
  '.continue': 'Continue',
  '.crush': 'Crush',
  '.cursor': 'Cursor',
  '.factory': 'Factory',
  '.gemini': 'Gemini (Google)',
  '.goose': 'Goose',
  '.gpt4': 'GPT-4 (OpenAI)',
  '.junie': 'Junie',
  '.kilocode': 'KiloCode',
  '.kiro': 'Kiro',
  '.kode': 'Kode',
  '.mcpjam': 'MCPJam',
  '.mux': 'Mux',
  '.neovate': 'Neovate',
  '.opencode': 'OpenCode',
  '.openhands': 'OpenHands',
  '.pi': 'Pi',
  '.pochi': 'Pochi',
  '.qoder': 'Qoder',
  '.qwen': 'Qwen',
  '.roo': 'Roo',
  '.trae': 'Trae',
  '.windsurf': 'Windsurf',
  '.zencoder': 'ZenCoder',
};

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
  final String skillsBaseUrl;
  final CliLogger logger;

  SkillManager({
    required this.projectRoot,
    required this.skillsBasePath,
    String? skillsBaseUrl,
    required this.logger,
  }) : skillsBaseUrl = skillsBaseUrl?.isNotEmpty == true
            ? skillsBaseUrl!
            : 'https://github.com/ibrar-x/shadcn_flutter_kit/tree/main/flutter_shadcn_kit/skill';

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
      logger.detail('Downloading skill from $skillsBaseUrl/$skillId');
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

    final shared = <String>[];
    final models = <String, List<String>>{};

    final sharedDir = Directory(skillsBasePath);
    if (sharedDir.existsSync()) {
      for (final entity in sharedDir.listSync()) {
        if (entity is Directory) {
          shared.add(p.basename(entity.path));
        }
      }
    }

    final modelFolders = discoverModelFolders();
    for (final model in modelFolders) {
      final modelSkillsDir = Directory(p.join(projectRoot, model, 'skills'));
      if (!modelSkillsDir.existsSync()) {
        continue;
      }

      final skillIds = <String>[];
      for (final skillEntity in modelSkillsDir.listSync()) {
        if (skillEntity is Directory || skillEntity is Link) {
          skillIds.add(p.basename(skillEntity.path));
        }
      }

      if (skillIds.isNotEmpty) {
        models[model] = skillIds;
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
  /// Only returns folders that actually exist or offers to create them interactively.
  List<String> discoverModelFolders() {
    try {
      final projectDir = Directory(projectRoot);
      if (!projectDir.existsSync()) {
        return [];
      }

      // Always return the full template list so users can install to any model
      // Existing folders will simply be reused/overwritten
      final template = _findTemplateModels();
      return template;
    } catch (e) {
      logger.error('Error discovering model folders: $e');
      return [];
    }
  }

  /// Returns the hardcoded list of known AI model folders.
  List<String> _getKnownAIModels() {
    return const [
      '.claude',
      '.cline',
      '.codebuddy',
      '.codex',
      '.commandcode',
      '.continue',
      '.crush',
      '.cursor',
      '.factory',
      '.gemini',
      '.goose',
      '.junie',
      '.kilocode',
      '.kiro',
      '.kode',
      '.mcpjam',
      '.mux',
      '.neovate',
      '.opencode',
      '.openhands',
      '.pi',
      '.pochi',
      '.qoder',
      '.qwen',
      '.roo',
      '.trae',
      '.windsurf',
      '.zencoder',
    ];
  }

  List<String> _listHiddenDirs(String rootPath) {
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) {
      return [];
    }

    // Get the list of known AI model folders (from constants, not recursively)
    final knownModels = _getKnownAIModels().toSet();

    final models = <String>[];
    for (final entity in rootDir.listSync()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        // Only include folders that are in the known AI models list
        if (knownModels.contains(name)) {
          models.add(name);
        }
      }
    }

    return models..sort();
  }

  List<String> _findTemplateModels() {
    final templateRoot = _findRemotionVideosRoot();
    if (templateRoot != null) {
      final models = _listHiddenDirs(templateRoot);
      if (models.isNotEmpty) {
        return models;
      }
    }

    // Return the default list of known AI models
    return _getKnownAIModels();
  }

  String? _findRemotionVideosRoot() {
    var current = Directory(projectRoot);
    while (true) {
      final candidate = Directory(p.join(current.path, 'remotion-videos'));
      if (candidate.existsSync()) {
        return candidate.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        return null;
      }
      current = parent;
    }
  }

  /// Lists available skills from skills.json index.
  Future<void> listAvailableSkills() async {
    logger.section('📚 Available Skills');
    
    final loader = SkillsLoader(skillsBasePath: skillsBasePath);
    final index = await loader.load();
    
    if (index == null || index.skills.isEmpty) {
      logger.info('No skills found in registry.');
      logger.detail('Skills index: skills.json');
      return;
    }
    
    print('');
    for (var i = 0; i < index.skills.length; i++) {
      final skill = index.skills[i];
      print('  ${i + 1}. ${skill.name} (${skill.id})');
      print('     ${skill.description}');
      print('     Version: ${skill.version} | Status: ${skill.status}');
      if (i < index.skills.length - 1) print('');
    }
    print('');
    logger.info('${index.skills.length} skills available.');
  }
  
  /// Interactive multi-skill installation flow.
  /// 
  /// Shows available skills from skills.json and allows user to select
  /// which skills to install and to which models.
  Future<void> installSkillsInteractive() async {
    final loader = SkillsLoader(skillsBasePath: skillsBasePath);
    final index = await loader.load();
    
    if (index == null || index.skills.isEmpty) {
      logger.error('No skills found in registry.');
      logger.detail('Create a skills.json file in your skills directory.');
      return;
    }
    
    // Show available skills
    logger.section('📚 Available Skills');
    for (var i = 0; i < index.skills.length; i++) {
      final skill = index.skills[i];
      print('  ${i + 1}. ${skill.name} - ${skill.description}');
    }
    print('  ${index.skills.length + 1}. All skills');
    
    stdout.write('\nSelect skills to install (comma-separated numbers, or ${index.skills.length + 1} for all): ');
    final input = stdin.readLineSync()?.trim() ?? '';
    
    List<SkillEntry> selectedSkills = [];
    if (input == '${index.skills.length + 1}' || input.toLowerCase() == 'all') {
      selectedSkills = index.skills;
    } else {
      final indices = input.split(',').map((i) => int.tryParse(i.trim()));
      for (final idx in indices) {
        if (idx != null && idx > 0 && idx <= index.skills.length) {
          selectedSkills.add(index.skills[idx - 1]);
        }
      }
    }
    
    if (selectedSkills.isEmpty) {
      logger.error('No skills selected.');
      return;
    }
    
    // Show AI models
    final models = discoverModelFolders();
    if (models.isEmpty) {
      logger.warn('⚠️  No existing AI model folders found.');
      logger.detail('Showing available AI model options for selection...');
    }
    
    // If empty, show all available template models instead
    final availableModels = models.isNotEmpty ? models : _getKnownAIModels();
    
    logger.section('🤖 Target AI Models');
    for (var i = 0; i < availableModels.length; i++) {
      final displayName = aiModelDisplayNames[availableModels[i]] ?? availableModels[i];
      print('  ${i + 1}. $displayName');
    }
    print('  ${availableModels.length + 1}. All models');
    
    stdout.write('\nSelect models (comma-separated numbers, or ${availableModels.length + 1} for all): ');
    final modelInput = stdin.readLineSync()?.trim() ?? '';
    
    List<String> selectedModels = [];
    if (modelInput == '${availableModels.length + 1}' || modelInput.toLowerCase() == 'all') {
      selectedModels = availableModels;
    } else {
      final indices = modelInput.split(',').map((i) => int.tryParse(i.trim()));
      for (final idx in indices) {
        if (idx != null && idx > 0 && idx <= availableModels.length) {
          selectedModels.add(availableModels[idx - 1]);
        }
      }
    }
    
    if (selectedModels.isEmpty) {
      logger.error('No models selected.');
      return;
    }
    
    // Check which models already have these skills installed
    final alreadyInstalled = <String, List<String>>{}; // skillId -> [models]
    final notInstalled = <String, List<String>>{}; // skillId -> [models]
    
    for (final skill in selectedSkills) {
      alreadyInstalled[skill.id] = [];
      notInstalled[skill.id] = [];
      
      for (final model in selectedModels) {
        final modelDir = Directory(p.join(projectRoot, model));
        final skillDir = Directory(p.join(modelDir.path, 'skills', skill.id));
        
        if (skillDir.existsSync()) {
          alreadyInstalled[skill.id]!.add(model);
        } else {
          notInstalled[skill.id]!.add(model);
        }
      }
    }
    
    // Check if any skills are already installed in any selected models
    final hasAnyInstalled = alreadyInstalled.values.any((models) => models.isNotEmpty);
    
    if (hasAnyInstalled) {
      logger.section('⚠️  Existing Installations Detected');
      for (final skill in selectedSkills) {
        final installed = alreadyInstalled[skill.id]!;
        if (installed.isNotEmpty) {
          final displayNames = installed.map((m) => aiModelDisplayNames[m] ?? m).join(', ');
          print('  "${skill.name}" is already installed in: $displayNames');
        }
      }
      print('');
      print('What would you like to do?');
      print('  1. Skip already installed models (install to new models only)');
      print('  2. Overwrite all selected models');
      print('  3. Cancel installation');
      stdout.write('\nSelect option (1, 2, or 3): ');
      final overwriteInput = stdin.readLineSync()?.trim() ?? '';
      
      if (overwriteInput == '3') {
        logger.info('Installation cancelled.');
        return;
      } else if (overwriteInput == '1') {
        // Filter to only install to models that don't have the skill
        final modelsToInstall = <String>{};
        for (final skill in selectedSkills) {
          modelsToInstall.addAll(notInstalled[skill.id]!);
        }
        
        if (modelsToInstall.isEmpty) {
          logger.info('All selected models already have these skills installed.');
          return;
        }
        
        selectedModels = modelsToInstall.toList()..sort();
        logger.info('Installing to ${selectedModels.length} new model(s)...');
      }
      // If overwriteInput == '2', continue with all selectedModels
    }
    
    // If multiple models selected, ask about installation mode
    String? primaryModel;
    bool useSymlinks = false;
    
    if (selectedModels.length > 1) {
      logger.section('📦 Installation Mode');
      print('You selected ${selectedModels.length} models.');
      print('');
      print('Choose installation method:');
      print('  1. Copy skill files to each model folder');
      print('  2. Install to one model and symlink to others');
      stdout.write('\nSelect mode (1 or 2): ');
      final modeInput = stdin.readLineSync()?.trim() ?? '';
      
      if (modeInput == '2') {
        useSymlinks = true;
        logger.section('🎯 Primary Installation Target');
        print('Select which model to install the skill files into:');
        for (var i = 0; i < selectedModels.length; i++) {
          final displayName = aiModelDisplayNames[selectedModels[i]] ?? selectedModels[i];
          print('  ${i + 1}. $displayName');
        }
        stdout.write('\nSelect primary model: ');
        final primaryInput = stdin.readLineSync()?.trim() ?? '';
        final primaryIdx = int.tryParse(primaryInput);
        
        if (primaryIdx != null && primaryIdx > 0 && primaryIdx <= selectedModels.length) {
          primaryModel = selectedModels[primaryIdx - 1];
        } else {
          logger.error('Invalid selection.');
          return;
        }
      }
    }
    
    // Install each skill
    for (final skill in selectedSkills) {
      if (useSymlinks && primaryModel != null) {
        // Install to primary model first
        await installSkill(skillId: skill.id, model: primaryModel);
        
        // Create symlinks for other models
        for (final model in selectedModels) {
          if (model != primaryModel) {
            await symlinkSkill(
              skillId: skill.id,
              targetModel: primaryModel,
              model: model,
            );
          }
        }
      } else {
        // Copy to each model
        for (final model in selectedModels) {
          await installSkill(skillId: skill.id, model: model);
        }
      }
    }
    
    logger.success('✓ Installed ${selectedSkills.length} skill(s) to ${selectedModels.length} model(s)');
  }

  /// Interactive installation flow.
  /// 
  /// Shows numbered menu of available AI models and guides user through
  /// selection and installation mode choice.
  Future<void> installSkillInteractive({required String skillId}) async {
    final models = discoverModelFolders();
    
    if (models.isEmpty) {
      logger.error('No AI model folders could be discovered or created.');
      return;
    }

    logger.section('🎯 Installing Skill: $skillId');
    logger.detail('Available AI models:');
    for (var i = 0; i < models.length; i++) {
      final displayName = aiModelDisplayNames[models[i]] ?? models[i];
      print('  ${i + 1}. $displayName');
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

  /// Downloads or copies skill files from source.
  /// 
  /// First tries local registry, then falls back to GitHub/remote.
  Future<void> _downloadSkillFiles(String skillId, String targetPath) async {
    // Try local registry first
    final localSkillPath = await _findLocalSkillPath(skillId);
    
    if (localSkillPath != null) {
      logger.detail('Copying skill from local registry: $localSkillPath');
      await _copyLocalSkillFiles(localSkillPath, targetPath);
      return;
    }

    // Fallback: Try to download from GitHub (placeholder for now)
    logger.detail('Local skill not found. Creating placeholder...');
    await _createPlaceholderManifest(skillId, targetPath);
  }

  /// Finds local skill path by checking common locations.
  Future<String?> _findLocalSkillPath(String skillId) async {
    // Check 1: shadcn_flutter_kit/flutter_shadcn_kit/skills/{skillId}
    var current = Directory(projectRoot);
    while (true) {
      final candidate = Directory(
        p.join(current.path, 'shadcn_flutter_kit', 'flutter_shadcn_kit', 'skills', skillId),
      );
      if (await candidate.exists()) {
        return candidate.path;
      }

      // Check 2: Look for skills/ in parent directories
      final skillsCandidate = Directory(p.join(current.path, 'skills', skillId));
      if (await skillsCandidate.exists()) {
        return skillsCandidate.path;
      }

      final parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }

    // Check 3: Direct path in project root
    final rootSkill = Directory(p.join(projectRoot, 'skills', skillId));
    if (await rootSkill.exists()) {
      return rootSkill.path;
    }

    return null;
  }

  /// Copies skill files from local registry to target path.
  /// 
  /// Requires either skill.json or skill.yaml manifest in the source path.
  /// The manifest's 'files' key determines which files to copy.
  Future<void> _copyLocalSkillFiles(String sourcePath, String targetPath) async {
    final files = <File>[];
    
    // Check for skill.json first, then skill.yaml
    File? manifestFile;
    final skillJsonFile = File(p.join(sourcePath, 'skill.json'));
    final skillYamlFile = File(p.join(sourcePath, 'skill.yaml'));
    
    if (await skillJsonFile.exists()) {
      manifestFile = skillJsonFile;
    } else if (await skillYamlFile.exists()) {
      manifestFile = skillYamlFile;
    }
    
    if (manifestFile == null) {
      logger.error('No skill.json or skill.yaml found in $sourcePath');
      throw Exception('Skill manifest (skill.json or skill.yaml) is required');
    }
    
    // Read manifest to know which files to copy
    try {
      final content = await manifestFile.readAsString();
      Map<String, dynamic>? json;
      
      // Parse based on file extension
      if (p.extension(manifestFile.path) == '.json') {
        json = jsonDecode(content) as Map<String, dynamic>;
      } else {
        // For YAML support, we'd use yaml package here
        // For now, log and fall back to markdown files
        logger.detail('YAML manifest found but YAML parsing not yet implemented');
      }
      
      if (json != null) {
        final filesConfig = json['files'] as Map<String, dynamic>?;
        
        if (filesConfig != null) {
          // Add main file
          if (filesConfig['main'] != null) {
            files.add(File(p.join(sourcePath, filesConfig['main'] as String)));
          }
          
          // Add installation file
          if (filesConfig['installation'] != null) {
            files.add(File(p.join(sourcePath, filesConfig['installation'] as String)));
          }
          
          // Add readme if exists
          if (filesConfig['readme'] != null) {
            final readmeFile = File(p.join(sourcePath, filesConfig['readme'] as String));
            if (await readmeFile.exists()) {
              files.add(readmeFile);
            }
          }
          
          // Add reference files (excluding schemas - that's for CLI management)
          if (filesConfig['references'] is Map) {
            final references = filesConfig['references'] as Map<String, dynamic>;
            for (final entry in references.entries) {
              if (entry.key != 'schemas' && entry.value is String) {
                files.add(File(p.join(sourcePath, entry.value as String)));
              }
            }
          }
        }
        
        // NOTE: skill.json and skill.yaml are CLI management files
        // They are NOT copied to model folders - only used by CLI to determine what to copy
        logger.detail('Using manifest: ${p.basename(manifestFile.path)}');
      } else {
        logger.detail('No files configuration found in manifest');
      }
    } catch (e) {
      logger.error('Error parsing manifest: $e');
      throw Exception('Failed to read skill manifest: $e');
    }
    
    // Validate that we have files to copy
    if (files.isEmpty) {
      logger.error('No files configured in manifest to copy');
      throw Exception('Manifest must specify files to copy in the "files" key');
    }
    
    // Copy each file maintaining directory structure
    for (final file in files) {
      if (!await file.exists()) {
        logger.detail('Skipping missing file: ${file.path}');
        continue;
      }
      
      final relativePath = p.relative(file.path, from: sourcePath);
      final destFile = File(p.join(targetPath, relativePath));
      
      // Create parent directories
      await destFile.parent.create(recursive: true);
      
      // Copy file
      await file.copy(destFile.path);
      logger.detail('✓ Copied: $relativePath');
    }
    
    logger.success('✓ Copied ${files.length} skill files');
  }

  /// Creates a placeholder manifest when skill source is not found.
  Future<void> _createPlaceholderManifest(String skillId, String targetPath) async {
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
  "files": [],
  "note": "This is a placeholder. Skill files were not found in local registry."
}
''');

    logger.detail('Placeholder manifest created at: ${manifestFile.path}');
  }
}
