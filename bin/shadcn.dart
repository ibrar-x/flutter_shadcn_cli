import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_shadcn_cli/src/installer.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/discovery_commands.dart';
import 'package:flutter_shadcn_cli/src/skill_manager.dart';
import 'package:flutter_shadcn_cli/src/version_manager.dart';

Future<void> main(List<String> arguments) async {
  _ensureExecutablePath();
  final parser = ArgParser()
    ..addFlag('verbose', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('wip', negatable: false, help: 'Enable WIP features')
    ..addFlag('experimental', negatable: false, help: 'Enable experimental features')
    ..addFlag('dev', negatable: false, help: 'Persist local registry for dev mode')
    ..addOption('dev-path', help: 'Local registry path to persist for dev mode')
    ..addOption('registry', allowed: ['auto', 'local', 'remote'], defaultsTo: 'auto')
    ..addOption('registry-path', help: 'Path to local registry folder')
    ..addOption('registry-url', help: 'Remote registry base URL (repo root)')
    ..addCommand(
      'init',
      ArgParser()
        ..addFlag('all', abbr: 'a', negatable: false)
        ..addMultiOption('add', abbr: 'c')
        ..addFlag('yes', abbr: 'y', negatable: false)
        ..addFlag(
          'install-fonts',
          negatable: false,
          help: 'Install typography fonts during init',
        )
        ..addFlag(
          'install-icons',
          negatable: false,
          help: 'Install icon font assets during init',
        )
        ..addOption('install-path', help: 'Install path inside lib/')
        ..addOption('shared-path', help: 'Shared path inside lib/')
        ..addFlag('include-readme', negatable: true)
        ..addFlag('include-meta', negatable: true)
        ..addFlag('include-preview', negatable: true)
        ..addOption('prefix', help: 'Class alias prefix')
        ..addOption('theme', help: 'Theme preset id')
        ..addMultiOption(
          'alias',
          help: 'Path alias (name=lib/path). Enables @name shorthand.',
        )
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'theme',
      ArgParser()
        ..addFlag('list', negatable: false)
        ..addOption('apply', abbr: 'a')
        ..addOption('apply-file', help: 'Apply theme from local JSON file')
        ..addOption('apply-url', help: 'Apply theme from JSON URL')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'add',
      ArgParser()
        ..addFlag('all', abbr: 'a', negatable: false)
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'dry-run',
      ArgParser()
        ..addFlag('all', abbr: 'a', negatable: false)
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'remove',
      ArgParser()
        ..addFlag('all', abbr: 'a', negatable: false)
        ..addFlag('force', abbr: 'f', negatable: false)
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'sync',
      ArgParser()..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'doctor',
      ArgParser()..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'assets',
      ArgParser()
        ..addFlag('icons', negatable: false, help: 'Install icon font assets')
        ..addFlag(
          'typography',
          negatable: false,
          help: 'Install typography font assets (GeistSans/GeistMono)',
        )
        ..addFlag('fonts', negatable: false, help: 'Alias for --typography')
        ..addFlag('list', negatable: false, help: 'List available assets')
        ..addFlag('all', abbr: 'a', negatable: false)
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'platform',
      ArgParser()
        ..addMultiOption(
          'set',
          help: 'Set platform target path (platform.section=path)',
        )
        ..addMultiOption(
          'reset',
          help: 'Remove platform target override (platform.section)',
        )
        ..addFlag('list', negatable: false, help: 'List platform targets')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'list',
      ArgParser()
        ..addFlag('refresh', negatable: false, help: 'Refresh cache')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'search',
      ArgParser()
        ..addFlag('refresh', negatable: false, help: 'Refresh cache')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'info',
      ArgParser()
        ..addFlag('refresh', negatable: false, help: 'Refresh cache')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'install-skill',
      ArgParser()
        ..addOption('skill', abbr: 's', help: 'Skill id to install')
        ..addOption('model', abbr: 'm', help: 'Model name (e.g., gpt-4)')
        ..addOption('skills-url', help: 'Override skills base URL/path')
        ..addFlag('symlink', negatable: false, help: 'Symlink shared skill to model')
        ..addFlag('list', negatable: false, help: 'List installed skills')
        ..addFlag('available', abbr: 'a', negatable: false, help: 'List available skills from registry')
        ..addFlag('interactive', abbr: 'i', negatable: false, help: 'Interactive multi-skill installation')
        ..addOption('uninstall', help: 'Uninstall skill')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'version',
      ArgParser()
        ..addFlag('check', negatable: false, help: 'Check for updates')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'upgrade',
      ArgParser()
        ..addFlag('force', abbr: 'f', negatable: false, help: 'Force upgrade even if already latest')
        ..addFlag('help', abbr: 'h', negatable: false),
    );

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }

  if (argResults['help'] == true) {
    _printUsage();
    exit(0);
  }

  if (argResults.command == null) {
    _printUsage();
    exit(1);
  }

  final targetDir = Directory.current.path;
  final roots = await _resolveRoots();
  final verbose = argResults['verbose'] == true;
  final logger = CliLogger(verbose: verbose);
  var config = await ShadcnConfig.load(targetDir);

  // Auto-check for updates (rate-limited to once per 24 hours)
  // Skip for version and upgrade commands to avoid recursion
  final shouldCheckUpdates = config.checkUpdates ?? true;
  final commandName = argResults.command?.name;
  if (shouldCheckUpdates && commandName != 'version' && commandName != 'upgrade') {
    final versionMgr = VersionManager(logger: logger);
    // Run in background without blocking
    unawaited(versionMgr.autoCheckForUpdates());
  }

  if (argResults['dev'] == true) {
    final resolvedDevPath = _resolveLocalRoot(
      argResults['dev-path'] as String?,
      roots.localRegistryRoot,
      config.registryPath,
    );
    if (resolvedDevPath == null) {
      stderr.writeln('Error: Unable to resolve local registry for dev mode.');
      stderr.writeln('Set SHADCN_REGISTRY_ROOT or --dev-path.');
      exit(1);
    }
    config = config.copyWith(
      registryMode: 'local',
      registryPath: resolvedDevPath,
    );
    await ShadcnConfig.save(targetDir, config);
    logger.success('Saved dev registry path: $resolvedDevPath');
  }

  if (argResults.command!.name == 'doctor') {
    final doctorCommand = argResults.command!;
    if (doctorCommand['help'] == true) {
      print('Usage: flutter_shadcn doctor');
      print('');
      print('Diagnostics for registry resolution and environment.');
      return;
    }
    await _runDoctor(roots, argResults, config);
    return;
  }

  final needsRegistry = const {
    'init',
    'theme',
    'add',
    'dry-run',
    'remove',
    'sync',
    'assets',
  };
  Registry? registry;
  if (needsRegistry.contains(argResults.command!.name)) {
    final selection = _resolveRegistrySelection(argResults, roots, config);
    final schemaPath = _resolveComponentsSchemaPath(roots, selection);
    final cachePath = _componentsJsonCachePath(selection.registryRoot);
    try {
      registry = await Registry.load(
        registryRoot: selection.registryRoot,
        sourceRoot: selection.sourceRoot,
        schemaPath: schemaPath,
        cachePath: cachePath,
        logger: logger,
      );
    } catch (e) {
      stderr.writeln('Error loading registry: $e');
      stderr.writeln('Registry root: ${selection.registryRoot.root}');
      exit(1);
    }
  }

  final installer = registry == null
      ? null
      : Installer(
          registry: registry,
          targetDir: targetDir,
          logger: logger,
        );

  switch (argResults.command!.name) {
    case 'init':
      final initCommand = argResults.command!;
      final activeInstaller = installer;
      if (activeInstaller == null) {
        stderr.writeln('Error: Installer is not available.');
        exit(1);
      }
      if (initCommand['help'] == true) {
        print('Usage: flutter_shadcn init [options]');
        print('');
        print('Options:');
        print('  --add, -c <name>   Add components after init (repeatable)');
        print('  --all, -a          Add every component after init');
        print('  --yes, -y          Skip prompts and use defaults');
        print('  --install-fonts    Install typography fonts during init');
        print('  --install-icons    Install icon font assets during init');
        print('  --install-path     Component install path inside lib/');
        print('  --shared-path      Shared helpers path inside lib/');
        print('  --include-meta     Include meta.json files (recommended)');
        print('  --include-readme   Include README.md files');
        print('  --include-preview  Include preview.dart files');
        print('  --prefix           Class prefix for widget aliases');
        print('  --theme            Theme preset id');
        print(
          '  --alias            Path alias (name=lib/path), allows @name in paths',
        );
        print('  --help, -h         Show this message');
        exit(0);
      }
      final skipPrompts = initCommand['yes'] == true;
      final aliasPairs = (initCommand['alias'] as List).cast<String>();
      final aliases = _parseAliasPairs(aliasPairs);
      final installFonts = initCommand['install-fonts'] == true;
      final installIcons = initCommand['install-icons'] == true;
      final includeReadme = initCommand.wasParsed('include-readme')
          ? initCommand['include-readme'] as bool
          : null;
      final includeMeta = initCommand.wasParsed('include-meta')
          ? initCommand['include-meta'] as bool
          : null;
      final includePreview = initCommand.wasParsed('include-preview')
          ? initCommand['include-preview'] as bool
          : null;
      final installPath = initCommand.wasParsed('install-path')
          ? initCommand['install-path'] as String?
          : null;
      final sharedPath = initCommand.wasParsed('shared-path')
          ? initCommand['shared-path'] as String?
          : null;
      final classPrefix = initCommand.wasParsed('prefix')
          ? initCommand['prefix'] as String?
          : null;
      final aliasOverrides = initCommand.wasParsed('alias') && aliases.isNotEmpty
          ? aliases
          : null;

      await activeInstaller.init(
        skipPrompts: skipPrompts,
        configOverrides: InitConfigOverrides(
          installPath: installPath,
          sharedPath: sharedPath,
          includeReadme: includeReadme,
          includeMeta: includeMeta,
          includePreview: includePreview,
          classPrefix: classPrefix,
          pathAliases: aliasOverrides,
        ),
        themePreset: initCommand['theme'] as String?,
      );

      if (installFonts || installIcons) {
        await activeInstaller.runBulkInstall(() async {
          if (installIcons) {
            await activeInstaller.addComponent('icon_fonts');
          }
          if (installFonts) {
            await activeInstaller.addComponent('typography_fonts');
          }
        });
      }

      final addAll = initCommand['all'] == true;
      final addList = <String>[
        ...(initCommand['add'] as List).cast<String>(),
        ...initCommand.rest,
      ];
      if (addAll) {
        await activeInstaller.runBulkInstall(() async {
          await activeInstaller.addComponent('icon_fonts');
          await activeInstaller.addComponent('typography_fonts');
          await activeInstaller.installAllComponents();
        });
        break;
      }
      if (addList.isNotEmpty) {
        await activeInstaller.runBulkInstall(() async {
          for (final componentName in addList) {
            await activeInstaller.addComponent(componentName);
          }
        });
      }
      break;
    case 'theme':
      final themeCommand = argResults.command!;
      final activeInstaller = installer;
      if (activeInstaller == null) {
        stderr.writeln('Error: Installer is not available.');
        exit(1);
      }
      if (themeCommand['help'] == true) {
        print(
            'Usage: flutter_shadcn theme [--list | --apply <preset> | --apply-file <path> | --apply-url <url>]');
        print('');
        print('Options:');
        print('  --list             Show all available theme presets');
        print('  --apply, -a <id>   Apply the preset with the given ID');
        print('  --apply-file       Apply a theme JSON file (experimental)');
        print('  --apply-url        Apply a theme JSON URL (experimental)');
        print('  --help, -h         Show this message');
        print('');
        print('Experimental:');
        print('  Use --experimental to enable apply-file/apply-url.');
        exit(0);
      }
      final isExperimental = argResults['experimental'] == true;
      if (themeCommand['list'] == true) {
        await activeInstaller.listThemes();
        break;
      }
      final applyFile = themeCommand['apply-file'] as String?;
      final applyUrl = themeCommand['apply-url'] as String?;
      if (applyFile != null || applyUrl != null) {
        if (!isExperimental) {
          stderr.writeln('Error: --apply-file/--apply-url require --experimental.');
          exit(1);
        }
        if (applyFile != null) {
          await activeInstaller.applyThemeFromFile(applyFile);
          break;
        }
        if (applyUrl != null) {
          await activeInstaller.applyThemeFromUrl(applyUrl);
          break;
        }
      }
      final applyOption = themeCommand['apply'] as String?;
      final rest = themeCommand.rest;
      final presetArg = applyOption ?? (rest.isEmpty ? null : rest.first);
      if (presetArg != null) {
        await activeInstaller.applyThemeById(presetArg);
        break;
      }
      await activeInstaller.chooseTheme();
      break;
    case 'add':
      final addCommand = argResults.command!;
      final activeInstaller = installer;
      if (activeInstaller == null) {
        stderr.writeln('Error: Installer is not available.');
        exit(1);
      }
      if (addCommand['help'] == true) {
        print('Usage: flutter_shadcn add <component> [<component> ...]');
        print('       flutter_shadcn add --all');
        print('Options:');
        print('  --all, -a          Install every available component');
        print('  --help, -h         Show this message');
        exit(0);
      }
      final rest = addCommand.rest;
      final addAll = addCommand['all'] == true || rest.contains('all');
      if (addAll) {
        await activeInstaller.ensureInitFiles(allowPrompts: false);
        await activeInstaller.runBulkInstall(() async {
          await activeInstaller.addComponent('icon_fonts');
          await activeInstaller.addComponent('typography_fonts');
          await activeInstaller.installAllComponents();
        });
        break;
      }
      if (rest.isEmpty) {
        print('Usage: flutter_shadcn add <component>');
        print('       flutter_shadcn add --all');
        exit(1);
      }
      await activeInstaller.ensureInitFiles(allowPrompts: false);
      await activeInstaller.runBulkInstall(() async {
        for (final componentName in rest) {
          await activeInstaller.addComponent(componentName);
        }
      });
      break;
    case 'dry-run':
      final dryRunCommand = argResults.command!;
      final activeInstaller = installer;
      if (activeInstaller == null) {
        stderr.writeln('Error: Installer is not available.');
        exit(1);
      }
      if (dryRunCommand['help'] == true) {
        print('Usage: flutter_shadcn dry-run <component> [<component> ...]');
        print('       flutter_shadcn dry-run --all');
        print('');
        print('Shows what would be installed (dependencies, shared modules, assets, fonts).');
        print('Options:');
        print('  --all, -a          Include every available component');
        print('  --help, -h         Show this message');
        exit(0);
      }
      final rest = dryRunCommand.rest;
      final dryRunAll = dryRunCommand['all'] == true || rest.contains('all');
      final componentIds = <String>[];
      if (dryRunAll) {
        componentIds.add('icon_fonts');
        componentIds.add('typography_fonts');
        componentIds.addAll(activeInstaller.registry.components.map((c) => c.id));
      } else {
        if (rest.isEmpty) {
          print('Usage: flutter_shadcn dry-run <component> [<component> ...]');
          print('       flutter_shadcn dry-run --all');
          exit(1);
        }
        componentIds.addAll(rest);
      }
      final plan = await activeInstaller.buildDryRunPlan(componentIds);
      activeInstaller.printDryRunPlan(plan);
      break;
    case 'remove':
      final removeCommand = argResults.command!;
      final activeInstaller = installer;
      if (activeInstaller == null) {
        stderr.writeln('Error: Installer is not available.');
        exit(1);
      }
      if (removeCommand['help'] == true) {
        print('Usage: flutter_shadcn remove <component> [<component> ...]');
        print('       flutter_shadcn remove --all');
        print('Options:');
        print('  --all, -a          Remove every installed component');
        print('  --force, -f        Force removal even if dependencies remain');
        print('  --help, -h         Show this message');
        exit(0);
      }
      final rest = removeCommand.rest;
      final removeAll = removeCommand['all'] == true || rest.contains('all');
      if (removeAll) {
        await activeInstaller.removeAllComponents(force: true);
        break;
      }
      if (rest.isEmpty) {
        print('Usage: flutter_shadcn remove <component>');
        exit(1);
      }
      final force = removeCommand['force'] == true;
      for (final componentName in rest) {
        await activeInstaller.removeComponent(componentName, force: force);
      }
      await activeInstaller.generateAliases();
      break;
    case 'doctor':
      final doctorCommand = argResults.command!;
      if (doctorCommand['help'] == true) {
        print('Usage: flutter_shadcn doctor');
        print('');
        print('Diagnostics for registry resolution and environment.');
        exit(0);
      }
      break;
    case 'assets':
      final assetsCommand = argResults.command!;
      final activeInstaller = installer;
      if (activeInstaller == null) {
        stderr.writeln('Error: Installer is not available.');
        exit(1);
      }
      if (assetsCommand['help'] == true) {
        print('Usage: flutter_shadcn assets [options]');
        print('');
        print('Options:');
        print('  --icons          Install icon font assets (Lucide/Radix/Bootstrap)');
        print('  --typography     Install typography fonts (GeistSans/GeistMono)');
        print('  --fonts          Alias for --typography');
        print('  --list           List available assets');
        print('  --all, -a        Install both icon + typography fonts');
        print('  --help, -h       Show this message');
        exit(0);
      }

      if (assetsCommand['list'] == true) {
        print('Available assets:');
        print('  icon_fonts       Lucide/Radix/Bootstrap icon fonts');
        print('  typography_fonts GeistSans/GeistMono font families');
        break;
      }

      final installAll = assetsCommand['all'] == true;
      final installIcons = assetsCommand['icons'] == true;
      final installTypography =
          assetsCommand['typography'] == true || assetsCommand['fonts'] == true;
      if (!installAll && !installIcons && !installTypography) {
        print('Nothing selected. Use --icons, --typography, or --all.');
        exit(1);
      }

      await activeInstaller.runBulkInstall(() async {
        if (installAll || installIcons) {
          await activeInstaller.addComponent('icon_fonts');
        }
        if (installAll || installTypography) {
          await activeInstaller.addComponent('typography_fonts');
        }
      });
      break;
    case 'platform':
      final platformCommand = argResults.command!;
      if (platformCommand['help'] == true) {
        print('Usage: flutter_shadcn platform [--list | --set <p.s=path> | --reset <p.s>]');
        print('');
        print('Options:');
        print('  --list             List platform targets');
        print('  --set              Set override (repeatable), e.g. ios.infoPlist=ios/Runner/Info.plist');
        print('  --reset            Remove override (repeatable), e.g. ios.infoPlist');
        print('  --help, -h         Show this message');
        exit(0);
      }
      final sets = (platformCommand['set'] as List).cast<String>();
      final resets = (platformCommand['reset'] as List).cast<String>();
      final list = platformCommand['list'] == true;
      if (sets.isEmpty && resets.isEmpty && !list) {
        print('Nothing selected. Use --list, --set, or --reset.');
        exit(1);
      }

      final updated = _updatePlatformTargets(config, sets, resets);
      if (updated != null) {
        config = updated;
        await ShadcnConfig.save(targetDir, config);
      }
      final targets = _mergePlatformTargets(config.platformTargets);
      _printPlatformTargets(targets);
      break;
    case 'sync':
      final syncCommand = argResults.command!;
      final activeInstaller = installer;
      if (activeInstaller == null) {
        stderr.writeln('Error: Installer is not available.');
        exit(1);
      }
      if (syncCommand['help'] == true) {
        print('Usage: flutter_shadcn sync');
        print('');
        print('Re-applies .shadcn/config.json (paths, theme) to existing files.');
        exit(0);
      }
      await activeInstaller.syncFromConfig();
      break;
    case 'list':
      final listCommand = argResults.command!;
      if (listCommand['help'] == true) {
        print('Usage: flutter_shadcn list [--refresh]');
        print('');
        print('Lists all available components from the registry.');
        print('Options:');
        print('  --refresh  Refresh cache from remote');
        exit(0);
      }
      final selection = _resolveRegistrySelection(argResults, roots, config);
      final registryUrl = selection.registryRoot.root;
      await handleListCommand(
        registryBaseUrl: registryUrl,
        registryId: _sanitizeCacheKey(registryUrl),
        refresh: listCommand['refresh'] == true,
        logger: logger,
      );
      break;
    case 'search':
      final searchCommand = argResults.command!;
      if (searchCommand['help'] == true) {
        print('Usage: flutter_shadcn search <query> [--refresh]');
        print('');
        print('Searches for components by name, description, or tags.');
        print('Options:');
        print('  --refresh  Refresh cache from remote');
        exit(0);
      }
      final searchQuery = searchCommand.rest.join(' ');
      if (searchQuery.isEmpty) {
        print('Usage: flutter_shadcn search <query>');
        exit(1);
      }
      final selection = _resolveRegistrySelection(argResults, roots, config);
      final registryUrl = selection.registryRoot.root;
      await handleSearchCommand(
        query: searchQuery,
        registryBaseUrl: registryUrl,
        registryId: _sanitizeCacheKey(registryUrl),
        refresh: searchCommand['refresh'] == true,
        logger: logger,
      );
      break;
    case 'info':
      final infoCommand = argResults.command!;
      if (infoCommand['help'] == true) {
        print('Usage: flutter_shadcn info <component-id> [--refresh]');
        print('');
        print('Shows detailed information about a component.');
        print('Options:');
        print('  --refresh  Refresh cache from remote');
        exit(0);
      }
      final componentId = infoCommand.rest.isNotEmpty ? infoCommand.rest.first : '';
      if (componentId.isEmpty) {
        print('Usage: flutter_shadcn info <component-id>');
        exit(1);
      }
      final selection = _resolveRegistrySelection(argResults, roots, config);
      final registryUrl = selection.registryRoot.root;
      await handleInfoCommand(
        componentId: componentId,
        registryBaseUrl: registryUrl,
        registryId: _sanitizeCacheKey(registryUrl),
        refresh: infoCommand['refresh'] == true,
        logger: logger,
      );
      break;
    case 'install-skill':
      final skillCommand = argResults.command!;
      if (skillCommand['help'] == true) {
        print('Usage: flutter_shadcn install-skill [--skill <id>] [--model <name>] [options]');
        print('');
        print('Manages AI skills for model-specific installations.');
        print('Discovers hidden AI model folders (.claude, .gpt4, .cursor, etc.) in project root.');
        print('');
        print('Modes:');
        print('  (no args)              Multi-skill interactive mode (default)');
        print('  --available, -a        List all available skills from skills.json registry');
        print('  --list                 List all installed skills grouped by model');
        print('  --skill <id>           Install single skill (opens interactive model menu if no --model)');
        print('  --skill <id> --model   Install skill to specific model folder');
        print('  --skills-url           Override skills base URL/path (defaults to registry URL)');
        print('  --symlink --model      Create symlinks from source model to other models');
        print('  --uninstall <id>       Remove skill from specific model (requires --model)');
        print('');
        print('Default Interactive Installation Flow:');
        print('  1. Shows all available skills from skills.json');
        print('  2. Select which skills to install (comma-separated or "all")');
        print('  3. Discovers all .{model}/ folders (shown with readable names)');
        print('  4. Select target models (numbered menu or "all")');
        print('  5. Choose mode for multiple selections:');
        print('     - Copy skill to each model folder');
        print('     - Install to one model, symlink to others');
        print('  6. Creates skill folder structure in selected models');
        print('');
        print('Examples:');
        print('  flutter_shadcn install-skill                    # Default: multi-skill interactive');
        print('  flutter_shadcn install-skill --available        # List available skills from registry');
        print('  flutter_shadcn install-skill --skill my-skill   # Install single skill, pick models');
        print('  flutter_shadcn install-skill --list             # Show installed skills by model');
        print('  flutter_shadcn install-skill --skill my-skill --model .claude  # Install to specific model');
        exit(0);
      }

      // Resolve skills base path (project root for discovering model folders)
      final selection = _resolveRegistrySelection(argResults, roots, config);
      final skillsOverride = skillCommand['skills-url'] as String?;
      final defaultSkillsUrl = skillsOverride?.isNotEmpty == true
          ? skillsOverride!
          : (config.registryUrl?.isNotEmpty == true
              ? config.registryUrl!
              : selection.sourceRoot.root);

      final skillMgr = SkillManager(
        projectRoot: targetDir,
        skillsBasePath: p.join(targetDir, 'skills'),
        skillsBaseUrl: defaultSkillsUrl,
        logger: logger,
      );

      if (skillCommand['available'] == true) {
        await skillMgr.listAvailableSkills();
      } else if (skillCommand['list'] == true) {
        await skillMgr.listSkills();
      } else if (skillCommand.wasParsed('uninstall')) {
        final skillId = skillCommand['uninstall'] as String;
        final model = skillCommand.wasParsed('model')
            ? skillCommand['model'] as String?
            : null;
        if (model == null) {
          logger.error('--uninstall requires --model');
          exit(1);
        }
        await skillMgr.uninstallSkill(skillId: skillId, model: model);
      } else if (skillCommand['symlink'] == true) {
        final skillId = skillCommand.wasParsed('skill')
            ? skillCommand['skill'] as String
            : null;
        final targetModel = skillCommand.wasParsed('model')
            ? skillCommand['model'] as String
            : null;
        if (skillId == null || targetModel == null) {
          logger.error('--symlink requires both --skill and --model');
          exit(1);
        }
        // Ask for destination models
        final allModels = skillMgr.discoverModelFolders();
        final available =
            allModels.where((m) => m != targetModel).toList();
        if (available.isEmpty) {
          logger.error('No other models available to symlink to.');
          exit(1);
        }
        logger.section('🔗 Create symlinks for skill: $skillId');
        print('\nAvailable target models:');
        for (var i = 0; i < available.length; i++) {
          print('  ${i + 1}. ${available[i]}');
        }
        print('  ${available.length + 1}. All');
        stdout.write('\nSelect models (comma-separated) or all: ');
        final input = stdin.readLineSync()?.trim() ?? '';
        if (input == '${available.length + 1}' ||
            input.toLowerCase() == 'all') {
          for (final model in available) {
            await skillMgr.symlinkSkill(
              skillId: skillId,
              targetModel: targetModel,
              model: model,
            );
          }
        } else {
          final indices = input.split(',').map((i) => int.tryParse(i.trim()));
          for (final idx in indices) {
            if (idx != null && idx > 0 && idx <= available.length) {
              await skillMgr.symlinkSkill(
                skillId: skillId,
                targetModel: targetModel,
                model: available[idx - 1],
              );
            }
          }
        }
      } else if (skillCommand.wasParsed('skill')) {
        final skillId = skillCommand['skill'] as String;
        final model = skillCommand.wasParsed('model')
            ? skillCommand['model'] as String?
            : null;
        if (model != null) {
          // Direct install to specified model
          await skillMgr.installSkill(skillId: skillId, model: model);
        } else {
          // Interactive mode - show models
          await skillMgr.installSkillInteractive(skillId: skillId);
        }
      } else {
        // Default: multi-skill interactive mode (no flags needed)
        await skillMgr.installSkillsInteractive();
      }
      break;
    case 'version':
      final versionCommand = argResults.command!;
      if (versionCommand['help'] == true) {
        print('Usage: flutter_shadcn version [--check]');
        print('');
        print('Shows the current CLI version.');
        print('');
        print('Options:');
        print('  --check  Check for available updates');
        print('  --help, -h  Show this message');
        exit(0);
      }
      final versionMgr = VersionManager(logger: logger);
      if (versionCommand['check'] == true) {
        await versionMgr.checkForUpdates();
      } else {
        versionMgr.showVersion();
      }
      break;
    case 'upgrade':
      final upgradeCommand = argResults.command!;
      if (upgradeCommand['help'] == true) {
        print('Usage: flutter_shadcn upgrade [--force]');
        print('');
        print('Upgrades flutter_shadcn_cli to the latest version from pub.dev.');
        print('');
        print('Options:');
        print('  --force, -f  Force upgrade even if already on latest version');
        print('  --help, -h   Show this message');
        exit(0);
      }
      final versionMgr = VersionManager(logger: logger);
      await versionMgr.upgrade(force: upgradeCommand['force'] == true);
      break;
  }
}

