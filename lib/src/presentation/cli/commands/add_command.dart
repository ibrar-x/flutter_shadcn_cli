import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/application/services/installer_orchestrator.dart';
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/installer.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_manager.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/arg_helpers.dart';

Future<int> runAddCommand({
  required ArgResults addCommand,
  required bool routeAddToMultiRegistry,
  required MultiRegistryManager multiRegistry,
  required Installer? installer,
  required String targetDir,
  required CliLogger logger,
  required ShadcnConfig config,
  required String? preloadedNamespace,
}) async {
  final includeFileKinds = parseFileKindOptions(
    addCommand['include-files'] as List,
    optionName: 'include-files',
  );
  final excludeFileKinds = parseFileKindOptions(
    addCommand['exclude-files'] as List,
    optionName: 'exclude-files',
  );
  if (includeFileKinds.isNotEmpty && excludeFileKinds.isNotEmpty) {
    stderr.writeln(
      'Error: --include-files and --exclude-files cannot be used together.',
    );
    return ExitCodes.usage;
  }

  if (routeAddToMultiRegistry) {
    if (addCommand['help'] == true) {
      print('Usage: flutter_shadcn add <@namespace/component> [<@namespace/component> ...]');
      print('       flutter_shadcn add <component> [<component> ...]  # resolves using default/enabled registries');
      print('Options:');
      print('  --include-files   Optional kinds to include: readme, preview, meta');
      print('  --exclude-files   Optional kinds to exclude: readme, preview, meta');
      print('  --help, -h         Show this message');
      return ExitCodes.success;
    }
    final rest = addCommand.rest;
    if (rest.isEmpty) {
      print('Usage: flutter_shadcn add <component>');
      print('       flutter_shadcn add @namespace/component');
      return ExitCodes.usage;
    }
    try {
      await multiRegistry.runAdd(
        rest,
        includeFileKinds: includeFileKinds,
        excludeFileKinds: excludeFileKinds,
      );
      return ExitCodes.success;
    } catch (e) {
      stderr.writeln('Error: $e');
      if ('$e'.contains('ambiguous')) {
        return ExitCodes.usage;
      }
      return ExitCodes.componentMissing;
    }
  }

  final activeInstaller = installer;
  if (activeInstaller == null) {
    stderr.writeln('Error: Installer is not available.');
    return ExitCodes.registryNotFound;
  }
  final activeOrchestrator = InstallerOrchestrator(activeInstaller);
  if (addCommand['help'] == true) {
    print('Usage: flutter_shadcn add <component> [<component> ...]');
    print('       flutter_shadcn add @namespace/component');
    print('       flutter_shadcn add --all');
    print('Options:');
    print('  --all, -a          Install every available component');
    print('  --include-files   Optional kinds to include: readme, preview, meta');
    print('  --exclude-files   Optional kinds to exclude: readme, preview, meta');
    print('  --help, -h         Show this message');
    return ExitCodes.success;
  }

  final rest = addCommand.rest;
  final addAll = addCommand['all'] == true || rest.contains('all');
  if (addAll) {
    await activeOrchestrator.ensureInitFiles();
    await activeOrchestrator.runBulkInstall(() async {
      await activeOrchestrator.addComponents(const [
        'icon_fonts',
        'typography_fonts',
      ]);
      await activeOrchestrator.installAllComponents();
    });
    return ExitCodes.success;
  }
  if (rest.isEmpty) {
    print('Usage: flutter_shadcn add <component>');
    print('       flutter_shadcn add --all');
    return ExitCodes.usage;
  }

  final normalizedRest = <String>[];
  for (final token in rest) {
    final parsed = MultiRegistryManager.parseComponentRef(token);
    if (parsed == null) {
      normalizedRest.add(token);
      continue;
    }
    if (isLegacyNamespaceAliasAllowed(parsed.namespace, config)) {
      normalizedRest.add(parsed.componentId);
      continue;
    }
    stderr.writeln(
      'Error: Namespace "${parsed.namespace}" requires configured multi-registry sources.',
    );
    return ExitCodes.configInvalid;
  }

  final commandInstaller = Installer(
    registry: activeInstaller.registry,
    targetDir: targetDir,
    logger: logger,
    registryNamespace: preloadedNamespace,
    includeFileKindsOverride: includeFileKinds,
    excludeFileKindsOverride: excludeFileKinds,
    enableSharedGroups: activeInstaller.enableSharedGroups,
    enableComposites: activeInstaller.enableComposites,
  );
  final commandOrchestrator = InstallerOrchestrator(commandInstaller);
  await commandOrchestrator.ensureInitFiles();
  await commandOrchestrator.runBulkInstall(() async {
    await commandOrchestrator.addComponents(normalizedRest);
  });
  return ExitCodes.success;
}
