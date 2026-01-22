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
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand(
      'theme',
      ArgParser()
        ..addFlag('list', negatable: false)
        ..addOption('apply', abbr: 'a')
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
        ..addFlag('force', abbr: 'f', negatable: false)
        ..addFlag('help', abbr: 'h', negatable: false),
    )
    ..addCommand('doctor');

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }

  if (argResults.command == null) {
    print('Usage: flutter_shadcn <command> [arguments]');
    print('Commands:');
    print('  init   Initialize shadcn_flutter in the current project');
    print('  theme  Manage registry theme presets');
    print('  add    Add a component');
    print('  remove  Remove a component');
    print('  doctor  Diagnose registry resolution');
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
    _runDoctor(roots, argResults, config);
    return;
  }

  final needsRegistry = const {'init', 'theme', 'add', 'remove'};
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
      if (initCommand['help'] == true) {
        print('Usage: flutter_shadcn init [options]');
        print('');
        print('Options:');
        print('  --add, -c <name>   Add components after init (repeatable)');
        print('  --all, -a          Add every component after init');
        print('  --help, -h         Show this message');
        exit(0);
      }
      await installer!.init();
      final addAll = initCommand['all'] == true;
      final addList = (initCommand['add'] as List).cast<String>();
      if (addAll) {
        for (final component in registry!.components) {
          await installer!.addComponent(component.id);
        }
        await installer!.generateAliases();
        break;
      }
      if (addList.isNotEmpty) {
        for (final componentName in addList) {
          await installer!.addComponent(componentName);
        }
        await installer!.generateAliases();
      }
      break;
    case 'theme':
      final themeCommand = argResults.command!;
      if (themeCommand['help'] == true) {
        print(
            'Usage: flutter_shadcn theme [--list | --apply <preset>] [--help]');
        print('');
        print('Options:');
        print('  --list             Show all available theme presets');
        print('  --apply, -a <id>   Apply the preset with the given ID');
        print('  --help, -h         Show this message');
        exit(0);
      }
      if (themeCommand['list'] == true) {
        await installer!.listThemes();
        break;
      }
      final applyOption = themeCommand['apply'] as String?;
      final rest = themeCommand.rest;
      final presetArg = applyOption ?? (rest.isEmpty ? null : rest.first);
      if (presetArg != null) {
        await installer!.applyThemeById(presetArg);
        break;
      }
      await installer!.chooseTheme();
      break;
    case 'add':
      final addCommand = argResults.command!;
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
        for (final component in registry!.components) {
          await installer!.addComponent(component.id);
        }
        await installer!.generateAliases();
        break;
      }
      if (rest.isEmpty) {
        print('Usage: flutter_shadcn add <component>');
        print('       flutter_shadcn add --all');
        exit(1);
      }
      for (final componentName in rest) {
        await installer!.addComponent(componentName);
      }
      await installer!.generateAliases();
      break;
    case 'remove':
      final removeCommand = argResults.command!;
      if (removeCommand['help'] == true) {
        print('Usage: flutter_shadcn remove <component> [<component> ...]');
        print('Options:');
        print('  --force, -f        Force removal even if dependencies remain');
        print('  --help, -h         Show this message');
        exit(0);
      }
      final rest = removeCommand.rest;
      if (rest.isEmpty) {
        print('Usage: flutter_shadcn remove <component>');
        exit(1);
      }
      final force = removeCommand['force'] == true;
      for (final componentName in rest) {
        await installer!.removeComponent(componentName, force: force);
      }
      await installer!.generateAliases();
      break;
    case 'doctor':
      break;
  }
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
    final localRoot = _resolveLocalRoot(
      pathOverride,
      roots.localRegistryRoot,
      config.registryPath,
    );
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

const String _defaultRemoteRegistryBase =
  'https://cdn.jsdelivr.net/gh/ibrar-x/shadcn_flutter_kit@latest/flutter_shadcn_kit/lib';
