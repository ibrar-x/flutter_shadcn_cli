import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_manager.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/bootstrap_route_decision.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/registry_bootstrap_exception.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/registry_bootstrap_selection.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/registry_selection.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/runtime_roots.dart';

export 'package:flutter_shadcn_cli/src/presentation/cli/registry_bootstrap_exception.dart';

Future<BootstrapRouteDecision> resolveBootstrapRouteDecision({
  required ArgResults argResults,
  required ShadcnConfig config,
  required MultiRegistryManager multiRegistry,
  required String? registriesUrl,
  required String? registriesPath,
}) async {
  var routeInitToMultiRegistry = false;
  var routeAddToMultiRegistry = false;
  final activeCommand = argResults.command;
  final hasRegistriesUrlOverride = registriesUrl?.isNotEmpty == true;
  final hasRegistriesPathOverride = registriesPath?.isNotEmpty == true;

  if (activeCommand != null && activeCommand.name == 'init') {
    final initRest = activeCommand.rest;
    final initAll = activeCommand['all'] == true;
    final explicitLegacySelection =
        hasExplicitLegacyRegistrySelection(argResults);
    if (!initAll && initRest.length == 1) {
      try {
        final namespaceCandidate = parseInitNamespaceToken(initRest.first);
        routeInitToMultiRegistry =
            await multiRegistry.canHandleNamespaceInit(namespaceCandidate);
      } catch (_) {
        routeInitToMultiRegistry = false;
      }
    } else if (!initAll &&
        initRest.isEmpty &&
        !explicitLegacySelection &&
        (config.hasRegistries ||
            hasRegistriesUrlOverride ||
            hasRegistriesPathOverride)) {
      try {
        final namespaceCandidate = config.effectiveDefaultNamespace;
        routeInitToMultiRegistry =
            await multiRegistry.canHandleNamespaceInit(namespaceCandidate);
      } catch (_) {
        routeInitToMultiRegistry = false;
      }
    }
  }

  if (activeCommand != null && activeCommand.name == 'add') {
    final addRest = activeCommand.rest;
    final addAll = activeCommand['all'] == true || addRest.contains('all');
    if (!addAll && addRest.isNotEmpty) {
      final hasConfiguredMap = hasConfiguredRegistryMap(config);
      final enabledCount =
          (config.registries ?? const <String, RegistryConfigEntry>{})
              .entries
              .where((entry) => entry.value.enabled)
              .length;
      routeAddToMultiRegistry = enabledCount > 1 || hasConfiguredMap;
    }
  }

  return BootstrapRouteDecision(
    routeInitToMultiRegistry: routeInitToMultiRegistry,
    routeAddToMultiRegistry: routeAddToMultiRegistry,
  );
}

String? resolveCommandNamespaceOverride(ArgResults argResults) {
  if (argResults.command?.name == 'remove') {
    final removeRest = argResults.command!.rest;
    final removeAll =
        argResults.command!['all'] == true || removeRest.contains('all');
    if (!removeAll && removeRest.isNotEmpty) {
      final namespaces = <String>{};
      for (final token in removeRest) {
        final parsed = MultiRegistryManager.parseComponentRef(token);
        if (parsed != null) {
          namespaces.add(parsed.namespace);
        }
      }
      if (namespaces.length == 1) {
        return namespaces.first;
      }
    }
  } else if (const {'theme', 'sync', 'validate', 'audit', 'deps'}
      .contains(argResults.command?.name)) {
    final rest = argResults.command?.rest ?? const <String>[];
    if (rest.isNotEmpty && rest.first.startsWith('@') && !rest.first.contains('/')) {
      return rest.first.substring(1).trim();
    }
  }
  return null;
}

Future<RegistryBootstrapSelection?> preloadRegistryIfNeeded({
  required ArgResults argResults,
  required ResolvedRoots roots,
  required ShadcnConfig config,
  required bool offline,
  required bool routeInitToMultiRegistry,
  required bool routeAddToMultiRegistry,
  required String? namespaceOverride,
  required CliLogger logger,
}) async {
  final commandName = argResults.command!.name;
  final needsRegistry = const {
    'init',
    'theme',
    'add',
    'dry-run',
    'remove',
    'sync',
    'assets',
    'validate',
    'audit',
    'deps',
  };
  final shouldLoad = needsRegistry.contains(commandName) &&
      !(commandName == 'init' && routeInitToMultiRegistry) &&
      !(commandName == 'add' && routeAddToMultiRegistry);
  if (!shouldLoad) {
    return null;
  }

  final selection = resolveRegistrySelection(
    argResults,
    roots,
    config,
    offline,
    namespaceOverride: namespaceOverride,
  );
  final cachePath = componentsJsonCachePath(selection.registryRoot);
  try {
    final registry = await Registry.load(
      registryRoot: selection.registryRoot,
      sourceRoot: selection.sourceRoot,
      schemaPath: selection.schemaPath,
      componentsPath: selection.componentsPath,
      cachePath: cachePath,
      offline: offline,
      logger: logger,
    );
    return RegistryBootstrapSelection(selection: selection, registry: registry);
  } catch (e) {
    throw RegistryBootstrapException(selection.registryRoot.root, e.toString());
  }
}

String parseInitNamespaceToken(String token) {
  final trimmed = token.trim();
  if (trimmed.startsWith('@') && trimmed.length > 1) {
    return trimmed.substring(1);
  }
  return trimmed;
}

bool hasConfiguredRegistryMap(ShadcnConfig config) {
  final registries = config.registries;
  if (registries == null || registries.isEmpty) {
    return false;
  }
  for (final entry in registries.values) {
    if ((entry.registryPath?.trim().isNotEmpty ?? false) ||
        (entry.registryUrl?.trim().isNotEmpty ?? false) ||
        (entry.baseUrl?.trim().isNotEmpty ?? false)) {
      return true;
    }
  }
  return false;
}

bool hasExplicitLegacyRegistrySelection(ArgResults args) {
  if (args.wasParsed('registry-path') || args.wasParsed('registry-url')) {
    return true;
  }
  if (!args.wasParsed('registry')) {
    return false;
  }
  final mode = (args['registry'] as String?)?.trim().toLowerCase();
  return mode != null && mode.isNotEmpty && mode != 'auto';
}
