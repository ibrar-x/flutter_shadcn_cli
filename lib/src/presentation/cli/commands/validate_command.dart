import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';
import 'package:flutter_shadcn_cli/src/validate_command.dart'
    as validate_service;

Future<int> runValidateCommandCli({
  required ArgResults command,
  required Registry? registry,
  required bool offline,
  required CliLogger logger,
}) async {
  if (command['help'] == true) {
    print('Usage: flutter_shadcn validate [--json]');
    print('');
    print('Validates components.json and registry file dependencies.');
    print('Options:');
    print('  --json             Output machine-readable JSON');
    return ExitCodes.success;
  }
  if (registry == null) {
    stderr.writeln('Error: Registry is not available.');
    return ExitCodes.registryNotFound;
  }
  return validate_service.runValidateCommand(
    registry: registry,
    registryRoot: registry.registryRoot,
    sourceRoot: registry.sourceRoot,
    offline: offline,
    jsonOutput: command['json'] == true,
    logger: logger,
  );
}