void _printUsage() {
  print('Usage: flutter_shadcn <command> [arguments]');
  print('Commands:');
  print('  init           Initialize shadcn_flutter in the current project');
  print('  theme          Manage registry theme presets');
  print('  add            Add a widget');
  print('  dry-run        Preview what would be installed');
  print('  remove         Remove a widget');
  print('  sync           Sync changes from .shadcn/config.json');
  print('  assets         Install font/icon assets');
  print('  platform       Configure platform targets');
  print('  list           List available components');
  print('  search         Search for components');
  print('  info           Show component details');
  print('  install-skill  Install AI skills');
  print('  version        Show CLI version');
  print('  upgrade        Upgrade CLI to latest version');
  print('  doctor         Diagnose registry resolution');
  print('');
  print('Global flags:');
  print('  --verbose        Verbose logging');
  print('  --dev            Persist local registry for dev mode');
  print('  --dev-path       Local registry path to persist for dev mode');
  print('  --registry       auto|local|remote (default: auto)');
  print('  --registry-path  Path to local registry folder');
  print('  --registry-url   Remote registry base URL');
  print('  --wip            Enable WIP features');
  print('  --experimental   Enable experimental features');
}

void _ensureExecutablePath() {
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return;
  }
  final pubBin = p.join(home, '.pub-cache', 'bin');
  final pathEntries = (Platform.environment['PATH'] ?? '').split(':');
  if (pathEntries.contains(pubBin)) {
    return;
  }
  final target = p.join(pubBin, 'flutter_shadcn');
  final linkPath = '/usr/local/bin/flutter_shadcn';
  if (!File(target).existsSync()) {
    return;
  }
  final link = Link(linkPath);
  try {
    if (link.existsSync()) {
      return;
    }
    link.createSync(target);
  } catch (_) {
    return;
  }
}

