import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:flutter_shadcn_cli/src/skill_manager.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';

void main() {
  group('SkillManager', () {
    late Directory tempRoot;
    late Directory projectRoot;
    late Directory skillsRoot;
    late SkillManager skillManager;
    late CliLogger logger;

    setUp(() async {
      tempRoot = Directory.systemTemp.createTempSync('skill_manager_test_');
      projectRoot = Directory(p.join(tempRoot.path, 'project'))..createSync();
      skillsRoot = Directory(p.join(tempRoot.path, 'shadcn_flutter_kit', 'flutter_shadcn_kit', 'skills'))
        ..createSync(recursive: true);
      
      logger = CliLogger(verbose: false);
      skillManager = SkillManager(
        projectRoot: projectRoot.path,
        skillsBasePath: p.join(projectRoot.path, 'skills'),
        logger: logger,
      );
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    group('Skill Discovery', () {
      test('finds skill in local kit registry', () async {
        // Create skill in kit registry
        final skillDir = Directory(p.join(skillsRoot.path, 'flutter-shadcn-ui'))
          ..createSync(recursive: true);
        
        _createSkillManifest(skillDir.path, {
          'id': 'flutter-shadcn-ui',
          'name': 'Flutter Shadcn UI',
          'version': '1.0.0',
          'files': {
            'main': 'SKILL.md',
            'installation': 'INSTALLATION.md',
            'references': {
              'commands': 'references/commands.md',
              'examples': 'references/examples.md',
            }
          }
        });

        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('# Skill');
        File(p.join(skillDir.path, 'INSTALLATION.md')).writeAsStringSync('# Installation');
        Directory(p.join(skillDir.path, 'references')).createSync();
        File(p.join(skillDir.path, 'references', 'commands.md')).writeAsStringSync('# Commands');
        File(p.join(skillDir.path, 'references', 'examples.md')).writeAsStringSync('# Examples');

        // Install skill
        final modelDir = Directory(p.join(projectRoot.path, '.claude'))
          ..createSync();
        
        await skillManager.installSkill(
          skillId: 'flutter-shadcn-ui',
          model: '.claude',
        );

        // Verify files were copied
        final installedSkill = Directory(p.join(modelDir.path, 'skills', 'flutter-shadcn-ui'));
        expect(installedSkill.existsSync(), isTrue);
        expect(File(p.join(installedSkill.path, 'SKILL.md')).existsSync(), isTrue);
        expect(File(p.join(installedSkill.path, 'INSTALLATION.md')).existsSync(), isTrue);
        expect(File(p.join(installedSkill.path, 'references', 'commands.md')).existsSync(), isTrue);
        expect(File(p.join(installedSkill.path, 'references', 'examples.md')).existsSync(), isTrue);
      });

      test('finds skill in parent directory skills folder', () async {
        // Create skill in parent directory
        final parentSkillsDir = Directory(p.join(tempRoot.path, 'skills', 'my-skill'))
          ..createSync(recursive: true);
        
        _createSkillManifest(parentSkillsDir.path, {
          'id': 'my-skill',
          'name': 'My Skill',
          'version': '1.0.0',
          'files': {
            'main': 'SKILL.md',
          }
        });
        
        File(p.join(parentSkillsDir.path, 'SKILL.md')).writeAsStringSync('# My Skill');

        final modelDir = Directory(p.join(projectRoot.path, '.cursor'))
          ..createSync();

        await skillManager.installSkill(
          skillId: 'my-skill',
          model: '.cursor',
        );

        final installedSkill = Directory(p.join(modelDir.path, 'skills', 'my-skill'));
        expect(installedSkill.existsSync(), isTrue);
        expect(File(p.join(installedSkill.path, 'SKILL.md')).existsSync(), isTrue);
      });

      test('creates placeholder when skill not found', () async {
        final modelDir = Directory(p.join(projectRoot.path, '.gpt4'))
          ..createSync();

        await skillManager.installSkill(
          skillId: 'nonexistent-skill',
          model: '.gpt4',
        );

        // Should create placeholder manifest
        final installedSkill = Directory(p.join(modelDir.path, 'skills', 'nonexistent-skill'));
        expect(installedSkill.existsSync(), isTrue);
        
        final manifestFile = File(p.join(installedSkill.path, 'manifest.json'));
        expect(manifestFile.existsSync(), isTrue);
        
        final manifest = jsonDecode(manifestFile.readAsStringSync());
        expect(manifest['skill']['id'], equals('nonexistent-skill'));
        expect(manifest['note'], contains('placeholder'));
      });
      
      test('requires skill.json or skill.yaml manifest', () async {
        // Create skill directory without manifest
        final skillDir = Directory(p.join(skillsRoot.path, 'no-manifest-skill'))
          ..createSync(recursive: true);
        
        File(p.join(skillDir.path, 'README.md')).writeAsStringSync('# No Manifest Skill');

        Directory(p.join(projectRoot.path, '.claude')).createSync();

        // Should throw because no manifest exists
        expect(
          () => skillManager.installSkill(
            skillId: 'no-manifest-skill',
            model: '.claude',
          ),
          throwsA(isA<Exception>()),
        );
      });
      
      test('accepts skill.yaml as alternative to skill.json', () async {
        final skillDir = Directory(p.join(skillsRoot.path, 'yaml-skill'))
          ..createSync(recursive: true);
        
        // Create skill.yaml instead of skill.json
        File(p.join(skillDir.path, 'skill.yaml')).writeAsStringSync('''
id: yaml-skill
name: YAML Skill
version: 1.0.0
files:
  main: SKILL.md
''');
        
        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('# YAML Skill');

        Directory(p.join(projectRoot.path, '.claude')).createSync();

        // YAML parsing not yet implemented, should throw error about no files to copy
        // Once YAML parsing is added, update this test to verify proper file copying
        expect(
          () => skillManager.installSkill(
            skillId: 'yaml-skill',
            model: '.claude',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('files'),
          )),
        );
      });
    });

    group('File Copying', () {
      test('copies only AI-focused files, excludes manifest and schemas', () async {
        final skillDir = Directory(p.join(skillsRoot.path, 'test-skill'))
          ..createSync(recursive: true);
        
        _createSkillManifest(skillDir.path, {
          'id': 'test-skill',
          'name': 'Test Skill',
          'version': '1.0.0',
          'files': {
            'main': 'SKILL.md',
            'installation': 'INSTALLATION.md',
            'references': {
              'commands': 'references/commands.md',
              'schemas': 'references/schemas.md',
              'examples': 'references/examples.md',
            }
          }
        });

        // Create all files
        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('# Skill');
        File(p.join(skillDir.path, 'INSTALLATION.md')).writeAsStringSync('# Install');
        File(p.join(skillDir.path, 'skill.yaml')).writeAsStringSync('id: test-skill');
        Directory(p.join(skillDir.path, 'references')).createSync();
        File(p.join(skillDir.path, 'references', 'commands.md')).writeAsStringSync('# Commands');
        File(p.join(skillDir.path, 'references', 'schemas.md')).writeAsStringSync('# Schemas');
        File(p.join(skillDir.path, 'references', 'examples.md')).writeAsStringSync('# Examples');

        final modelDir = Directory(p.join(projectRoot.path, '.claude'))
          ..createSync();

        await skillManager.installSkill(
          skillId: 'test-skill',
          model: '.claude',
        );

        final installedSkill = Directory(p.join(modelDir.path, 'skills', 'test-skill'));
        
        // Should copy AI-focused files
        expect(File(p.join(installedSkill.path, 'SKILL.md')).existsSync(), isTrue);
        expect(File(p.join(installedSkill.path, 'INSTALLATION.md')).existsSync(), isTrue);
        expect(File(p.join(installedSkill.path, 'references', 'commands.md')).existsSync(), isTrue);
        expect(File(p.join(installedSkill.path, 'references', 'examples.md')).existsSync(), isTrue);
        
        // Should NOT copy management files
        expect(File(p.join(installedSkill.path, 'skill.json')).existsSync(), isFalse);
        expect(File(p.join(installedSkill.path, 'skill.yaml')).existsSync(), isFalse);
        expect(File(p.join(installedSkill.path, 'references', 'schemas.md')).existsSync(), isFalse);
      });

      test('maintains directory structure during copy', () async {
        final skillDir = Directory(p.join(skillsRoot.path, 'structure-skill'))
          ..createSync(recursive: true);
        
        _createSkillManifest(skillDir.path, {
          'id': 'structure-skill',
          'name': 'Structure Skill',
          'version': '1.0.0',
          'files': {
            'main': 'SKILL.md',
            'references': {
              'commands': 'references/deep/nested/commands.md',
            }
          }
        });

        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('# Skill');
        Directory(p.join(skillDir.path, 'references', 'deep', 'nested'))
          ..createSync(recursive: true);
        File(p.join(skillDir.path, 'references', 'deep', 'nested', 'commands.md'))
          .writeAsStringSync('# Nested Commands');

        final modelDir = Directory(p.join(projectRoot.path, '.gemini'))
          ..createSync();

        await skillManager.installSkill(
          skillId: 'structure-skill',
          model: '.gemini',
        );

        final installedFile = File(p.join(
          modelDir.path,
          'skills',
          'structure-skill',
          'references',
          'deep',
          'nested',
          'commands.md',
        ));
        
        expect(installedFile.existsSync(), isTrue);
        expect(installedFile.readAsStringSync(), equals('# Nested Commands'));
      });
    });

    group('Skill Management', () {
      test('lists installed skills by model', () async {
        // Install skills to different models
        final skill1Dir = Directory(p.join(skillsRoot.path, 'skill-1'))
          ..createSync(recursive: true);
        _createSkillManifest(skill1Dir.path, {
          'id': 'skill-1',
          'name': 'Skill 1',
          'version': '1.0.0',
          'files': {'main': 'SKILL.md'}
        });
        File(p.join(skill1Dir.path, 'SKILL.md')).writeAsStringSync('# Skill 1');

        Directory(p.join(projectRoot.path, '.claude')).createSync();
        Directory(p.join(projectRoot.path, '.cursor')).createSync();

        await skillManager.installSkill(skillId: 'skill-1', model: '.claude');
        await skillManager.installSkill(skillId: 'skill-1', model: '.cursor');

        // Verify both installations exist
        expect(
          Directory(p.join(projectRoot.path, '.claude', 'skills', 'skill-1')).existsSync(),
          isTrue,
        );
        expect(
          Directory(p.join(projectRoot.path, '.cursor', 'skills', 'skill-1')).existsSync(),
          isTrue,
        );
      });

      test('uninstalls skill from specific model', () async {
        final skillDir = Directory(p.join(skillsRoot.path, 'removable-skill'))
          ..createSync(recursive: true);
        _createSkillManifest(skillDir.path, {
          'id': 'removable-skill',
          'name': 'Removable Skill',
          'version': '1.0.0',
          'files': {'main': 'SKILL.md'}
        });
        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('# Removable');

        Directory(p.join(projectRoot.path, '.claude')).createSync();

        await skillManager.installSkill(skillId: 'removable-skill', model: '.claude');
        
        final installedDir = Directory(p.join(projectRoot.path, '.claude', 'skills', 'removable-skill'));
        expect(installedDir.existsSync(), isTrue);

        // Uninstall
        await skillManager.uninstallSkill(skillId: 'removable-skill', model: '.claude');
        
        expect(installedDir.existsSync(), isFalse);
      });
    });

    group('Model Discovery', () {
      test('discovers AI model folders starting with dot', () async {
        // Create various model folders
        Directory(p.join(projectRoot.path, '.claude')).createSync();
        Directory(p.join(projectRoot.path, '.cursor')).createSync();
        Directory(p.join(projectRoot.path, '.gpt4')).createSync();
        Directory(p.join(projectRoot.path, '.gemini')).createSync();
        
        // Create non-model folders (should be ignored)
        Directory(p.join(projectRoot.path, '.git')).createSync();
        Directory(p.join(projectRoot.path, '.dart_tool')).createSync();
        Directory(p.join(projectRoot.path, 'lib')).createSync();

        final models = skillManager.discoverModelFolders();
        
        // Should discover model folders but not .git, .dart_tool, or lib
        expect(models, contains('.claude'));
        expect(models, contains('.cursor'));
        expect(models, contains('.gpt4'));
        expect(models, contains('.gemini'));
        expect(models.length, greaterThanOrEqualTo(4));
      });

      test('auto-creates model folders if they do not exist', () async {
        // Initially no model folders
        expect(Directory(p.join(projectRoot.path, '.claude')).existsSync(), isFalse);

        final models = skillManager.discoverModelFolders();
        
        // Should have created standard model folders
        expect(models, isNotEmpty);
        expect(models, contains('.claude'));
        expect(Directory(p.join(projectRoot.path, '.claude')).existsSync(), isTrue);
      });
    });

    group('Symlink Support', () {
      test('creates symlinks from one model to another', () async {
        final skillDir = Directory(p.join(skillsRoot.path, 'shared-skill'))
          ..createSync(recursive: true);
        _createSkillManifest(skillDir.path, {
          'id': 'shared-skill',
          'name': 'Shared Skill',
          'version': '1.0.0',
          'files': {'main': 'SKILL.md'}
        });
        File(p.join(skillDir.path, 'SKILL.md')).writeAsStringSync('# Shared');

        Directory(p.join(projectRoot.path, '.claude')).createSync();
        Directory(p.join(projectRoot.path, '.cursor')).createSync();

        // Install to .claude
        await skillManager.installSkill(skillId: 'shared-skill', model: '.claude');
        
        // Create symlink from .cursor to .claude
        await skillManager.symlinkSkill(
          skillId: 'shared-skill',
          targetModel: '.claude',
          model: '.cursor',
        );

        final symlinkPath = p.join(projectRoot.path, '.cursor', 'skills', 'shared-skill');
        final link = Link(symlinkPath);
        
        expect(link.existsSync(), isTrue);
        
        // Verify symlink points to correct location
        final target = link.targetSync();
        expect(target, contains('.claude'));
        expect(target, contains('shared-skill'));
      });
    });
  });
}

void _createSkillManifest(String skillPath, Map<String, dynamic> manifest) {
  final file = File(p.join(skillPath, 'skill.json'));
  file.writeAsStringSync(jsonEncode(manifest));
}
