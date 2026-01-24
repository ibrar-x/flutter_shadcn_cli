import 'dart:io';
import 'dart:isolate';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_shadcn_cli/src/installer.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';
import 'package:flutter_shadcn_cli/src/config.dart';

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
    _runDoctor(roots, argResults, config);
    return;
  }

  final needsRegistry = const {'init', 'theme', 'add', 'remove', 'sync', 'assets'};
  Registry? registry;
  if (needsRegistry.contains(argResults.command!.name)) {
    final selection = _resolveRegistrySelection(argResults, roots, config);
    try {
      registry = await Registry.load(
        registryRoot: selection.registryRoot,
        sourceRoot: selection.sourceRoot,
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
  }
}

void _printUsage() {
  print('Usage: flutter_shadcn <command> [arguments]');
  print('Commands:');
  print('  init    Initialize shadcn_flutter in the current project');
  print('  theme   Manage registry theme presets');
  print('  add     Add a widget');
  print('  remove  Remove a widget');
  print('  sync    Sync changes from .shadcn/config.json');
  print('  assets  Install font/icon assets');
  print('  doctor  Diagnose registry resolution');
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

void _runDoctor(ResolvedRoots roots, ArgResults args, ShadcnConfig config) {
  final selection = _resolveRegistrySelection(args, roots, config);
  final envRoot = Platform.environment['SHADCN_REGISTRY_ROOT'];
  final envUrl = Platform.environment['SHADCN_REGISTRY_URL'];
  final pubCache = Platform.environment['PUB_CACHE'] ??
      p.join(Platform.environment['HOME'] ?? '', '.pub-cache');
  stdout.writeln('flutter_shadcn doctor');
  stdout.writeln('  script: ${Platform.script.toFilePath()}');
  stdout.writeln('  cwd: ${Directory.current.path}');
  stdout.writeln('  SHADCN_REGISTRY_ROOT: ${envRoot ?? '(unset)'}');
  stdout.writeln('  SHADCN_REGISTRY_URL: ${envUrl ?? '(unset)'}');
  stdout.writeln('  PUB_CACHE: $pubCache');
  stdout.writeln('  cliRoot: ${roots.cliRoot ?? '(unresolved)'}');
  stdout.writeln('  localRegistryRoot: ${roots.localRegistryRoot ?? '(unresolved)'}');
  stdout.writeln('  config.registryMode: ${config.registryMode ?? '(unset)'}');
  stdout.writeln('  config.registryPath: ${config.registryPath ?? '(unset)'}');
  stdout.writeln('  config.registryUrl: ${config.registryUrl ?? '(unset)'}');
  stdout.writeln('  registryMode: ${selection.mode}');
  stdout.writeln('  registryRoot: ${selection.registryRoot.root}');
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