Future<ResolvedRoots> _resolveRoots() async {
  final cliRoot = await _packageRoot();
  final registryRoot = await _resolveRegistryRoot(cliRoot);
  return ResolvedRoots(
    localRegistryRoot: registryRoot,
    cliRoot: cliRoot,
  );
}

Future<String?> _resolveRegistryRoot(String? cliRoot) async {
  final envRoot = Platform.environment['SHADCN_REGISTRY_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) {
    final resolved = _validateRegistryRoot(envRoot);
    if (resolved != null) {
      return resolved;
    }
  }

  final kitFromCli = _findKitRegistryFromCliRoot(cliRoot);
  if (kitFromCli != null) {
    return kitFromCli;
  }

  final kitFromCwd = _findKitRegistryUpwards(Directory.current);
  if (kitFromCwd != null) {
    return kitFromCwd;
  }

  final globalRegistry = _globalPackageRegistry();
  if (globalRegistry != null) {
    return globalRegistry;
  }

  if (cliRoot != null) {
    final fromPackage = _validateRegistryRoot(p.join(cliRoot, 'registry'));
    if (fromPackage != null) {
      return fromPackage;
    }
  }

  final scriptPath = Platform.script.toFilePath();
  final scriptDir = Directory(p.dirname(scriptPath));
  final kitFromScript = _findKitRegistryUpwards(scriptDir);
  if (kitFromScript != null) {
    return kitFromScript;
  }
  final fromScript = _findRegistryUpwards(scriptDir);
  if (fromScript != null) {
    return fromScript;
  }

  final fromCwd = _findRegistryUpwards(Directory.current);
  if (fromCwd != null) {
    return fromCwd;
  }

  return null;
}

