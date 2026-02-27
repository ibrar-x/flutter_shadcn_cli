import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/discovery_commands.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_manager.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/registry_selection.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/runtime_roots.dart';

Future<int> runInfoCommand({
  required ArgResults infoCommand,
  required ArgResults rootArgs,
  required String? localRegistryRoot,
  required String? cliRoot,
  required ShadcnConfig config,
  required bool offline,
  required CliLogger logger,
}) async {
  if (infoCommand['help'] == true) {
    print('Usage: flutter_shadcn info <component-id|@namespace/component> [--refresh] [--json]');
    print('');
    print('Shows detailed information about a component.');
    print('Options:');
    print('  --refresh  Refresh cache from remote');
    print('  --json     Output machine-readable JSON');
    return ExitCodes.success;
  }
  final componentToken = infoCommand.rest.isNotEmpty ? infoCommand.rest.first : '';
  if (componentToken.isEmpty) {
    print('Usage: flutter_shadcn info <component-id>');
    return ExitCodes.usage;
  }
  String componentId = componentToken;
  String? namespaceOverride;
  final qualified = MultiRegistryManager.parseComponentRef(componentToken);
  if (qualified != null) {
    namespaceOverride = qualified.namespace;
    componentId = qualified.componentId;
  }

  final roots = ResolvedRoots(localRegistryRoot: localRegistryRoot, cliRoot: cliRoot);
  final selection = resolveRegistrySelection(
    rootArgs,
    roots,
    config,
    offline,
    namespaceOverride: namespaceOverride,
  );
  final registryUrl = selection.registryRoot.root;
  final infoExit = await handleInfoCommand(
    componentId: componentId,
    registryBaseUrl: registryUrl,
    registryId: sanitizeCacheKey(registryUrl),
    refresh: infoCommand['refresh'] == true,
    offline: offline,
    jsonOutput: infoCommand['json'] == true,
    logger: logger,
  );
  return infoExit;
}
