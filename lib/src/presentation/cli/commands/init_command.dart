import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_manager.dart';

Future<int> runInitCommand({
  required ArgResults initCommand,
  required MultiRegistryManager multiRegistry,
  required String defaultNamespace,
}) async {
  if (initCommand['help'] == true) {
    print('Usage: flutter_shadcn init [@namespace|namespace]');
    print('');
    print('Runs inline bootstrap actions for the selected namespace.');
    print('Defaults to current default namespace (shadcn by default).');
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

String _parseInitNamespaceToken(String token) {
  final trimmed = token.trim();
  if (trimmed.startsWith('@') && trimmed.length > 1) {
    return trimmed.substring(1);
  }
  return trimmed;
}