String? _findKitRegistryFromCliRoot(String? cliRoot) {
  if (cliRoot == null) {
    return null;
  }
  final parent = p.dirname(cliRoot);
  final candidates = [
    p.join(parent, 'shadcn_flutter_kit', 'flutter_shadcn_kit', 'lib', 'registry'),
    p.join(parent, 'flutter_shadcn_kit', 'lib', 'registry'),
    p.join(parent, 'shadcn_flutter_kit', 'lib', 'registry'),
  ];
  for (final candidate in candidates) {
    final resolved = _validateRegistryRoot(candidate);
    if (resolved != null) {
      return resolved;
    }
  }
  return null;
}

String? _findKitRegistryUpwards(Directory start) {
  var current = start.absolute;
  for (var i = 0; i < 8; i++) {
    final candidates = [
      p.join(current.path, 'shadcn_flutter_kit', 'flutter_shadcn_kit', 'lib', 'registry'),
      p.join(current.path, 'flutter_shadcn_kit', 'lib', 'registry'),
      p.join(current.path, 'shadcn_flutter_kit', 'lib', 'registry'),
    ];
    for (final candidate in candidates) {
      final resolved = _validateRegistryRoot(candidate);
      if (resolved != null) {
        return resolved;
      }
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }
  return null;
}

String? _validateRegistryRoot(String candidate) {
  if (File(p.join(candidate, 'components.json')).existsSync()) {
    return candidate;
  }
  return null;
}

String? _globalPackageRegistry() {
  final pubCache = Platform.environment['PUB_CACHE'] ??
      p.join(Platform.environment['HOME'] ?? '', '.pub-cache');
  if (pubCache.isEmpty) {
    return null;
  }
  final packageRoot = p.join(pubCache, 'global_packages', 'flutter_shadcn_cli');
  return _validateRegistryRoot(p.join(packageRoot, 'registry'));
}

Future<String?> _packageRoot() async {
  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:flutter_shadcn_cli/flutter_shadcn_cli.dart'),
  );
  if (packageUri == null) {
    return null;
  }
  final packageLib = File.fromUri(packageUri).parent;
  return packageLib.parent.path;
}

