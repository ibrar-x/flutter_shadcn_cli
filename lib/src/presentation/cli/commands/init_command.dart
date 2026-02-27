import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/application/services/installer_orchestrator.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/installer.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_manager.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/arg_helpers.dart';

Future<int> runInitCommand({
  required ArgResults initCommand,
  required bool routeInitToMultiRegistry,
  required MultiRegistryManager multiRegistry,
  required Installer? installer,
  required String defaultNamespace,
}) async {
  if (routeInitToMultiRegistry) {
    if (initCommand['help'] == true) {
      print('Usage: flutter_shadcn init <namespace>');
      print('       flutter_shadcn init [options]');
      print('');
      print('Runs inline bootstrap actions for the selected namespace.');
      return ExitCodes.success;
    }
    final namespace = initCommand.rest.isNotEmpty
        ? _parseInitNamespaceToken(initCommand.rest.first)
        : defaultNamespace;
    try {
      await multiRegistry.runNamespaceInit(namespace);
      return ExitCodes.success;
    } catch (e) {
      stderr.writeln('Error: $e');
      return ExitCodes.configInvalid;
    }
  }

  final activeInstaller = installer;
  if (activeInstaller == null) {
    stderr.writeln('Error: Installer is not available.');
    return ExitCodes.registryNotFound;
  }
  final orchestrator = InstallerOrchestrator(activeInstaller);
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
    print('  --alias            Path alias (name=lib/path), allows @name in paths');
    print('  --help, -h         Show this message');
    return ExitCodes.success;
  }

  final skipPrompts = initCommand['yes'] == true;
  final aliasPairs = (initCommand['alias'] as List).cast<String>();
  final aliases = parseAliasPairs(aliasPairs);
  final installFonts = initCommand['install-fonts'] == true;
  final installIcons = initCommand['install-icons'] == true;
  final includeReadme =
      initCommand.wasParsed('include-readme') ? initCommand['include-readme'] as bool : null;
  final includeMeta =
      initCommand.wasParsed('include-meta') ? initCommand['include-meta'] as bool : null;
  final includePreview =
      initCommand.wasParsed('include-preview') ? initCommand['include-preview'] as bool : null;
  final installPath =
      initCommand.wasParsed('install-path') ? initCommand['install-path'] as String? : null;
  final sharedPath =
      initCommand.wasParsed('shared-path') ? initCommand['shared-path'] as String? : null;
  final classPrefix =
      initCommand.wasParsed('prefix') ? initCommand['prefix'] as String? : null;
  final aliasOverrides = initCommand.wasParsed('alias') && aliases.isNotEmpty ? aliases : null;

  await orchestrator.runInit(
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
    await orchestrator.runBulkInstall(() async {
      if (installIcons) {
        await orchestrator.addComponents(const ['icon_fonts']);
      }
      if (installFonts) {
        await orchestrator.addComponents(const ['typography_fonts']);
      }
    });
  }

  final addAll = initCommand['all'] == true;
  final addList = <String>[...initCommand.rest];
  if (addAll) {
    await orchestrator.runBulkInstall(() async {
      await orchestrator.addComponents(const ['icon_fonts', 'typography_fonts']);
      await orchestrator.installAllComponents();
    });
    return ExitCodes.success;
  }
  if (addList.isNotEmpty) {
    await orchestrator.runBulkInstall(() async {
      await orchestrator.addComponents(addList);
    });
  }
  return ExitCodes.success;
}

String _parseInitNamespaceToken(String token) {
  final trimmed = token.trim();
  if (trimmed.startsWith('@') && trimmed.length > 1) {
    return trimmed.substring(1);
  }
  return trimmed;
}
