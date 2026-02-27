import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/json_output.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_manager.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/platform_targets.dart';

Future<int> runRegistriesCommand({
  required ArgResults command,
  required ShadcnConfig config,
  required MultiRegistryManager multiRegistry,
}) async {
  if (command['help'] == true) {
    print('Usage: flutter_shadcn registries [--json]');
    print('');
    print('Lists configured and discoverable registries.');
    print('Options:');
    print('  --json             Output machine-readable JSON');
    print('  --help, -h         Show this message');
    return ExitCodes.success;
  }
  final summaries = await multiRegistry.listRegistries();
  if (command['json'] == true) {
    final payload = jsonEnvelope(
      command: 'registries',
      data: {
        'defaultNamespace': config.effectiveDefaultNamespace,
        'items': summaries.map((s) => s.toJson()).toList(),
      },
    );
    printJson(payload);
    return ExitCodes.success;
  }
  if (summaries.isEmpty) {
    print('No registries configured.');
    return ExitCodes.success;
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
    if (summary.registryPath != null && summary.registryPath!.isNotEmpty) {
      print('    path: ${summary.registryPath}');
    }
  }
  return ExitCodes.success;
}

Future<({ShadcnConfig config, int exitCode})> runDefaultCommand({
  required ArgResults command,
  required ShadcnConfig config,
  required MultiRegistryManager multiRegistry,
}) async {
  if (command['help'] == true) {
    print('Usage: flutter_shadcn default <namespace>');
    print('');
    print('Sets the default registry namespace.');
    return (config: config, exitCode: ExitCodes.success);
  }
  if (command.rest.isEmpty) {
    print('Current default registry: ${config.effectiveDefaultNamespace}');
    return (config: config, exitCode: ExitCodes.success);
  }
  final namespace = command.rest.first.trim();
  try {
    final next = await multiRegistry.setDefaultRegistry(namespace);
    print('Default registry set to: ${next.effectiveDefaultNamespace}');
    return (config: next, exitCode: ExitCodes.success);
  } catch (e) {
    print('Error: $e');
    return (config: config, exitCode: ExitCodes.configInvalid);
  }
}

Future<({ShadcnConfig config, int exitCode})> runPlatformCommand({
  required ArgResults command,
  required ShadcnConfig config,
  required String targetDir,
}) async {
  if (command['help'] == true) {
    print(
      'Usage: flutter_shadcn platform [--list | --set <p.s=path> | --reset <p.s>]',
    );
    print('');
    print('Options:');
    print('  --list             List platform targets');
    print(
      '  --set              Set override (repeatable), e.g. ios.infoPlist=ios/Runner/Info.plist',
    );
    print(
      '  --reset            Remove override (repeatable), e.g. ios.infoPlist',
    );
    print('  --help, -h         Show this message');
    return (config: config, exitCode: ExitCodes.success);
  }

  final sets = (command['set'] as List).cast<String>();
  final resets = (command['reset'] as List).cast<String>();
  final list = command['list'] == true;
  if (sets.isEmpty && resets.isEmpty && !list) {
    print('Nothing selected. Use --list, --set, or --reset.');
    return (config: config, exitCode: ExitCodes.usage);
  }

  var nextConfig = config;
  final updated = updatePlatformTargets(config, sets, resets);
  if (updated != null) {
    nextConfig = updated;
    await ShadcnConfig.save(targetDir, nextConfig);
  }
  final targets = mergePlatformTargets(nextConfig.platformTargets);
  printPlatformTargets(targets);
  return (config: nextConfig, exitCode: ExitCodes.success);
}
