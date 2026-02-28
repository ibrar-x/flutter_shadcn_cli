import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/deps_command.dart' as deps_service;
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';

Future<int> runDepsCommandCli({
  required ArgResults command,
  required Registry? registry,
  required String targetDir,
  required ShadcnConfig config,
  required CliLogger logger,
}) async {
  if (command['help'] == true) {
    print('Usage: flutter_shadcn deps [--all] [--json]');
    print('');
    print('Compares registry dependency versions to pubspec.yaml.');
    print('Options:');
    print('  --all, -a          Compare all registry components');
    print('  --json             Output machine-readable JSON');
    return ExitCodes.success;
  }
  if (registry == null) {
    stderr.writeln('Error: Registry is not available.');
    return ExitCodes.registryNotFound;
  }
  return deps_service.runDepsCommand(
    registry: registry,
    targetDir: targetDir,
    config: config,
    includeAll: command['all'] == true,
    jsonOutput: command['json'] == true,
    logger: logger,
  );
}
