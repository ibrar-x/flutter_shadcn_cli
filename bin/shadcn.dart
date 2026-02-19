import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_shadcn_cli/src/installer.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/registry_directory.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/discovery_commands.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_manager.dart';
import 'package:flutter_shadcn_cli/src/json_output.dart';
import 'package:flutter_shadcn_cli/src/skill_manager.dart';
import 'package:flutter_shadcn_cli/src/version_manager.dart';
import 'package:flutter_shadcn_cli/src/feedback_manager.dart';
import 'package:flutter_shadcn_cli/src/validate_command.dart';
import 'package:flutter_shadcn_cli/src/audit_command.dart';
import 'package:flutter_shadcn_cli/src/deps_command.dart';
import 'package:flutter_shadcn_cli/src/docs_generator.dart';

Future<void> main(List<String> arguments) async {
  _ensureExecutablePath();
  final parser = ArgParser()
    ..addFlag('verbose', abbr: 'v', negatable: false)
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('wip', negatable: false, help: 'Enable WIP features')
    ..addFlag('experimental',
        negatable: false, help: 'Enable experimental features')
    ..addFlag('offline',
        negatable: false,
        help: 'Disable network calls and use cached registry data only')
    ..addFlag('dev',
        negatable: false, help: 'Persist local registry for dev mode')
    ..addOption('dev-path', help: 'Local registry path to persist for dev mode')
    ..addOption('registry',
        allowed: ['auto', 'local', 'remote'], defaultsTo: 'auto')
    ..addOption(
      'registry-name',
      help: 'Registry namespace selection (e.g. shadcn, orient)',
    )
    ..addOption('registry-path', help: 'Path to local registry folder')
    ..addOption('registry-url', help: 'Remote registry base URL (repo root)')
    ..addOption(
      'registries-url',
      help: 'Remote registries.json directory URL for multi-registry mode',
    )
    ..addOption(
      'registries-path',
      help: 'Local registries.json file or directory path (dev mode)',
    )
    ..addCommand(
      'init',
      ArgParser()
        ..addFlag('all', abbr: 'a', negatable: false)
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
        ..addMultiOption(
          'include-files',
          help:
              'Optional file kinds to include (readme, preview, meta). Comma-separated or repeated.',
        )
        ..addMultiOption(
          'exclude-files',
          help:
              'Optional file kinds to exclude (readme, preview, meta). Comma-separated or repeated.',
        )
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'dry-run',
      ArgParser()
        ..addFlag('all', abbr: 'a', negatable: false)
        ..addFlag('json',
            negatable: false, help: 'Output machine-readable JSON')
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
      ArgParser()
        ..addFlag('json',
            negatable: false, help: 'Output machine-readable JSON')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'validate',
      ArgParser()
        ..addFlag('json',
            negatable: false, help: 'Output machine-readable JSON')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'audit',
      ArgParser()
        ..addFlag('json',
            negatable: false, help: 'Output machine-readable JSON')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'deps',
      ArgParser()
        ..addFlag('all',
            abbr: 'a',
            negatable: false,
            help: 'Compare dependencies for all registry components')
        ..addFlag('json',
            negatable: false, help: 'Output machine-readable JSON')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'docs',
      ArgParser()
        ..addFlag('generate',
            abbr: 'g',
            negatable: false,
            help: 'Regenerate /doc/site documentation')
        ..addFlag('help', abbr: 'h', negatable: false),
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
      'registries',
      ArgParser()
        ..addFlag(
          'json',
          negatable: false,
          help: 'Output machine-readable JSON',
        )
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'default',
      ArgParser()..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'list',
      ArgParser()
        ..addFlag('refresh', negatable: false, help: 'Refresh cache')
        ..addFlag('json',
            negatable: false, help: 'Output machine-readable JSON')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'search',
      ArgParser()
        ..addFlag('refresh', negatable: false, help: 'Refresh cache')
        ..addFlag('json',
            negatable: false, help: 'Output machine-readable JSON')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'info',
      ArgParser()
        ..addFlag('refresh', negatable: false, help: 'Refresh cache')
        ..addFlag('json',
            negatable: false, help: 'Output machine-readable JSON')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'install-skill',
      ArgParser()
        ..addOption('skill', abbr: 's', help: 'Skill id to install')
        ..addOption('model', abbr: 'm', help: 'Model name (e.g., gpt-4)')
        ..addOption('skills-url', help: 'Override skills base URL/path')
        ..addFlag('symlink',
            negatable: false, help: 'Symlink shared skill to model')
        ..addFlag('list', negatable: false, help: 'List installed skills')
        ..addFlag('available',
            abbr: 'a',
            negatable: false,
            help: 'List available skills from registry')
        ..addFlag('interactive',
            abbr: 'i',
            negatable: false,
            help: 'Interactive multi-skill installation')
        ..addOption('uninstall',
            help: 'Uninstall skill (specify --model for single removal)')
        ..addFlag('uninstall-interactive',
            negatable: false,
            help: 'Interactive removal (choose skills and models)')
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
        ..addFlag('force',
            abbr: 'f',
            negatable: false,
            help: 'Force upgrade even if already latest')
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'feedback',
      ArgParser()
        ..addFlag('help', abbr: 'h', negatable: false)
        ..addOption('type',
            abbr: 't',
            help:
                'Feedback type: bug, feature, docs, question, performance, other')
        ..addOption('title', help: 'Issue title')
        ..addOption('body', help: 'Issue description/body'),
    );

  final normalizedArgs = _normalizeArgs(arguments);
  ArgResults argResults;
  try {
    argResults = parser.parse(normalizedArgs);
  } catch (e) {
    print('Error: $e');
    exit(ExitCodes.usage);
  }

  if (argResults['help'] == true) {
    _printUsage();
    exit(0);
  }

  if (argResults.command == null) {
    _printUsage();
    exit(ExitCodes.usage);
  }

  final targetDir = Directory.current.path;
  final roots = await _resolveRoots();
  final verbose = argResults['verbose'] == true;
  final offline = argResults['offline'] == true;
  final logger = CliLogger(verbose: verbose);
  var config = await ShadcnConfig.load(targetDir);
  final registriesUrl = (argResults['registries-url'] as String?)?.trim();
  final registriesPath = (argResults['registries-path'] as String?)?.trim();
  if ((registriesUrl?.isNotEmpty ?? false) &&
      (registriesPath?.isNotEmpty ?? false)) {
    stderr.writeln(
      'Error: Use only one of --registries-url or --registries-path.',
    );
    exit(ExitCodes.usage);
  }
  final multiRegistry = MultiRegistryManager(
    targetDir: targetDir,
    offline: offline,
    logger: logger,
    directoryUrl: registriesUrl?.isNotEmpty == true
        ? registriesUrl!
        : defaultRegistriesDirectoryUrl,
    directoryPath: registriesPath?.isNotEmpty == true ? registriesPath : null,
  );
  try {
    // Auto-check for updates (rate-limited to once per 24 hours)
    // Skip for version and upgrade commands to avoid recursion
    final shouldCheckUpdates = config.checkUpdates ?? true;
    final commandName = argResults.command?.name;
    if (shouldCheckUpdates &&
        !offline &&
        commandName != 'version' &&
        commandName != 'upgrade') {
      final versionMgr = VersionManager(logger: logger);
      // Run in background without blocking
      unawaited(versionMgr.autoCheckForUpdates());
    }

    var routeInitToMultiRegistry = false;
    var routeAddToMultiRegistry = false;
    final activeCommand = argResults.command;
    if (activeCommand != null && activeCommand.name == 'init') {
      final initRest = activeCommand.rest;
      final initAll = activeCommand['all'] == true;
      if (!initAll && initRest.length == 1) {
        try {
          final namespaceCandidate = _parseInitNamespaceToken(initRest.first);
          routeInitToMultiRegistry =
              await multiRegistry.canHandleNamespaceInit(namespaceCandidate);
        } catch (_) {
          routeInitToMultiRegistry = false;
        }
      }
    }
    if (activeCommand != null && activeCommand.name == 'add') {
      final addRest = activeCommand.rest;
      final addAll = activeCommand['all'] == true || addRest.contains('all');
      if (!addAll && addRest.isNotEmpty) {
        final hasConfiguredMap = _hasConfiguredRegistryMap(config);
        final enabledCount =
            (config.registries ?? const <String, RegistryConfigEntry>{})
                .entries
                .where((entry) => entry.value.enabled)
                .length;
        routeAddToMultiRegistry = enabledCount > 1 || hasConfiguredMap;
      }
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
        exit(ExitCodes.registryNotFound);
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

    if (argResults.command!.name == 'docs') {
      final docsCommand = argResults.command!;
      if (docsCommand['help'] == true) {
        print('Usage: flutter_shadcn docs [--generate]');
        print('');
        print('Regenerate /doc/site documentation from sources.');
        print('Options:');
        print('  --generate, -g  Regenerate documentation (default)');
        return;
      }
      final cliRoot = roots.cliRoot ?? await _packageRoot();
      if (cliRoot == null) {
        stderr.writeln('Error: Unable to resolve CLI root.');
        exit(ExitCodes.ioError);
      }
      await generateDocsSite(cliRoot: cliRoot, logger: logger);
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
      'validate',
      'audit',
      'deps',
    };
    String? commandNamespaceOverride;
    if (argResults.command?.name == 'remove') {
      final removeRest = argResults.command!.rest;
      final removeAll =
          argResults.command!['all'] == true || removeRest.contains('all');
      if (!removeAll && removeRest.isNotEmpty) {
        final namespaces = <String>{};
        for (final token in removeRest) {
          final parsed = MultiRegistryManager.parseComponentRef(token);
          if (parsed != null) {
            namespaces.add(parsed.namespace);
          }
        }
        if (namespaces.length == 1) {
          commandNamespaceOverride = namespaces.first;
        }
      }
    } else if (const {'theme', 'sync', 'validate', 'audit', 'deps'}
        .contains(argResults.command?.name)) {
      final rest = argResults.command?.rest ?? const <String>[];
      if (rest.isNotEmpty &&
          rest.first.startsWith('@') &&
          !rest.first.contains('/')) {
        commandNamespaceOverride = rest.first.substring(1).trim();
      }
    }
    Registry? registry;
    RegistrySelection? preloadedSelection;
    if (needsRegistry.contains(argResults.command!.name) &&
        !(argResults.command!.name == 'init' && routeInitToMultiRegistry) &&
        !(argResults.command!.name == 'add' && routeAddToMultiRegistry)) {
      final selection = _resolveRegistrySelection(
        argResults,
        roots,
        config,
        offline,
        namespaceOverride: commandNamespaceOverride,
      );
      preloadedSelection = selection;
      final cachePath = _componentsJsonCachePath(selection.registryRoot);
      try {
        registry = await Registry.load(
          registryRoot: selection.registryRoot,
          sourceRoot: selection.sourceRoot,
          schemaPath: selection.schemaPath,
          componentsPath: selection.componentsPath,
          cachePath: cachePath,
          offline: offline,
          logger: logger,
        );
      } catch (e) {
        stderr.writeln('Error loading registry: $e');
        stderr.writeln('Registry root: ${selection.registryRoot.root}');
        final message = e.toString();
        if (message.contains('Offline mode')) {
          exit(ExitCodes.offlineUnavailable);
        }
        if (message.contains('Failed to fetch')) {
          exit(ExitCodes.networkError);
        }
        exit(ExitCodes.registryNotFound);
      }
    }

    final installer = registry == null
        ? null
        : Installer(
            registry: registry,
            targetDir: targetDir,
            logger: logger,
            registryNamespace: preloadedSelection?.namespace,
          );

    switch (argResults.command!.name) {
      case 'registries':
        final registriesCommand = argResults.command!;
        if (registriesCommand['help'] == true) {
          print('Usage: flutter_shadcn registries [--json]');
          print('');
          print('Lists configured and discoverable registries.');
          print('Options:');
          print('  --json             Output machine-readable JSON');
          print('  --help, -h         Show this message');
          exit(0);
        }
        final summaries = await multiRegistry.listRegistries();
        if (registriesCommand['json'] == true) {
          final payload = jsonEnvelope(
            command: 'registries',
            data: {
              'defaultNamespace': config.effectiveDefaultNamespace,
              'items': summaries.map((s) => s.toJson()).toList(),
            },
          );
          printJson(payload);
          break;
        }
        if (summaries.isEmpty) {
          print('No registries configured.');
          break;
        }
        print('Registries:');
        for (final summary in summaries) {
          final defaultMarker = summary.isDefault ? ' (default)' : '';
          final enabled = summary.enabled ? 'enabled' : 'disabled';
          print('  ${summary.namespace}$defaultMarker');
          print('    source: ${summary.source}');
          print('    status: $enabled');
          if (summary.mode != null) {
            print('    mode: ${summary.mode}');
          }
          if (summary.baseUrl != null && summary.baseUrl!.isNotEmpty) {
            print('    baseUrl: ${summary.baseUrl}');
          }
          if (summary.registryPath != null &&
              summary.registryPath!.isNotEmpty) {
            print('    path: ${summary.registryPath}');
          }
        }
        break;
      case 'default':
        final defaultCommand = argResults.command!;
        if (defaultCommand['help'] == true) {
          print('Usage: flutter_shadcn default <namespace>');
          print('');
          print('Sets the default registry namespace.');
          exit(0);
        }
        if (defaultCommand.rest.isEmpty) {
          print(
              'Current default registry: ${config.effectiveDefaultNamespace}');
          break;
        }
        final namespace = defaultCommand.rest.first.trim();
        try {
          config = await multiRegistry.setDefaultRegistry(namespace);
        } catch (e) {
          stderr.writeln('Error: $e');
          exit(ExitCodes.configInvalid);
        }
        print('Default registry set to: ${config.effectiveDefaultNamespace}');
        break;
      case 'init':
        final initCommand = argResults.command!;
        if (routeInitToMultiRegistry) {
          if (initCommand['help'] == true) {
            print('Usage: flutter_shadcn init <namespace>');
            print('       flutter_shadcn init [options]');
            print('');
            print('Runs inline bootstrap actions for the selected namespace.');
            exit(0);
          }
          final namespace = _parseInitNamespaceToken(initCommand.rest.first);
          try {
            await multiRegistry.runNamespaceInit(namespace);
          } catch (e) {
            stderr.writeln('Error: $e');
            exit(ExitCodes.configInvalid);
          }
          break;
        }
        final activeInstaller = installer;
        if (activeInstaller == null) {
          stderr.writeln('Error: Installer is not available.');
          exit(ExitCodes.registryNotFound);
        }
        if (initCommand['help'] == true) {
          print('Usage: flutter_shadcn init [options]');
          print('');
          print('Options:');
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
        final aliasOverrides =
            initCommand.wasParsed('alias') && aliases.isNotEmpty
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
          exit(ExitCodes.registryNotFound);
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
            stderr.writeln(
                'Error: --apply-file/--apply-url require --experimental.');
            exit(ExitCodes.usage);
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
        final rest = [...themeCommand.rest];
        if (rest.isNotEmpty &&
            rest.first.startsWith('@') &&
            !rest.first.contains('/')) {
          rest.removeAt(0);
        }
        final presetArg = applyOption ?? (rest.isEmpty ? null : rest.first);
        if (presetArg != null) {
          await activeInstaller.applyThemeById(presetArg);
          break;
        }
        await activeInstaller.chooseTheme();
        break;
      case 'add':
        final addCommand = argResults.command!;
        final includeFileKinds = _parseFileKindOptions(
          addCommand['include-files'] as List,
          optionName: 'include-files',
        );
        final excludeFileKinds = _parseFileKindOptions(
          addCommand['exclude-files'] as List,
          optionName: 'exclude-files',
        );
        if (includeFileKinds.isNotEmpty && excludeFileKinds.isNotEmpty) {
          stderr.writeln(
            'Error: --include-files and --exclude-files cannot be used together.',
          );
          exit(ExitCodes.usage);
        }
        if (routeAddToMultiRegistry) {
          if (addCommand['help'] == true) {
            print(
                'Usage: flutter_shadcn add <@namespace/component> [<@namespace/component> ...]');
            print(
                '       flutter_shadcn add <component> [<component> ...]  # resolves using default/enabled registries');
            print('Options:');
            print(
                '  --include-files   Optional kinds to include: readme, preview, meta');
            print(
                '  --exclude-files   Optional kinds to exclude: readme, preview, meta');
            print('  --help, -h         Show this message');
            exit(0);
          }
          final rest = addCommand.rest;
          if (rest.isEmpty) {
            print('Usage: flutter_shadcn add <component>');
            print('       flutter_shadcn add @namespace/component');
            exit(ExitCodes.usage);
          }
          try {
            await multiRegistry.runAdd(
              rest,
              includeFileKinds: includeFileKinds,
              excludeFileKinds: excludeFileKinds,
            );
          } catch (e) {
            stderr.writeln('Error: $e');
            if ('$e'.contains('ambiguous')) {
              exit(ExitCodes.usage);
            }
            exit(ExitCodes.componentMissing);
          }
          break;
        }
        final activeInstaller = installer;
        if (activeInstaller == null) {
          stderr.writeln('Error: Installer is not available.');
          exit(ExitCodes.registryNotFound);
        }
        if (addCommand['help'] == true) {
          print('Usage: flutter_shadcn add <component> [<component> ...]');
          print('       flutter_shadcn add @namespace/component');
          print('       flutter_shadcn add --all');
          print('Options:');
          print('  --all, -a          Install every available component');
          print(
              '  --include-files   Optional kinds to include: readme, preview, meta');
          print(
              '  --exclude-files   Optional kinds to exclude: readme, preview, meta');
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
          exit(ExitCodes.usage);
        }
        final normalizedRest = <String>[];
        for (final token in rest) {
          final parsed = MultiRegistryManager.parseComponentRef(token);
          if (parsed == null) {
            normalizedRest.add(token);
            continue;
          }
          if (_isLegacyNamespaceAliasAllowed(parsed.namespace, config)) {
            normalizedRest.add(parsed.componentId);
            continue;
          }
          stderr.writeln(
            'Error: Namespace "${parsed.namespace}" requires configured multi-registry sources.',
          );
          exit(ExitCodes.configInvalid);
        }
        final commandInstaller = Installer(
          registry: activeInstaller.registry,
          targetDir: targetDir,
          logger: logger,
          registryNamespace: preloadedSelection?.namespace,
          includeFileKindsOverride: includeFileKinds,
          excludeFileKindsOverride: excludeFileKinds,
        );
        await commandInstaller.ensureInitFiles(allowPrompts: false);
        await commandInstaller.runBulkInstall(() async {
          for (final componentName in normalizedRest) {
            await commandInstaller.addComponent(componentName);
          }
        });
        break;
      case 'dry-run':
        final dryRunCommand = argResults.command!;
        final activeInstaller = installer;
        if (activeInstaller == null) {
          stderr.writeln('Error: Installer is not available.');
          exit(ExitCodes.registryNotFound);
        }
        if (dryRunCommand['help'] == true) {
          print(
              'Usage: flutter_shadcn dry-run <component> [<component> ...] [--json]');
          print('       flutter_shadcn dry-run --all [--json]');
          print('');
          print(
              'Shows what would be installed (dependencies, shared modules, assets, fonts).');
          print('Options:');
          print('  --all, -a          Include every available component');
          print('  --json             Output machine-readable JSON');
          print('  --help, -h         Show this message');
          exit(0);
        }
        final rest = dryRunCommand.rest;
        final dryRunAll = dryRunCommand['all'] == true || rest.contains('all');
        final componentIds = <String>[];
        if (dryRunAll) {
          componentIds.add('icon_fonts');
          componentIds.add('typography_fonts');
          componentIds
              .addAll(activeInstaller.registry.components.map((c) => c.id));
        } else {
          if (rest.isEmpty) {
            print(
                'Usage: flutter_shadcn dry-run <component> [<component> ...]');
            print('       flutter_shadcn dry-run --all');
            exit(ExitCodes.usage);
          }
          componentIds.addAll(rest);
        }
        final plan = await activeInstaller.buildDryRunPlan(componentIds);
        final hasMissing = plan.missing.isNotEmpty;
        final dryRunExitCode =
            hasMissing ? ExitCodes.componentMissing : ExitCodes.success;
        if (dryRunCommand['json'] == true) {
          final warnings = <Map<String, dynamic>>[];
          if (hasMissing) {
            warnings.add(jsonWarning(
              code: ExitCodeLabels.componentMissing,
              message: 'One or more components were not found.',
              details: {'missing': plan.missing},
            ));
          }
          final payload = jsonEnvelope(
            command: 'dry-run',
            data: plan.toJson(),
            warnings: warnings,
            meta: {
              'exitCode': dryRunExitCode,
            },
          );
          printJson(payload);
        } else {
          activeInstaller.printDryRunPlan(plan);
        }
        if (dryRunExitCode != ExitCodes.success) {
          exitCode = dryRunExitCode;
        }
        break;
      case 'remove':
        final removeCommand = argResults.command!;
        final activeInstaller = installer;
        if (activeInstaller == null) {
          stderr.writeln('Error: Installer is not available.');
          exit(ExitCodes.registryNotFound);
        }
        if (removeCommand['help'] == true) {
          print('Usage: flutter_shadcn remove <component> [<component> ...]');
          print('       flutter_shadcn remove --all');
          print('Options:');
          print('  --all, -a          Remove every installed component');
          print(
              '  --force, -f        Force removal even if dependencies remain');
          print('  --help, -h         Show this message');
          exit(0);
        }
        final rest = removeCommand.rest;
        final removeAll = removeCommand['all'] == true || rest.contains('all');
        if (removeAll) {
          final namespace = preloadedSelection?.namespace ??
              _selectedNamespaceForCommand(argResults, config);
          await multiRegistry.rollbackInlineAssets(
            namespace: namespace,
            removeIcons: true,
            removeTypography: true,
            removeAll: true,
          );
          await activeInstaller.removeAllComponents(force: true);
          break;
        }
        if (rest.isEmpty) {
          print('Usage: flutter_shadcn remove <component>');
          exit(ExitCodes.usage);
        }
        final force = removeCommand['force'] == true;
        final selectedNamespace = preloadedSelection?.namespace ??
            _selectedNamespaceForCommand(argResults, config);
        var currentNamespace = selectedNamespace;
        final normalized = <String>[];
        var inlineRollbackApplied = false;
        for (final token in rest) {
          if (token.startsWith('@') && !token.contains('/')) {
            final inlineNs = token.substring(1).trim();
            if (inlineNs.isNotEmpty) {
              currentNamespace = inlineNs;
              continue;
            }
          }
          final parsed = MultiRegistryManager.parseComponentRef(token);
          final componentName = parsed?.componentId ?? token;
          final namespace = parsed?.namespace ?? currentNamespace;
          if (parsed != null &&
              namespace != selectedNamespace &&
              !_isLegacyNamespaceAliasAllowed(parsed.namespace, config)) {
            stderr.writeln(
              'Error: remove with @namespace/component requires --registry-name for that namespace.',
            );
            exit(ExitCodes.configInvalid);
          }
          if (componentName == 'icon_fonts' ||
              componentName == 'typography_fonts') {
            final rolledBack = await multiRegistry.rollbackInlineAssets(
              namespace: namespace,
              removeIcons: componentName == 'icon_fonts',
              removeTypography: componentName == 'typography_fonts',
              removeAll: false,
            );
            if (rolledBack) {
              inlineRollbackApplied = true;
              continue;
            }
          }
          normalized.add(componentName);
        }
        if (normalized.isEmpty && inlineRollbackApplied) {
          logger.success('Removed inline-managed asset actions.');
          break;
        }
        for (final componentName in normalized) {
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
          print('');
          print('Options:');
          print('  --json             Output machine-readable JSON');
          exit(0);
        }
        break;
      case 'validate':
        final validateCommand = argResults.command!;
        if (validateCommand['help'] == true) {
          print('Usage: flutter_shadcn validate [--json]');
          print('');
          print('Validates components.json and registry file dependencies.');
          print('Options:');
          print('  --json             Output machine-readable JSON');
          exit(0);
        }
        if (registry == null) {
          stderr.writeln('Error: Registry is not available.');
          exit(ExitCodes.registryNotFound);
        }
        final validateExit = await runValidateCommand(
          registry: registry,
          registryRoot: registry.registryRoot,
          sourceRoot: registry.sourceRoot,
          offline: offline,
          jsonOutput: validateCommand['json'] == true,
          logger: logger,
        );
        if (validateExit != ExitCodes.success) {
          exitCode = validateExit;
        }
        break;
      case 'audit':
        final auditCommand = argResults.command!;
        if (auditCommand['help'] == true) {
          print('Usage: flutter_shadcn audit [--json]');
          print('');
          print('Audits installed components against registry metadata.');
          print('Options:');
          print('  --json             Output machine-readable JSON');
          exit(0);
        }
        if (registry == null) {
          stderr.writeln('Error: Registry is not available.');
          exit(ExitCodes.registryNotFound);
        }
        final auditExit = await runAuditCommand(
          registry: registry,
          targetDir: targetDir,
          config: config,
          jsonOutput: auditCommand['json'] == true,
          logger: logger,
        );
        if (auditExit != ExitCodes.success) {
          exitCode = auditExit;
        }
        break;
      case 'deps':
        final depsCommand = argResults.command!;
        if (depsCommand['help'] == true) {
          print('Usage: flutter_shadcn deps [--all] [--json]');
          print('');
          print('Compares registry dependency versions to pubspec.yaml.');
          print('Options:');
          print('  --all, -a          Compare all registry components');
          print('  --json             Output machine-readable JSON');
          exit(0);
        }
        if (registry == null) {
          stderr.writeln('Error: Registry is not available.');
          exit(ExitCodes.registryNotFound);
        }
        final depsExit = await runDepsCommand(
          registry: registry,
          targetDir: targetDir,
          config: config,
          includeAll: depsCommand['all'] == true,
          jsonOutput: depsCommand['json'] == true,
          logger: logger,
        );
        if (depsExit != ExitCodes.success) {
          exitCode = depsExit;
        }
        break;
      case 'assets':
        final assetsCommand = argResults.command!;
        final activeInstaller = installer;
        if (activeInstaller == null) {
          stderr.writeln('Error: Installer is not available.');
          exit(ExitCodes.registryNotFound);
        }
        if (assetsCommand['help'] == true) {
          print('Usage: flutter_shadcn assets [options]');
          print('');
          print('Options:');
          print(
              '  --icons          Install icon font assets (Lucide/Radix/Bootstrap)');
          print(
              '  --typography     Install typography fonts (GeistSans/GeistMono)');
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
        final installTypography = assetsCommand['typography'] == true ||
            assetsCommand['fonts'] == true;
        if (!installAll && !installIcons && !installTypography) {
          print('Nothing selected. Use --icons, --typography, or --all.');
          exit(ExitCodes.usage);
        }

        final inlineHandled = await multiRegistry.runInlineAssets(
          namespace: _selectedNamespaceForCommand(argResults, config),
          installIcons: installIcons,
          installTypography: installTypography,
          installAll: installAll,
        );
        if (inlineHandled) {
          logger.success('Installed assets via inline registry actions.');
          break;
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
          print(
              'Usage: flutter_shadcn platform [--list | --set <p.s=path> | --reset <p.s>]');
          print('');
          print('Options:');
          print('  --list             List platform targets');
          print(
              '  --set              Set override (repeatable), e.g. ios.infoPlist=ios/Runner/Info.plist');
          print(
              '  --reset            Remove override (repeatable), e.g. ios.infoPlist');
          print('  --help, -h         Show this message');
          exit(0);
        }
        final sets = (platformCommand['set'] as List).cast<String>();
        final resets = (platformCommand['reset'] as List).cast<String>();
        final list = platformCommand['list'] == true;
        if (sets.isEmpty && resets.isEmpty && !list) {
          print('Nothing selected. Use --list, --set, or --reset.');
          exit(ExitCodes.usage);
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
          exit(ExitCodes.registryNotFound);
        }
        if (syncCommand['help'] == true) {
          print('Usage: flutter_shadcn sync');
          print('');
          print(
              'Re-applies .shadcn/config.json (paths, theme) to existing files.');
          exit(0);
        }
        await activeInstaller.syncFromConfig();
        break;
      case 'list':
        final listCommand = argResults.command!;
        if (listCommand['help'] == true) {
          print('Usage: flutter_shadcn list [--refresh] [--json]');
          print('       flutter_shadcn list @<namespace> [--refresh] [--json]');
          print('');
          print('Lists all available components from the registry.');
          print('Options:');
          print('  --refresh  Refresh cache from remote');
          print('  --json     Output machine-readable JSON');
          exit(0);
        }
        String? listNamespaceOverride;
        final listTokens = [...listCommand.rest];
        if (listTokens.isNotEmpty &&
            listTokens.first.startsWith('@') &&
            !listTokens.first.contains('/')) {
          listNamespaceOverride = listTokens.removeAt(0).substring(1).trim();
          if (listNamespaceOverride.isEmpty) {
            stderr.writeln('Error: Invalid namespace token for list.');
            exit(ExitCodes.usage);
          }
        }
        if (listTokens.isNotEmpty) {
          stderr.writeln('Error: list does not accept positional query text.');
          stderr.writeln('Use: flutter_shadcn search [@namespace] <query>');
          exit(ExitCodes.usage);
        }
        final selection = _resolveRegistrySelection(
          argResults,
          roots,
          config,
          offline,
          namespaceOverride: listNamespaceOverride,
        );
        final registryUrl = selection.registryRoot.root;
        final listExit = await handleListCommand(
          registryBaseUrl: registryUrl,
          registryId: _sanitizeCacheKey(registryUrl),
          refresh: listCommand['refresh'] == true,
          offline: offline,
          jsonOutput: listCommand['json'] == true,
          logger: logger,
        );
        if (listExit != ExitCodes.success) {
          exitCode = listExit;
        }
        break;
      case 'search':
        final searchCommand = argResults.command!;
        if (searchCommand['help'] == true) {
          print('Usage: flutter_shadcn search <query> [--refresh] [--json]');
          print(
              '       flutter_shadcn search @<namespace> [query] [--refresh] [--json]');
          print('');
          print('Searches for components by name, description, or tags.');
          print('Options:');
          print('  --refresh  Refresh cache from remote');
          print('  --json     Output machine-readable JSON');
          exit(0);
        }
        String? searchNamespaceOverride;
        final searchTokens = [...searchCommand.rest];
        if (searchTokens.isNotEmpty &&
            searchTokens.first.startsWith('@') &&
            !searchTokens.first.contains('/')) {
          searchNamespaceOverride =
              searchTokens.removeAt(0).substring(1).trim();
          if (searchNamespaceOverride.isEmpty) {
            stderr.writeln('Error: Invalid namespace token for search.');
            exit(ExitCodes.usage);
          }
        }
        final searchQuery = searchTokens.join(' ');
        final selection = _resolveRegistrySelection(
          argResults,
          roots,
          config,
          offline,
          namespaceOverride: searchNamespaceOverride,
        );
        final registryUrl = selection.registryRoot.root;
        if (searchQuery.isEmpty) {
          final listExit = await handleListCommand(
            registryBaseUrl: registryUrl,
            registryId: _sanitizeCacheKey(registryUrl),
            refresh: searchCommand['refresh'] == true,
            offline: offline,
            jsonOutput: searchCommand['json'] == true,
            logger: logger,
          );
          if (listExit != ExitCodes.success) {
            exitCode = listExit;
          }
          break;
        }
        final searchExit = await handleSearchCommand(
          query: searchQuery,
          registryBaseUrl: registryUrl,
          registryId: _sanitizeCacheKey(registryUrl),
          refresh: searchCommand['refresh'] == true,
          offline: offline,
          jsonOutput: searchCommand['json'] == true,
          logger: logger,
        );
        if (searchExit != ExitCodes.success) {
          exitCode = searchExit;
        }
        break;
      case 'info':
        final infoCommand = argResults.command!;
        if (infoCommand['help'] == true) {
          print(
              'Usage: flutter_shadcn info <component-id|@namespace/component> [--refresh] [--json]');
          print('');
          print('Shows detailed information about a component.');
          print('Options:');
          print('  --refresh  Refresh cache from remote');
          print('  --json     Output machine-readable JSON');
          exit(0);
        }
        final componentToken =
            infoCommand.rest.isNotEmpty ? infoCommand.rest.first : '';
        if (componentToken.isEmpty) {
          print('Usage: flutter_shadcn info <component-id>');
          exit(ExitCodes.usage);
        }
        String componentId = componentToken;
        String? namespaceOverride;
        final qualified =
            MultiRegistryManager.parseComponentRef(componentToken);
        if (qualified != null) {
          namespaceOverride = qualified.namespace;
          componentId = qualified.componentId;
        }
        final selection = _resolveRegistrySelection(
          argResults,
          roots,
          config,
          offline,
          namespaceOverride: namespaceOverride,
        );
        final registryUrl = selection.registryRoot.root;
        final infoExit = await handleInfoCommand(
          componentId: componentId,
          registryBaseUrl: registryUrl,
          registryId: _sanitizeCacheKey(registryUrl),
          refresh: infoCommand['refresh'] == true,
          offline: offline,
          jsonOutput: infoCommand['json'] == true,
          logger: logger,
        );
        if (infoExit != ExitCodes.success) {
          exitCode = infoExit;
        }
        break;
      case 'install-skill':
        final skillCommand = argResults.command!;
        if (skillCommand['help'] == true) {
          print(
              'Usage: flutter_shadcn install-skill [--skill <id>] [--model <name>] [options]');
          print('');
          print(
              '\x1B[33m⚠️  EXPERIMENTAL - This command has not been fully tested yet. Use with caution.\x1B[0m');
          print('');
          print('Manages AI skills for model-specific installations.');
          print(
              'Discovers hidden AI model folders (.claude, .gpt4, .cursor, etc.) in project root.');
          print('');
          print('Modes:');
          print(
              '  (no args)              Multi-skill interactive mode (default)');
          print(
              '  --available, -a        List all available skills from skills.json registry');
          print(
              '  --list                 List all installed skills grouped by model');
          print(
              '  --skill <id>           Install single skill (opens interactive model menu if no --model)');
          print(
              '  --skill <id> --model   Install skill to specific model folder');
          print(
              '  --skills-url           Override skills base URL/path (defaults to registry URL)');
          print(
              '  --symlink --model      Create symlinks from source model to other models');
          print(
              '  --uninstall <id>       Remove skill from specific model (requires --model)');
          print(
              '  --uninstall-interactive Remove skills (interactive: choose skills and models)');
          print('');
          print('Default Interactive Installation Flow:');
          print('  1. Shows all available skills from skills.json');
          print(
              '  2. Select which skills to install (comma-separated or "all")');
          print(
              '  3. Discovers all .{model}/ folders (shown with readable names)');
          print('  4. Select target models (numbered menu or "all")');
          print('  5. Choose mode for multiple selections:');
          print('     - Copy skill to each model folder');
          print('     - Install to one model, symlink to others');
          print('  6. Creates skill folder structure in selected models');
          print('');
          print('Interactive Uninstall Flow (--uninstall-interactive):');
          print('  1. Shows all installed skills');
          print('  2. Select which skills to remove');
          print('  3. Select which models to remove from');
          print('  4. Confirm removal before proceeding');
          print('');
          print('Examples:');
          print(
              '  flutter_shadcn install-skill                    # Default: multi-skill interactive');
          print(
              '  flutter_shadcn install-skill --available        # List available skills from registry');
          print(
              '  flutter_shadcn install-skill --skill my-skill   # Install single skill, pick models');
          print(
              '  flutter_shadcn install-skill --list             # Show installed skills by model');
          print(
              '  flutter_shadcn install-skill --uninstall-interactive  # Remove skills (interactive menu)');
          print(
              '  flutter_shadcn install-skill --uninstall flutter-shadcn-ui --model .claude  # Remove from one model');
          exit(0);
        }

        // Resolve skills base path (project root for discovering model folders)
        final selection =
            _resolveRegistrySelection(argResults, roots, config, offline);
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
        } else if (skillCommand['uninstall-interactive'] == true) {
          await skillMgr.uninstallSkillsInteractive();
        } else if (skillCommand.wasParsed('uninstall')) {
          final skillId = skillCommand['uninstall'] as String;
          final model = skillCommand.wasParsed('model')
              ? skillCommand['model'] as String?
              : null;
          if (model == null) {
            logger.error(
                '--uninstall requires --model, or use --uninstall-interactive for menu');
            exit(ExitCodes.usage);
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
            exit(ExitCodes.usage);
          }
          // Ask for destination models
          final allModels = skillMgr.discoverModelFolders();
          final available = allModels.where((m) => m != targetModel).toList();
          if (available.isEmpty) {
            logger.error('No other models available to symlink to.');
            exit(ExitCodes.usage);
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
          print(
              'Upgrades flutter_shadcn_cli to the latest version from pub.dev.');
          print('');
          print('Options:');
          print(
              '  --force, -f  Force upgrade even if already on latest version');
          print('  --help, -h   Show this message');
          exit(0);
        }
        final versionMgr = VersionManager(logger: logger);
        await versionMgr.upgrade(force: upgradeCommand['force'] == true);
        break;
      case 'feedback':
        final feedbackCommand = argResults.command!;
        if (feedbackCommand['help'] == true) {
          print('Usage: flutter_shadcn feedback [options]');
          print('       flutter_shadcn feedback @<namespace> [options]');
          print('');
          print('Submit feedback or report issues via GitHub.');
          print('');
          print('Interactive mode (default):');
          print('  flutter_shadcn feedback');
          print('');
          print('Non-interactive mode:');
          print(
              '  flutter_shadcn feedback --type bug --title "Title" --body "Description"');
          print('');
          print('Feedback types:');
          print('  🐛 bug          Report bugs');
          print('  ✨ feature      Request features');
          print('  📖 docs        Suggest documentation improvements');
          print('  ❓ question     Ask questions');
          print('  ⚡ performance  Report performance issues');
          print('  💡 other        Share general feedback');
          print('');
          print('Options:');
          print(
              '  --type, -t    Feedback type (bug, feature, docs, question, performance, other)');
          print('  --title       Issue title');
          print('  --body        Issue description/body');
          print('  @<namespace>  Optional registry context (e.g. @shadcn)');
          print('  --help, -h    Show this message');
          exit(0);
        }
        String? feedbackNamespaceOverride;
        final feedbackRest = [...feedbackCommand.rest];
        if (feedbackRest.isNotEmpty &&
            feedbackRest.first.startsWith('@') &&
            !feedbackRest.first.contains('/')) {
          feedbackNamespaceOverride =
              feedbackRest.removeAt(0).substring(1).trim();
          if (feedbackNamespaceOverride.isEmpty) {
            stderr.writeln('Error: Invalid namespace token for feedback.');
            exit(ExitCodes.usage);
          }
        }
        if (feedbackRest.isNotEmpty) {
          stderr.writeln('Error: Unrecognized feedback arguments.');
          exit(ExitCodes.usage);
        }
        final feedbackFlagNamespace =
            (argResults['registry-name'] as String?)?.trim();
        final needsFeedbackSelection = feedbackNamespaceOverride != null ||
            (feedbackFlagNamespace != null && feedbackFlagNamespace.isNotEmpty);
        final feedbackSelection = needsFeedbackSelection
            ? _resolveRegistrySelection(
                argResults,
                roots,
                config,
                offline,
                namespaceOverride: feedbackNamespaceOverride,
              )
            : null;
        final feedbackMgr = FeedbackManager(logger: logger);
        await feedbackMgr.showFeedbackMenu(
          type: feedbackCommand['type'] as String?,
          title: feedbackCommand['title'] as String?,
          body: feedbackCommand['body'] as String?,
          registryNamespace: feedbackSelection?.namespace,
          registryBaseUrl: feedbackSelection?.registryRoot.root,
        );
        break;
    }
  } finally {
    multiRegistry.close();
  }
}

List<String> _normalizeArgs(List<String> args) {
  if (args.isEmpty) {
    return args;
  }
  final aliasMap = <String, String>{
    'ls': 'list',
    'rm': 'remove',
    'i': 'info',
  };
  final mapped = aliasMap[args.first];
  if (mapped == null) {
    return args;
  }
  return [mapped, ...args.skip(1)];
}

void _printUsage() {
  print('');
  print('flutter_shadcn CLI');
  print('Usage: flutter_shadcn <command> [arguments]');
  print('');

  _printUsageSection('Project & Registry Setup', const [
    MapEntry('init', 'Initialize shadcn_flutter in the current project'),
    MapEntry('theme', 'Manage registry theme presets'),
    MapEntry('assets', 'Install font/icon assets'),
    MapEntry('platform', 'Configure platform targets'),
    MapEntry('sync', 'Sync changes from .shadcn/config.json'),
    MapEntry('registries', 'List available/configured registries'),
    MapEntry('default', 'Set default registry namespace'),
  ]);

  _printUsageSection('Component Workflow', const [
    MapEntry('add', 'Add a widget'),
    MapEntry('remove (alias: rm)', 'Remove a widget'),
    MapEntry('dry-run', 'Preview what would be installed'),
    MapEntry('list (alias: ls)', 'List available components'),
    MapEntry('search', 'Search for components'),
    MapEntry('info (alias: i)', 'Show component details'),
  ]);

  _printUsageSection('Verification & Diagnostics', const [
    MapEntry('validate', 'Validate registry integrity'),
    MapEntry('audit', 'Audit installed components'),
    MapEntry('deps', 'Compare registry deps vs pubspec'),
    MapEntry('doctor', 'Diagnose registry resolution'),
  ]);

  _printUsageSection('Tooling & Maintenance', const [
    MapEntry('docs', 'Regenerate documentation site'),
    MapEntry('feedback', 'Submit feedback or report issues'),
    MapEntry('version', 'Show CLI version'),
    MapEntry('upgrade', 'Upgrade CLI to latest version'),
    MapEntry('install-skill', 'Install AI skills (🧪 experimental)'),
  ]);

  print('Global flags');
  _printUsageFlagSection('General', const [
    MapEntry('--verbose', 'Verbose logging'),
    MapEntry('--offline', 'Disable network calls (use cache only)'),
    MapEntry('--wip', 'Enable WIP features'),
    MapEntry('--experimental', 'Enable experimental features'),
  ]);

  _printUsageFlagSection('Registry Selection', const [
    MapEntry('--registry', 'auto|local|remote (default: auto)'),
    MapEntry('--registry-name', 'Registry namespace (e.g. shadcn)'),
    MapEntry('--registry-path', 'Path to local registry folder'),
    MapEntry('--registry-url', 'Remote registry base URL'),
    MapEntry('--registries-url', 'Remote registries.json URL'),
    MapEntry('--registries-path', 'Local registries.json file/directory path'),
  ]);

  _printUsageFlagSection('Dev Mode', const [
    MapEntry('--dev', 'Persist local registry for dev mode'),
    MapEntry('--dev-path', 'Local registry path to persist for dev mode'),
  ]);

  print('');
}

void _printUsageSection(String title, List<MapEntry<String, String>> commands) {
  print(title);
  for (final entry in commands) {
    print(_formatUsageRow(entry.key, entry.value));
  }
  print('');
}

void _printUsageFlagSection(
    String title, List<MapEntry<String, String>> flags) {
  print('  $title:');
  for (final entry in flags) {
    print(_formatUsageRow(entry.key, entry.value, indent: '    '));
  }
  print('');
}

String _formatUsageRow(
  String name,
  String description, {
  String indent = '  ',
}) {
  const width = 24;
  final paddedName =
      name.length >= width ? '$name ' : name.padRight(width, ' ');
  return '$indent$paddedName$description';
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
    p.join(
        parent, 'shadcn_flutter_kit', 'flutter_shadcn_kit', 'lib', 'registry'),
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
      p.join(current.path, 'shadcn_flutter_kit', 'flutter_shadcn_kit', 'lib',
          'registry'),
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
  final offline = args['offline'] == true;
  final jsonOutput = args.command?['json'] == true;
  final logger = CliLogger(verbose: args['verbose'] == true);
  final selection = _resolveRegistrySelection(args, roots, config, offline);
  final envRoot = Platform.environment['SHADCN_REGISTRY_ROOT'];
  final envUrl = Platform.environment['SHADCN_REGISTRY_URL'];
  final pubCache = Platform.environment['PUB_CACHE'] ??
      p.join(Platform.environment['HOME'] ?? '', '.pub-cache');
  final cachePath = _componentsJsonCachePath(selection.registryRoot);
  final componentsSource = selection.registryRoot.describe(
    selection.componentsPath,
  );
  Map<String, dynamic>? registryData;
  SchemaSource? schemaSource;
  bool? schemaValid;
  final schemaErrors = <String>[];
  try {
    final content = await _readComponentsJson(selection, offline: offline);
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) {
      registryData = decoded;
      schemaSource = ComponentsSchemaValidator.resolveSchemaSource(
        data: decoded,
        registryRoot: selection.registryRoot,
      );
    }
  } catch (e) {
    final message = e.toString();
    final exit = message.contains('Offline mode')
        ? ExitCodes.offlineUnavailable
        : ExitCodes.networkError;
    if (jsonOutput) {
      final payload = jsonEnvelope(
        command: 'doctor',
        data: {
          'registry': {
            'mode': selection.mode,
            'root': selection.registryRoot.root,
            'componentsJson': componentsSource,
            'cache': cachePath ?? '(local registry, no cache)',
          },
        },
        errors: [
          jsonError(
            code: message.contains('Offline mode')
                ? ExitCodeLabels.offlineUnavailable
                : ExitCodeLabels.networkError,
            message: message,
          ),
        ],
        meta: {
          'exitCode': exit,
        },
      );
      printJson(payload);
      exitCode = exit;
      return;
    }
    logger.error('Failed to load components.json: $message');
    exitCode = exit;
    return;
  }

  if (schemaSource != null && registryData != null) {
    try {
      final result = await ComponentsSchemaValidator.validateWithJsonSchema(
        registryData,
        schemaSource,
      );
      schemaValid = result.isValid;
      schemaErrors.addAll(result.errors);
    } catch (e) {
      schemaValid = false;
      schemaErrors.add('Failed to validate schema: $e');
    }
  }

  final defaults = (registryData?['defaults'] as Map?)
          ?.map((key, value) => MapEntry(key.toString(), value.toString())) ??
      const <String, String>{};
  final installPath =
      config.installPath ?? defaults['installPath'] ?? 'lib/ui/shadcn';
  final sharedPath =
      config.sharedPath ?? defaults['sharedPath'] ?? 'lib/ui/shadcn/shared';
  final aliases = config.pathAliases ?? const <String, String>{};
  final resolvedInstallPath = _expandAliasPath(installPath, aliases);
  final resolvedSharedPath = _expandAliasPath(sharedPath, aliases);
  final installPathOnDisk = _ensureLibPrefix(resolvedInstallPath);
  final sharedPathOnDisk = _ensureLibPrefix(resolvedSharedPath);
  final installPathValid = _isLibPath(resolvedInstallPath);
  final sharedPathValid = _isLibPath(resolvedSharedPath);
  final installPathExists =
      Directory(p.join(Directory.current.path, installPathOnDisk)).existsSync();
  final sharedPathExists =
      Directory(p.join(Directory.current.path, sharedPathOnDisk)).existsSync();
  final colorSchemePath = p.join(
    Directory.current.path,
    sharedPathOnDisk,
    'theme',
    'color_scheme.dart',
  );
  final colorSchemeExists = File(colorSchemePath).existsSync();
  final invalidAliases = <String>[];
  aliases.forEach((name, value) {
    final aliasPath = p.join(Directory.current.path, _ensureLibPrefix(value));
    if (!Directory(aliasPath).existsSync()) {
      invalidAliases.add(name);
    }
  });

  final platformTargets = _mergePlatformTargets(config.platformTargets);

  final hasSchemaIssues = schemaValid == false;
  final hasConfigIssues = !installPathValid ||
      !sharedPathValid ||
      !colorSchemeExists ||
      invalidAliases.isNotEmpty;
  final warnings = <Map<String, dynamic>>[];
  final errors = <Map<String, dynamic>>[];

  if (!installPathExists) {
    warnings.add(jsonWarning(
      code: ExitCodeLabels.configInvalid,
      message: 'Install path does not exist.',
      details: {'path': resolvedInstallPath},
    ));
  }
  if (!sharedPathExists) {
    warnings.add(jsonWarning(
      code: ExitCodeLabels.configInvalid,
      message: 'Shared path does not exist.',
      details: {'path': resolvedSharedPath},
    ));
  }

  if (hasSchemaIssues) {
    errors.add(jsonError(
      code: ExitCodeLabels.schemaInvalid,
      message: 'Schema validation failed.',
      details: {
        'errorCount': schemaErrors.length,
        'errors': schemaErrors,
      },
    ));
  }
  if (!installPathValid) {
    errors.add(jsonError(
      code: ExitCodeLabels.configInvalid,
      message: 'Install path is not under lib/.',
      details: {'path': resolvedInstallPath},
    ));
  }
  if (!sharedPathValid) {
    errors.add(jsonError(
      code: ExitCodeLabels.configInvalid,
      message: 'Shared path is not under lib/.',
      details: {'path': resolvedSharedPath},
    ));
  }
  if (!colorSchemeExists) {
    errors.add(jsonError(
      code: ExitCodeLabels.configInvalid,
      message: 'color_scheme.dart is missing.',
      details: {'path': colorSchemePath},
    ));
  }
  if (invalidAliases.isNotEmpty) {
    errors.add(jsonError(
      code: ExitCodeLabels.configInvalid,
      message: 'One or more path aliases are invalid.',
      details: {'aliases': invalidAliases},
    ));
  }

  var doctorExitCode = ExitCodes.success;
  if (hasSchemaIssues && hasConfigIssues) {
    doctorExitCode = ExitCodes.validationFailed;
  } else if (hasSchemaIssues) {
    doctorExitCode = ExitCodes.schemaInvalid;
  } else if (hasConfigIssues) {
    doctorExitCode = ExitCodes.configInvalid;
  }

  if (jsonOutput) {
    final payload = jsonEnvelope(
      command: 'doctor',
      data: {
        'environment': {
          'script': Platform.script.toFilePath(),
          'cwd': Directory.current.path,
          'pubCache': pubCache,
        },
        'registry': {
          'mode': selection.mode,
          'root': selection.registryRoot.root,
          'componentsJson': componentsSource,
          'cache': cachePath ?? '(local registry, no cache)',
          'schema': schemaSource?.label,
        },
        'configuration': {
          'SHADCN_REGISTRY_ROOT': envRoot,
          'SHADCN_REGISTRY_URL': envUrl,
          'cliRoot': roots.cliRoot,
          'localRegistryRoot': roots.localRegistryRoot,
          'config.registryMode': config.registryMode,
          'config.registryPath': config.registryPath,
          'config.registryUrl': config.registryUrl,
        },
        'paths': {
          'installPath': installPath,
          'sharedPath': sharedPath,
          'resolvedInstallPath': resolvedInstallPath,
          'resolvedSharedPath': resolvedSharedPath,
          'installPathValid': installPathValid,
          'sharedPathValid': sharedPathValid,
          'installPathExists': installPathExists,
          'sharedPathExists': sharedPathExists,
          'colorSchemePath': colorSchemePath,
          'colorSchemeExists': colorSchemeExists,
        },
        'aliases': {
          'configured': aliases,
          'invalid': invalidAliases,
        },
        'schema': {
          'found': schemaSource != null,
          'valid': schemaValid,
          'errorCount': schemaErrors.length,
          'errors': schemaErrors,
        },
        'platformTargets': platformTargets,
      },
      errors: errors,
      warnings: warnings,
      meta: {
        'exitCode': doctorExitCode,
      },
    );
    printJson(payload);
    exitCode = doctorExitCode;
    return;
  }

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
  kv('Schema', schemaSource?.label ?? '(not found)');

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
  logger.section('Config paths');
  kv('installPath', resolvedInstallPath);
  kv('sharedPath', resolvedSharedPath);
  logger.info('  installPath valid: ${installPathValid ? 'yes' : 'no'}');
  logger.info('  sharedPath valid: ${sharedPathValid ? 'yes' : 'no'}');
  logger.info('  installPath exists: ${installPathExists ? 'yes' : 'no'}');
  logger.info('  sharedPath exists: ${sharedPathExists ? 'yes' : 'no'}');
  if (invalidAliases.isNotEmpty) {
    logger.warn('  invalid aliases: ${invalidAliases.join(', ')}');
  }

  print('');
  logger.section('Theme files');
  kv('color_scheme.dart', colorSchemeExists ? colorSchemePath : 'missing');

  print('');
  logger.section('Schema validation');
  if (schemaSource == null || registryData == null) {
    logger.warn('  Schema file not found.');
  } else {
    if (schemaValid == true) {
      logger.success('  components.json matches the schema.');
    } else {
      logger.error('  Schema issues: ${schemaErrors.length}');
      for (final error in schemaErrors.take(12)) {
        logger.info('  - $error');
      }
      if (schemaErrors.length > 12) {
        logger.info('  ...and ${schemaErrors.length - 12} more');
      }
    }
  }

  print('');
  logger.section('Platform targets');
  logger
      .info('  (set .shadcn/config.json "platformTargets" to override paths)');
  platformTargets.forEach((platform, targets) {
    logger.info('  $platform:');
    for (final entry in targets.entries) {
      logger.info('    ${entry.key}: ${entry.value}');
    }
  });

  if (doctorExitCode != ExitCodes.success) {
    exitCode = doctorExitCode;
  }
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

Future<String> _readComponentsJson(
  RegistrySelection selection, {
  required bool offline,
}) async {
  if (offline && selection.registryRoot.isRemote) {
    final cachePath = _componentsJsonCachePath(selection.registryRoot);
    if (cachePath == null) {
      throw Exception('Offline mode: cache path not available.');
    }
    final cacheFile = File(cachePath);
    if (!await cacheFile.exists()) {
      throw Exception('Offline mode: cached components.json not found.');
    }
    return cacheFile.readAsString();
  }
  return selection.registryRoot.readString('components.json');
}

String _sanitizeCacheKey(String value) {
  final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (safe.length > 80) {
    return safe.substring(0, 80);
  }
  return safe;
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
            (entry) =>
                MapEntry(entry.key, Map<String, String>.from(entry.value)),
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
  bool offline, {
  String? namespaceOverride,
}) {
  final selectedNamespace = namespaceOverride ??
      (args?['registry-name'] as String?)?.trim() ??
      (config.hasRegistries ? config.effectiveDefaultNamespace : null);
  final selectedEntry = selectedNamespace == null
      ? null
      : config.registryConfig(selectedNamespace);
  if (selectedNamespace != null &&
      selectedEntry == null &&
      ((args?['registry-name'] as String?)?.trim().isNotEmpty == true ||
          config.hasRegistries)) {
    stderr.writeln('Error: Registry namespace "$selectedNamespace" not found.');
    exit(ExitCodes.configInvalid);
  }

  final mode = (args?['registry'] as String?) ??
      selectedEntry?.registryMode ??
      config.registryMode ??
      'auto';
  final pathOverride = (args?['registry-path'] as String?) ??
      selectedEntry?.registryPath ??
      config.registryPath;
  final urlOverride = (args?['registry-url'] as String?) ??
      selectedEntry?.baseUrl ??
      selectedEntry?.registryUrl ??
      config.registryUrl;
  final componentsPath = selectedEntry?.componentsPath ?? 'components.json';
  final schemaPath = selectedEntry?.componentsSchemaPath;

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
        namespace: selectedNamespace,
        registryRoot: RegistryLocation.local(localRoot, offline: offline),
        sourceRoot: RegistryLocation.local(sourceRoot, offline: offline),
        componentsPath: componentsPath,
        schemaPath: schemaPath,
      );
    }
    if (mode == 'local') {
      stderr.writeln('Error: Local registry not found.');
      stderr.writeln('Set SHADCN_REGISTRY_ROOT or --registry-path.');
      exit(ExitCodes.registryNotFound);
    }
  }

  final remoteBase = _resolveRemoteBase(urlOverride);
  if (selectedEntry != null &&
      (selectedEntry.baseUrl != null || selectedEntry.componentsPath != null)) {
    return RegistrySelection(
      mode: 'remote',
      namespace: selectedNamespace,
      registryRoot: RegistryLocation.remote(remoteBase, offline: offline),
      sourceRoot: RegistryLocation.remote(remoteBase, offline: offline),
      componentsPath: componentsPath,
      schemaPath: schemaPath,
    );
  }
  final remoteRoots = _resolveRemoteRoots(remoteBase);
  return RegistrySelection(
    mode: 'remote',
    namespace: selectedNamespace,
    registryRoot:
        RegistryLocation.remote(remoteRoots.registryRoot, offline: offline),
    sourceRoot:
        RegistryLocation.remote(remoteRoots.sourceRoot, offline: offline),
    componentsPath: componentsPath,
    schemaPath: schemaPath,
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
  final normalized =
      base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  if (normalized.endsWith('/registry')) {
    final sourceRoot =
        normalized.substring(0, normalized.length - '/registry'.length);
    return _RemoteRoots(registryRoot: normalized, sourceRoot: sourceRoot);
  }
  return _RemoteRoots(
    registryRoot: '$normalized/registry',
    sourceRoot: normalized,
  );
}

class RegistrySelection {
  final String mode;
  final String? namespace;
  final RegistryLocation registryRoot;
  final RegistryLocation sourceRoot;
  final String componentsPath;
  final String? schemaPath;

  const RegistrySelection({
    required this.mode,
    required this.namespace,
    required this.registryRoot,
    required this.sourceRoot,
    this.componentsPath = 'components.json',
    this.schemaPath,
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

String _parseInitNamespaceToken(String token) {
  final trimmed = token.trim();
  if (trimmed.startsWith('@') && trimmed.length > 1) {
    return trimmed.substring(1);
  }
  return trimmed;
}

bool _hasConfiguredRegistryMap(ShadcnConfig config) {
  final registries = config.registries;
  if (registries == null || registries.isEmpty) {
    return false;
  }
  for (final entry in registries.values) {
    if ((entry.registryPath?.trim().isNotEmpty ?? false) ||
        (entry.registryUrl?.trim().isNotEmpty ?? false) ||
        (entry.baseUrl?.trim().isNotEmpty ?? false)) {
      return true;
    }
  }
  return false;
}

bool _isLegacyNamespaceAliasAllowed(String namespace, ShadcnConfig config) {
  final trimmed = namespace.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final defaultNamespace = config.effectiveDefaultNamespace;
  return trimmed == defaultNamespace ||
      trimmed == ShadcnConfig.legacyDefaultNamespace;
}

Set<String> _parseFileKindOptions(
  List rawValues, {
  required String optionName,
}) {
  final result = <String>{};
  for (final raw in rawValues) {
    final value = raw.toString();
    final parts = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    for (final part in parts) {
      final normalized = _normalizeFileKindToken(part);
      if (normalized == null) {
        stderr.writeln(
          'Error: --$optionName supports only readme, preview, meta (got "$part").',
        );
        exit(ExitCodes.usage);
      }
      result.add(normalized);
    }
  }
  return result;
}

String? _normalizeFileKindToken(String raw) {
  final token = raw.trim().toLowerCase();
  switch (token) {
    case 'readme':
    case 'docs':
      return 'readme';
    case 'preview':
    case 'previews':
      return 'preview';
    case 'meta':
    case 'metadata':
      return 'meta';
    default:
      return null;
  }
}

String _selectedNamespaceForCommand(ArgResults args, ShadcnConfig config) {
  final fromFlag = (args['registry-name'] as String?)?.trim();
  if (fromFlag != null && fromFlag.isNotEmpty) {
    return fromFlag;
  }
  return config.effectiveDefaultNamespace;
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

String _expandAliasPath(String path, Map<String, String> aliases) {
  if (aliases.isEmpty) {
    return path;
  }
  if (path.startsWith('@')) {
    final index = path.indexOf('/');
    final name = index == -1 ? path.substring(1) : path.substring(1, index);
    final aliasPath = aliases[name];
    if (aliasPath != null) {
      final suffix = index == -1 ? '' : path.substring(index + 1);
      return suffix.isEmpty ? aliasPath : p.join(aliasPath, suffix);
    }
  }
  return path;
}

bool _isLibPath(String path) {
  if (path.startsWith('lib/')) {
    return true;
  }
  if (p.isAbsolute(path)) {
    return false;
  }
  if (path.startsWith('..')) {
    return false;
  }
  return true;
}

String _ensureLibPrefix(String path) {
  if (path.startsWith('lib/')) {
    return path;
  }
  if (p.isAbsolute(path)) {
    return path;
  }
  return p.join('lib', path);
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