String? _findRegistryUpwards(Directory start) {
  var current = start.absolute;
  for (var i = 0; i < 8; i++) {
    final registryDir = Directory(p.join(current.path, 'registry'));
    final componentsFile = File(p.join(registryDir.path, 'components.json'));
    if (componentsFile.existsSync()) {
      return registryDir.path;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }
  return null;
}

Future<void> _runDoctor(
  ResolvedRoots roots,
  ArgResults args,
  ShadcnConfig config,
) async {
  final logger = CliLogger(verbose: args['verbose'] == true);
  final selection = _resolveRegistrySelection(args, roots, config);
  final envRoot = Platform.environment['SHADCN_REGISTRY_ROOT'];
  final envUrl = Platform.environment['SHADCN_REGISTRY_URL'];
  final pubCache = Platform.environment['PUB_CACHE'] ??
      p.join(Platform.environment['HOME'] ?? '', '.pub-cache');
  final schemaPath = _resolveComponentsSchemaPath(roots, selection);
  final cachePath = _componentsJsonCachePath(selection.registryRoot);
  final componentsSource = selection.registryRoot.describe('components.json');

  logger.header('flutter_shadcn doctor');

  void kv(String label, String value) {
    const pad = 22;
    final padded = label.padRight(pad);
    logger.info('  $padded $value');
  }

  print('');
  logger.section('Environment');
  kv('Script', Platform.script.toFilePath());
  kv('CWD', Directory.current.path);
  kv('PUB_CACHE', pubCache);

  print('');
  logger.section('Registry');
  kv('Mode', selection.mode);
  kv('Root', selection.registryRoot.root);
  kv('components.json', componentsSource);
  kv('Cache', cachePath ?? '(local registry, no cache)');
  kv('Schema', schemaPath ?? '(not found)');

  print('');
  logger.section('Configuration');
  kv('SHADCN_REGISTRY_ROOT', envRoot ?? '(unset)');
  kv('SHADCN_REGISTRY_URL', envUrl ?? '(unset)');
  kv('cliRoot', roots.cliRoot ?? '(unresolved)');
  kv('localRegistryRoot', roots.localRegistryRoot ?? '(unresolved)');
  kv('config.registryMode', config.registryMode ?? '(unset)');
  kv('config.registryPath', config.registryPath ?? '(unset)');
  kv('config.registryUrl', config.registryUrl ?? '(unset)');

  print('');
  logger.section('Schema validation');
  if (schemaPath == null) {
    logger.warn('  Schema file not found.');
  } else {
    try {
      final content = await selection.registryRoot.readString('components.json');
      final data = jsonDecode(content);
      final result = ComponentsSchemaValidator.validate(data, schemaPath);
      if (result.isValid) {
        logger.success('  components.json matches the schema.');
      } else {
        logger.error('  Schema issues: ${result.errors.length}');
        for (final error in result.errors.take(12)) {
          logger.info('  - $error');
        }
        if (result.errors.length > 12) {
          logger.info('  ...and ${result.errors.length - 12} more');
        }
      }
    } catch (e) {
      logger.error('  Failed to validate schema: $e');
    }
  }

  final platformTargets = _mergePlatformTargets(config.platformTargets);
  print('');
  logger.section('Platform targets');
  logger.info('  (set .shadcn/config.json "platformTargets" to override paths)');
  platformTargets.forEach((platform, targets) {
    logger.info('  $platform:');
    for (final entry in targets.entries) {
      logger.info('    ${entry.key}: ${entry.value}');
    }
  });
}

String? _componentsJsonCachePath(RegistryLocation registryRoot) {
  if (!registryRoot.isRemote) {
    return null;
  }
  final home = Platform.environment['HOME'] ?? '';
  if (home.isEmpty) {
    return null;
  }
  final cacheRoot = p.join(home, '.flutter_shadcn', 'cache', 'registry');
  final safeKey = _sanitizeCacheKey(registryRoot.root);
  return p.join(cacheRoot, safeKey, 'components.json');
}

String _sanitizeCacheKey(String value) {
  final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (safe.length > 80) {
    return safe.substring(0, 80);
  }
  return safe;
}

String? _resolveComponentsSchemaPath(
  ResolvedRoots roots,
  RegistrySelection selection,
) {
  final candidates = <String?>[
    p.join(
      Directory.current.path,
      'shadcn_flutter_kit',
      'flutter_shadcn_kit',
      'lib',
      'registry',
      'components.schema.json',
    ),
    p.join(
      Directory.current.path,
      'flutter_shadcn_kit',
      'lib',
      'registry',
      'components.schema.json',
    ),
    roots.localRegistryRoot == null
        ? null
        : p.join(roots.localRegistryRoot!, 'components.schema.json'),
    '/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_kit/flutter_shadcn_kit/lib/registry/components.schema.json',
  ];

  for (final candidate in candidates) {
    if (candidate == null) {
      continue;
    }
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  if (!selection.registryRoot.isRemote) {
    final localPath = p.join(selection.registryRoot.root, 'components.schema.json');
    if (File(localPath).existsSync()) {
      return localPath;
    }
  }

  return null;
}

Map<String, Map<String, String>> _mergePlatformTargets(
  Map<String, Map<String, String>>? overrides,
) {
  final defaults = <String, Map<String, String>>{
    'android': {
      'permissions': 'android/app/src/main/AndroidManifest.xml',
      'gradle': 'android/app/build.gradle',
      'notes': '.shadcn/platform/android.md',
    },
    'ios': {
      'infoPlist': 'ios/Runner/Info.plist',
      'podfile': 'ios/Podfile',
      'notes': '.shadcn/platform/ios.md',
    },
    'macos': {
      'entitlements': 'macos/Runner/DebugProfile.entitlements',
      'notes': '.shadcn/platform/macos.md',
    },
    'desktop': {
      'config': '.shadcn/platform/desktop.md',
    },
  };
  final merged = <String, Map<String, String>>{};
  for (final entry in defaults.entries) {
    merged[entry.key] = Map<String, String>.from(entry.value);
  }
  if (overrides != null) {
    overrides.forEach((platform, value) {
      merged.putIfAbsent(platform, () => {});
      merged[platform]!.addAll(value);
    });
  }
  return merged;
}

ShadcnConfig? _updatePlatformTargets(
  ShadcnConfig config,
  List<String> sets,
  List<String> resets,
) {
  if (sets.isEmpty && resets.isEmpty) {
    return null;
  }
  final current = config.platformTargets == null
      ? <String, Map<String, String>>{}
      : Map<String, Map<String, String>>.fromEntries(
          config.platformTargets!.entries.map(
            (entry) => MapEntry(entry.key, Map<String, String>.from(entry.value)),
          ),
        );

  for (final reset in resets) {
    final parts = reset.split('.');
    if (parts.length != 2) {
      stderr.writeln('Invalid reset format: $reset (use platform.section)');
      continue;
    }
    final platform = parts[0];
    final section = parts[1];
    final sectionMap = current[platform];
    sectionMap?.remove(section);
    if (sectionMap != null && sectionMap.isEmpty) {
      current.remove(platform);
    }
  }

  for (final set in sets) {
    final parts = set.split('=');
    if (parts.length != 2) {
      stderr.writeln('Invalid set format: $set (use platform.section=path)');
      continue;
    }
    final key = parts[0];
    final value = parts[1];
    final keyParts = key.split('.');
    if (keyParts.length != 2) {
      stderr.writeln('Invalid set key: $key (use platform.section)');
      continue;
    }
    final platform = keyParts[0];
    final section = keyParts[1];
    current.putIfAbsent(platform, () => {});
    current[platform]![section] = value;
  }

  return config.copyWith(platformTargets: current);
}

void _printPlatformTargets(Map<String, Map<String, String>> targets) {
  final logger = CliLogger();
  logger.section('Platform targets');
  if (targets.isEmpty) {
    logger.info('  (no targets configured)');
    return;
  }
  targets.forEach((platform, sections) {
    logger.info('  $platform:');
    for (final entry in sections.entries) {
      logger.info('    ${entry.key}: ${entry.value}');
    }
  });
}

class ResolvedRoots {
  final String? localRegistryRoot;
  final String? cliRoot;

  const ResolvedRoots({
    required this.localRegistryRoot,
    required this.cliRoot,
  });
}

RegistrySelection _resolveRegistrySelection(
  ArgResults? args,
  ResolvedRoots roots,
  ShadcnConfig config,
) {
  final mode = (args?['registry'] as String?) ?? config.registryMode ?? 'auto';
  final pathOverride = (args?['registry-path'] as String?) ?? config.registryPath;
  final urlOverride = (args?['registry-url'] as String?) ?? config.registryUrl;

  if (mode == 'local' || mode == 'auto') {
    var localRoot = _resolveLocalRoot(
      pathOverride,
      roots.localRegistryRoot,
      config.registryPath,
    );
    localRoot ??= _findKitRegistryUpwards(Directory.current);
    localRoot ??= _findKitRegistryFromCliRoot(roots.cliRoot);
    if (localRoot != null) {
      final sourceRoot = p.dirname(localRoot);
      return RegistrySelection(
        mode: 'local',
        registryRoot: RegistryLocation.local(localRoot),
        sourceRoot: RegistryLocation.local(sourceRoot),
      );
    }
    if (mode == 'local') {
      stderr.writeln('Error: Local registry not found.');
      stderr.writeln('Set SHADCN_REGISTRY_ROOT or --registry-path.');
      exit(1);
    }
  }

  final remoteBase = _resolveRemoteBase(urlOverride);
  final remoteRoots = _resolveRemoteRoots(remoteBase);
  return RegistrySelection(
    mode: 'remote',
    registryRoot: RegistryLocation.remote(remoteRoots.registryRoot),
    sourceRoot: RegistryLocation.remote(remoteRoots.sourceRoot),
  );
}

String? _resolveLocalRoot(
  String? override,
  String? detected,
  String? configPath,
) {
  if (override != null && override.isNotEmpty) {
    return _validateRegistryRoot(override);
  }
  if (configPath != null && configPath.isNotEmpty) {
    return _validateRegistryRoot(configPath) ?? detected;
  }
  return detected;
}

String _resolveRemoteBase(String? override) {
  final envUrl = Platform.environment['SHADCN_REGISTRY_URL'];
  if (override != null && override.isNotEmpty) {
    return override;
  }
  if (envUrl != null && envUrl.isNotEmpty) {
    return envUrl;
  }
  return _defaultRemoteRegistryBase;
}

_RemoteRoots _resolveRemoteRoots(String base) {
  final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  if (normalized.endsWith('/registry')) {
    final sourceRoot = normalized.substring(0, normalized.length - '/registry'.length);
    return _RemoteRoots(registryRoot: normalized, sourceRoot: sourceRoot);
  }
  return _RemoteRoots(
    registryRoot: '$normalized/registry',
    sourceRoot: normalized,
  );
}

class RegistrySelection {
  final String mode;
  final RegistryLocation registryRoot;
  final RegistryLocation sourceRoot;

  const RegistrySelection({
    required this.mode,
    required this.registryRoot,
    required this.sourceRoot,
  });
}

class _RemoteRoots {
  final String registryRoot;
  final String sourceRoot;

  const _RemoteRoots({
    required this.registryRoot,
    required this.sourceRoot,
  });
}

Map<String, String> _parseAliasPairs(List<String> entries) {
  final aliases = <String, String>{};
  for (final entry in entries) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final parts = trimmed.split('=');
    if (parts.length != 2) {
      continue;
    }
    final key = parts.first.trim();
    final value = parts.last.trim();
    if (key.isEmpty || value.isEmpty) {
      continue;
    }
    aliases[key] = _stripLibPrefix(value);
  }
  return aliases;
}

String _stripLibPrefix(String value) {
  final normalized = p.normalize(value);
  if (normalized == 'lib') {
    return '';
  }
  if (normalized.startsWith('lib${p.separator}')) {
    return normalized.substring('lib'.length + 1);
  }
  return normalized;
}

const String _defaultRemoteRegistryBase =
  'https://cdn.jsdelivr.net/gh/ibrar-x/shadcn_flutter_kit@latest/flutter_shadcn_kit/lib';