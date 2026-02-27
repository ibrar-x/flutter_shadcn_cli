import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/application/services/installer_orchestrator.dart';
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/installer.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_manager.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/arg_helpers.dart';

Future<int> runAssetsCommand({
  required ArgResults command,
  required Installer? installer,
  required MultiRegistryManager multiRegistry,
  required ArgResults rootArgs,
  required ShadcnConfig config,
  required CliLogger logger,
}) async {
  final activeInstaller = installer;
  if (activeInstaller == null) {
    stderr.writeln('Error: Installer is not available.');
    return ExitCodes.registryNotFound;
  }
  final orchestrator = InstallerOrchestrator(activeInstaller);
  if (command['help'] == true) {
    print('Usage: flutter_shadcn assets [options]');
    print('');
    print('Options:');
    print('  --icons            Install icon font assets');
    print('  --typography       Install typography font assets');
    print('  --fonts            Alias for --typography');
    print('  --list             List available assets');
    print('  --all, -a          Install both icon + typography fonts');
    print('  --help, -h         Show this message');
    return ExitCodes.success;
  }
  if (command['list'] == true) {
    print('Available assets:');
    print('  icon_fonts');
    print('  typography_fonts');
    return ExitCodes.success;
  }

  final installAll = command['all'] == true;
  final installIcons = command['icons'] == true;
  final installTypography =
      command['typography'] == true || command['fonts'] == true;
  if (!installAll && !installIcons && !installTypography) {
    print('Nothing selected. Use --icons, --typography, or --all.');
    return ExitCodes.usage;
  }

  final inlineHandled = await multiRegistry.runInlineAssets(
    namespace: selectedNamespaceForCommand(rootArgs, config),
    installIcons: installIcons,
    installTypography: installTypography,
    installAll: installAll,
  );
  if (inlineHandled) {
    logger.success('Installed assets via inline registry actions.');
    return ExitCodes.success;
  }

  await orchestrator.runBulkInstall(() async {
    final components = <String>[];
    if (installAll || installIcons) {
      components.add('icon_fonts');
    }
    if (installAll || installTypography) {
      components.add('typography_fonts');
    }
    await orchestrator.addComponents(components);
  });
  return ExitCodes.success;
}
