import 'dart:io';

import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/init_action_engine.dart';
import 'package:flutter_shadcn_cli/src/inline_action_journal.dart';
import 'package:flutter_shadcn_cli/src/installer.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';
import 'package:flutter_shadcn_cli/src/registry_directory.dart';
import 'package:flutter_shadcn_cli/src/state.dart';
import 'package:flutter_shadcn_cli/src/version_manager.dart';
import 'package:path/path.dart' as p;

class MultiRegistryException implements Exception {
  final String message;

  MultiRegistryException(this.message);

  @override
  String toString() => message;
}

class MultiRegistryManager {
  final String targetDir;
  final bool offline;
  final CliLogger logger;
  final String directoryUrl;
  final String? directoryPath;
  final RegistryDirectoryClient directoryClient;
  final InitActionEngine initActionEngine;

  RegistryDirectory? _directoryCache;
  final Map<String, _RegistrySource> _sources = {};
  final Map<String, Registry> _registryCache = {};

  MultiRegistryManager({
    required this.targetDir,
    required this.offline,
    required this.logger,
    this.directoryUrl = defaultRegistriesDirectoryUrl,
    this.directoryPath,
    RegistryDirectoryClient? directoryClient,
    InitActionEngine? initActionEngine,
  })  : directoryClient = directoryClient ?? RegistryDirectoryClient(),
        initActionEngine = initActionEngine ?? InitActionEngine();

  void close() {
    directoryClient.close();
  }

  static QualifiedComponentRef? parseComponentRef(String token) {
    return _parseQualifiedComponentRef(token);
  }

  Future<bool> canHandleNamespaceInit(String namespace) async {
    final trimmed = namespace.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final config = await ShadcnConfig.load(targetDir);
    final byConfig = config.registryConfig(trimmed);
    if (byConfig != null) {
      return true;
    }
    final directory = await _loadDirectory();
    return directory.registries.any((entry) => entry.namespace == trimmed);
  }

  Future<void> runNamespaceInit(String namespace) async {
    final projectRoot = _resolveProjectRoot(targetDir);
    var config = await ShadcnConfig.load(projectRoot);
    RegistryDirectoryEntry? directoryEntry;
    try {
      final directory = await _loadDirectory();
      directoryEntry = directory.registries.firstWhere(
        (entry) => entry.namespace == namespace,
      );
    } catch (_) {
      directoryEntry = null;
    }
    final source = directoryEntry != null
        ? _RegistrySource.fromDirectory(directoryEntry)
        : await _resolveSourceForNamespace(
            namespace,
            config,
            allowDirectoryFallback: false,
          );
    if (directoryEntry != null) {
      config = await _upsertConfigFromDirectory(config, directoryEntry);
    }
    await ShadcnConfig.save(projectRoot, config);

    if (directoryEntry == null) {
      logger.info('No bootstrap actions defined for this registry.');
      return;
    }

    final configured = config.registryConfig(namespace);
    final overrideBaseUrl = configured?.baseUrl ?? configured?.registryUrl;
    final initEntry = overrideBaseUrl != null && overrideBaseUrl.isNotEmpty
        ? RegistryDirectoryEntry(
            id: directoryEntry.id,
            displayName: directoryEntry.displayName,
            minCliVersion: directoryEntry.minCliVersion,
            baseUrl: overrideBaseUrl,
            namespace: directoryEntry.namespace,
            installRoot: directoryEntry.installRoot,
            paths: directoryEntry.paths,
            init: directoryEntry.init,
            raw: directoryEntry.raw,
          )
        : directoryEntry;

    final result = await initActionEngine.executeRegistryInit(
      projectRoot: projectRoot,
      registry: initEntry,
      logger: logger,
    );
    await _recordInlineExecution(
      projectRoot: projectRoot,
      namespace: namespace,
      category: 'init',
      record: result.record,
    );

    final state = await ShadcnState.load(
      projectRoot,
      defaultNamespace: config.effectiveDefaultNamespace,
    );
    final merged = Map<String, RegistryStateEntry>.from(
      state.registries ?? const {},
    );
    merged[namespace] = RegistryStateEntry(
      installPath: source.installRoot,
      sharedPath: source.sharedRoot,
      themeId: state.themeId,
    );
    await ShadcnState.save(
      projectRoot,
      ShadcnState(
        installPath: state.installPath ?? source.installRoot,
        sharedPath: state.sharedPath ?? source.sharedRoot,
        themeId: state.themeId,
        managedDependencies: state.managedDependencies,
        registries: merged,
      ),
    );

    if (!initEntry.hasInlineInit) {
      logger.info('No bootstrap actions defined for this registry.');
    } else {
      logger.success(
        'Initialized ${source.namespace} (${result.filesWritten} files, ${result.dirsCreated} dirs).',
      );
    }
  }

  Future<void> runAdd(
    List<String> requested, {
    Set<String>? includeFileKinds,
    Set<String>? excludeFileKinds,
  }) async {
    if (requested.isEmpty) {
      throw MultiRegistryException('No components provided');
    }
    final projectRoot = _resolveProjectRoot(targetDir);
    var config = await ShadcnConfig.load(projectRoot);
    final refs = await _resolveAddRequests(
      requested,
      config,
      projectRoot: projectRoot,
    );

    final grouped = <String, List<String>>{};
    for (final ref in refs) {
      grouped.putIfAbsent(ref.namespace, () => []).add(ref.componentId);
    }

    for (final entry in grouped.entries) {
      final source = await _resolveSourceForNamespace(
        entry.key,
        config,
        allowDirectoryFallback: true,
      );
      if (source.directoryEntry != null) {
        config =
            await _upsertConfigFromDirectory(config, source.directoryEntry!);
      }
      final registry = await _loadRegistryForSource(
        source,
        projectRoot: projectRoot,
      );
      final installer = Installer(
        registry: registry,
        targetDir: projectRoot,
        logger: logger,
        installPathOverride: source.installRoot,
        sharedPathOverride: source.sharedRoot,
        stateNamespace: source.namespace,
        registryNamespace: source.namespace,
        includeFileKindsOverride: includeFileKinds,
        excludeFileKindsOverride: excludeFileKinds,
        enableLegacyCoreBootstrap: false,
      );
      await installer.runBulkInstall(() async {
        for (final componentId in entry.value) {
          await installer.addComponent(componentId);
        }
      });
    }

    await ShadcnConfig.save(projectRoot, config);
  }

  Future<bool> runInlineAssets({
    required String namespace,
    required bool installIcons,
    required bool installTypography,
    required bool installAll,
  }) async {
    final projectRoot = _resolveProjectRoot(targetDir);
    var config = await ShadcnConfig.load(projectRoot);
    late final RegistryDirectoryEntry entry;
    try {
      final directory = await _loadDirectory();
      entry = directory.registries.firstWhere(
        (item) => item.namespace == namespace,
      );
    } catch (_) {
      return false;
    }
    if (!entry.hasInlineInit) {
      return false;
    }

    config = await _upsertConfigFromDirectory(config, entry);
    await ShadcnConfig.save(projectRoot, config);

    final selectedActions = _selectInlineAssetActions(
      entry: entry,
      installIcons: installIcons,
      installTypography: installTypography,
      installAll: installAll,
    );
    if (selectedActions.isEmpty) {
      return false;
    }

    final configured = config.registryConfig(namespace);
    final overrideBaseUrl = configured?.baseUrl ?? configured?.registryUrl;
    final baseUrl = overrideBaseUrl != null && overrideBaseUrl.isNotEmpty
        ? overrideBaseUrl
        : entry.baseUrl;
    final result = await initActionEngine.executeActions(
      projectRoot: projectRoot,
      baseUrl: baseUrl,
      actions: selectedActions,
      logger: logger,
    );
    final category = _inlineAssetCategory(
      installIcons: installIcons,
      installTypography: installTypography,
      installAll: installAll,
    );
    await _recordInlineExecution(
      projectRoot: projectRoot,
      namespace: namespace,
      category: category,
      record: result.record,
    );
    return true;
  }

  Future<bool> rollbackInlineAssets({
    required String namespace,
    required bool removeIcons,
    required bool removeTypography,
    required bool removeAll,
  }) async {
    final projectRoot = _resolveProjectRoot(targetDir);
    final journal = await InlineActionJournal.load(projectRoot);
    if (removeAll) {
      final snapshot = journal.takeAll(namespace);
      if (snapshot.entries.isEmpty) {
        return false;
      }
      final entries = snapshot.entries.toList().reversed.toList();
      for (final entry in entries) {
        await initActionEngine.rollbackRecordedChanges(
          projectRoot: projectRoot,
          record: entry.record,
          logger: logger,
        );
      }
      await snapshot.journal.save(projectRoot);
      return true;
    }

    final desired = <String>{};
    if (removeIcons) {
      desired.add('assets:icons');
      desired.add('assets:all');
    }
    if (removeTypography) {
      desired.add('assets:typography');
      desired.add('assets:all');
    }
    if (desired.isEmpty) {
      return false;
    }
    final snapshot = journal.takeLatest(
      namespace,
      where: (entry) => desired.contains(entry.category),
    );
    if (snapshot.entry == null) {
      return false;
    }
    await initActionEngine.rollbackRecordedChanges(
      projectRoot: projectRoot,
      record: snapshot.entry!.record,
      logger: logger,
    );
    await snapshot.journal.save(projectRoot);
    return true;
  }

  Future<List<_AddRequest>> _resolveAddRequests(
    List<String> requested,
    ShadcnConfig config, {
    required String projectRoot,
  }) async {
    final resolved = <_AddRequest>[];

    final enabled = (config.registries ?? const <String, RegistryConfigEntry>{})
        .entries
        .where((entry) => entry.value.enabled)
        .map((entry) => entry.key)
        .toSet();
    if (enabled.isEmpty &&
        config.registries != null &&
        config.registries!.isNotEmpty) {
      enabled.add(config.effectiveDefaultNamespace);
    }
    final defaultNamespace = config.effectiveDefaultNamespace;

    for (final token in requested) {
      final qualified = _parseQualifiedComponentRef(token);
      if (qualified != null) {
        resolved.add(
          _AddRequest(
            namespace: qualified.namespace,
            componentId: qualified.componentId,
          ),
        );
        continue;
      }

      if (enabled.contains(defaultNamespace)) {
        final defaultSource = await _resolveSourceForNamespace(
          defaultNamespace,
          config,
          allowDirectoryFallback: true,
        );
        final defaultRegistry = await _loadRegistryForSource(
          defaultSource,
          projectRoot: projectRoot,
        );
        if (defaultRegistry.getComponent(token) != null) {
          resolved.add(
            _AddRequest(namespace: defaultNamespace, componentId: token),
          );
          continue;
        }
      }

      final candidates = <String>[];
      for (final namespace in enabled) {
        final source = await _resolveSourceForNamespace(
          namespace,
          config,
          allowDirectoryFallback: true,
        );
        final registry = await _loadRegistryForSource(
          source,
          projectRoot: projectRoot,
        );
        if (registry.getComponent(token) != null) {
          candidates.add(namespace);
        }
      }

      if (candidates.isEmpty) {
        throw MultiRegistryException('Component "$token" not found.');
      }
      if (candidates.length > 1) {
        candidates.sort();
        throw MultiRegistryException(
          'Component "$token" is ambiguous across registries (${candidates.join(', ')}). '
          'Use namespace-qualified form: @<namespace>/$token',
        );
      }
      resolved.add(
        _AddRequest(namespace: candidates.first, componentId: token),
      );
    }

    return resolved;
  }

  Future<void> _recordInlineExecution({
    required String projectRoot,
    required String namespace,
    required String category,
    required InitExecutionRecord record,
  }) async {
    if (record.filesWritten.isEmpty &&
        record.dirsCreated.isEmpty &&
        record.pubspecDelta.isEmpty) {
      return;
    }
    final journal = await InlineActionJournal.load(projectRoot);
    final updated = journal.append(
      namespace: namespace,
      entry: InlineActionJournalEntry(
        category: category,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        record: record,
      ),
    );
    await updated.save(projectRoot);
  }

  String _inlineAssetCategory({
    required bool installIcons,
    required bool installTypography,
    required bool installAll,
  }) {
    if (installAll || (installIcons && installTypography)) {
      return 'assets:all';
    }
    if (installTypography) {
      return 'assets:typography';
    }
    return 'assets:icons';
  }

  List<Map<String, dynamic>> _selectInlineAssetActions({
    required RegistryDirectoryEntry entry,
    required bool installIcons,
    required bool installTypography,
    required bool installAll,
  }) {
    final init = entry.init;
    if (init == null || !entry.hasInlineInit) {
      return const [];
    }
    final actionList = (init['actions'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
    if (actionList.isEmpty) {
      return const [];
    }
    if (installAll || (installIcons && installTypography)) {
      return actionList.where(_matchesAnyAssetScope).toList();
    }
    return actionList.where((action) {
      if (installIcons && _matchesIconScope(action)) {
        return true;
      }
      if (installTypography && _matchesTypographyScope(action)) {
        return true;
      }
      return false;
    }).toList();
  }

  bool _matchesAnyAssetScope(Map<String, dynamic> action) {
    return _matchesIconScope(action) || _matchesTypographyScope(action);
  }

  bool _matchesIconScope(Map<String, dynamic> action) {
    final scopes = _extractActionScopes(action);
    if (scopes.isNotEmpty) {
      if (scopes.contains('all') || scopes.contains('assets')) {
        return true;
      }
      return scopes.contains('icons') ||
          scopes.contains('icon') ||
          scopes.contains('icon_fonts');
    }
    final text = _actionTextBlob(action);
    return text.contains('icon') ||
        text.contains('lucide') ||
        text.contains('radix') ||
        text.contains('bootstrap');
  }

  bool _matchesTypographyScope(Map<String, dynamic> action) {
    final scopes = _extractActionScopes(action);
    if (scopes.isNotEmpty) {
      if (scopes.contains('all') || scopes.contains('assets')) {
        return true;
      }
      return scopes.contains('typography') ||
          scopes.contains('fonts') ||
          scopes.contains('font') ||
          scopes.contains('typography_fonts');
    }
    final text = _actionTextBlob(action);
    return text.contains('typography') ||
        text.contains('font') ||
        text.contains('geist');
  }

  Set<String> _extractActionScopes(Map<String, dynamic> action) {
    final scopeValues = <String>{};
    for (final key in const [
      'scope',
      'scopes',
      'group',
      'groups',
      'profile',
      'profiles',
      'tag',
      'tags',
    ]) {
      final value = action[key];
      if (value is String) {
        scopeValues.addAll(
          value
              .toLowerCase()
              .split(RegExp(r'[,/ ]+'))
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty),
        );
      } else if (value is List) {
        for (final item in value) {
          final token = item.toString().trim().toLowerCase();
          if (token.isNotEmpty) {
            scopeValues.add(token);
          }
        }
      }
    }
    return scopeValues;
  }

  String _actionTextBlob(Map<String, dynamic> action) {
    final values = <String>[];
    void walk(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is String) {
        values.add(value.toLowerCase());
        return;
      }
      if (value is List) {
        for (final item in value) {
          walk(item);
        }
        return;
      }
      if (value is Map) {
        value.forEach((key, item) {
          values.add(key.toString().toLowerCase());
          walk(item);
        });
      }
    }

    walk(action);
    return values.join(' ');
  }

  Future<List<RegistrySummary>> listRegistries() async {
    final projectRoot = _resolveProjectRoot(targetDir);
    final config = await ShadcnConfig.load(projectRoot);
    final summaries = <String, RegistrySummary>{};

    final defaultNamespace = config.effectiveDefaultNamespace;
    final configRegistries =
        config.registries ?? const <String, RegistryConfigEntry>{};
    for (final entry in configRegistries.entries) {
      final namespace = entry.key;
      final value = entry.value;
      summaries[namespace] = RegistrySummary(
        namespace: namespace,
        displayName: namespace,
        isDefault: namespace == defaultNamespace,
        enabled: value.enabled,
        source: 'config',
        mode: value.registryMode,
        baseUrl: value.baseUrl ?? value.registryUrl,
        registryPath: value.registryPath,
        installRoot: value.installPath,
      );
    }

    try {
      final directory = await _loadDirectory();
      for (final entry in directory.registries) {
        final existing = summaries[entry.namespace];
        final mergedSource =
            existing == null ? 'directory' : 'config+directory';
        summaries[entry.namespace] = RegistrySummary(
          namespace: entry.namespace,
          displayName: entry.displayName,
          isDefault: entry.namespace == defaultNamespace,
          enabled: existing?.enabled ?? true,
          source: mergedSource,
          mode: existing?.mode ?? 'remote',
          baseUrl: existing?.baseUrl ?? entry.baseUrl,
          registryPath: existing?.registryPath,
          installRoot: existing?.installRoot ?? entry.installRoot,
        );
      }
    } catch (_) {
      // Directory lookup is optional for this listing command.
    }

    final list = summaries.values.toList()
      ..sort((a, b) => a.namespace.compareTo(b.namespace));
    return list;
  }

  Future<ShadcnConfig> setDefaultRegistry(String namespace) async {
    final trimmed = namespace.trim();
    if (trimmed.isEmpty) {
      throw MultiRegistryException('Registry namespace cannot be empty.');
    }

    final projectRoot = _resolveProjectRoot(targetDir);
    var config = await ShadcnConfig.load(projectRoot);
    var entry = config.registryConfig(trimmed);

    if (entry == null) {
      final directory = await _loadDirectory();
      final directoryEntry = directory.registries.firstWhere(
        (item) => item.namespace == trimmed,
        orElse: () => throw MultiRegistryException(
          'Registry namespace "$trimmed" not found.',
        ),
      );
      config = await _upsertConfigFromDirectory(config, directoryEntry);
      entry = config.registryConfig(trimmed);
    }

    if (entry == null) {
      throw MultiRegistryException('Registry namespace "$trimmed" not found.');
    }

    config = config.copyWith(
      defaultNamespace: trimmed,
      registryMode: entry.registryMode ?? config.registryMode,
      registryPath: entry.registryPath ?? config.registryPath,
      registryUrl: entry.baseUrl ?? entry.registryUrl ?? config.registryUrl,
      installPath: entry.installPath ?? config.installPath,
      sharedPath: entry.sharedPath ?? config.sharedPath,
    );
    await ShadcnConfig.save(projectRoot, config);
    return config;
  }

  static QualifiedComponentRef? _parseQualifiedComponentRef(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('@')) {
      final slash = trimmed.indexOf('/');
      if (slash <= 1 || slash == trimmed.length - 1) {
        return null;
      }
      final namespace = trimmed.substring(1, slash).trim();
      final componentId = trimmed.substring(slash + 1).trim();
      if (namespace.isEmpty || componentId.isEmpty) {
        return null;
      }
      return QualifiedComponentRef(
          namespace: namespace, componentId: componentId);
    }

    final split = trimmed.split(':');
    if (split.length == 2 && split[0].isNotEmpty && split[1].isNotEmpty) {
      return QualifiedComponentRef(
        namespace: split[0].trim(),
        componentId: split[1].trim(),
      );
    }

    return null;
  }

  Future<Registry> _loadRegistryForSource(
    _RegistrySource source, {
    required String projectRoot,
  }) async {
    final cacheKey =
        source.namespace.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (_registryCache.containsKey(cacheKey)) {
      return _registryCache[cacheKey]!;
    }

    final registry = await source.loadRegistry(
      projectRoot: projectRoot,
      offline: offline,
      logger: logger,
      directoryClient: directoryClient,
    );
    _registryCache[cacheKey] = registry;
    return registry;
  }

  Future<_RegistrySource> _resolveSourceForNamespace(
    String namespace,
    ShadcnConfig config, {
    required bool allowDirectoryFallback,
  }) async {
    final cached = _sources[namespace];
    if (cached != null) {
      return cached;
    }

    final configEntry = config.registryConfig(namespace);
    if (configEntry != null &&
        ((configEntry.registryMode == 'local' &&
                configEntry.registryPath != null) ||
            configEntry.registryUrl != null ||
            configEntry.baseUrl != null)) {
      final source = _RegistrySource.fromConfig(
        namespace: namespace,
        projectRoot: targetDir,
        configEntry: configEntry,
      );
      _sources[namespace] = source;
      return source;
    }

    if (!allowDirectoryFallback) {
      throw MultiRegistryException(
          'Registry namespace "$namespace" is not configured.');
    }

    final directory = await _loadDirectory();
    final entry = directory.registries.firstWhere(
      (item) => item.namespace == namespace,
      orElse: () => throw MultiRegistryException(
        'Registry namespace "$namespace" not found in registries directory.',
      ),
    );
    final source = _RegistrySource.fromDirectory(entry);
    _sources[namespace] = source;
    return source;
  }

  Future<ShadcnConfig> _upsertConfigFromDirectory(
    ShadcnConfig config,
    RegistryDirectoryEntry entry,
  ) async {
    final installRoot = entry.installRoot;
    final sharedRoot = '$installRoot/shared';
    final existing = config.registryConfig(entry.namespace);
    final next = config.withRegistry(
      entry.namespace,
      existing?.copyWith(
            registryMode: existing.registryMode ?? 'remote',
            registryUrl: existing.registryUrl ?? entry.baseUrl,
            baseUrl: existing.baseUrl ?? entry.baseUrl,
            componentsPath: existing.componentsPath ?? entry.componentsPath,
            componentsSchemaPath:
                existing.componentsSchemaPath ?? entry.componentsSchemaPath,
            indexPath: existing.indexPath ?? entry.indexPath,
            installPath: existing.installPath ?? installRoot,
            sharedPath: existing.sharedPath ?? sharedRoot,
            enabled: true,
          ) ??
          RegistryConfigEntry(
            registryMode: 'remote',
            registryUrl: entry.baseUrl,
            baseUrl: entry.baseUrl,
            componentsPath: entry.componentsPath,
            componentsSchemaPath: entry.componentsSchemaPath,
            indexPath: entry.indexPath,
            installPath: installRoot,
            sharedPath: sharedRoot,
            enabled: true,
          ),
    );
    return next;
  }

  Future<RegistryDirectory> _loadDirectory() async {
    if (_directoryCache != null) {
      return _directoryCache!;
    }
    _directoryCache = await directoryClient.load(
      projectRoot: targetDir,
      directoryUrl: directoryUrl,
      directoryPath: directoryPath,
      offline: offline,
      currentCliVersion: VersionManager.currentVersion,
      logger: logger,
    );
    return _directoryCache!;
  }

  String _resolveProjectRoot(String from) {
    var current = Directory(from);
    while (true) {
      final pubspec = File(p.join(current.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        return current.path;
      }
      final parent = current.parent;
      if (parent.path == current.path) {
        throw MultiRegistryException(
          'Could not locate Flutter project root (pubspec.yaml not found).',
        );
      }
      current = parent;
    }
  }
}

class _RegistrySource {
  final String namespace;
  final String installRoot;
  final String sharedRoot;
  final RegistryDirectoryEntry? directoryEntry;
  final RegistryConfigEntry? configEntry;

  const _RegistrySource({
    required this.namespace,
    required this.installRoot,
    required this.sharedRoot,
    required this.directoryEntry,
    required this.configEntry,
  });

  factory _RegistrySource.fromDirectory(RegistryDirectoryEntry entry) {
    return _RegistrySource(
      namespace: entry.namespace,
      installRoot: entry.installRoot,
      sharedRoot: '${entry.installRoot}/shared',
      directoryEntry: entry,
      configEntry: null,
    );
  }

  factory _RegistrySource.fromConfig({
    required String namespace,
    required String projectRoot,
    required RegistryConfigEntry configEntry,
  }) {
    final install = configEntry.installPath ?? 'lib/ui/$namespace';
    final shared = configEntry.sharedPath ?? '$install/shared';
    return _RegistrySource(
      namespace: namespace,
      installRoot: install,
      sharedRoot: shared,
      directoryEntry: null,
      configEntry: configEntry,
    );
  }

  Future<Registry> loadRegistry({
    required String projectRoot,
    required bool offline,
    required CliLogger logger,
    required RegistryDirectoryClient directoryClient,
  }) async {
    if (directoryEntry != null) {
      final content = await directoryClient.loadComponentsJson(
        projectRoot: projectRoot,
        registry: directoryEntry!,
        offline: offline,
        logger: logger,
      );
      final root =
          RegistryLocation.remote(directoryEntry!.baseUrl, offline: offline);
      return Registry.fromContent(
        content: content,
        registryRoot: root,
        sourceRoot: root,
        schemaPath: directoryEntry!.componentsSchemaPath,
        logger: logger,
      );
    }

    final entry = configEntry;
    if (entry == null) {
      throw MultiRegistryException('Registry source is not configured.');
    }

    final mode = (entry.registryMode ?? '').trim();
    if (mode == 'local' || entry.registryPath != null) {
      final localRoot = _resolveLocalPath(projectRoot, entry.registryPath);
      if (localRoot == null) {
        throw MultiRegistryException(
          'Local registry path is not configured for namespace "$namespace".',
        );
      }
      return Registry.load(
        registryRoot: RegistryLocation.local(localRoot),
        sourceRoot: RegistryLocation.local(p.dirname(localRoot)),
        componentsPath: entry.componentsPath ?? 'components.json',
        schemaPath: entry.componentsSchemaPath,
        logger: logger,
      );
    }

    final remoteRoot = entry.baseUrl ?? entry.registryUrl;
    if (remoteRoot == null || remoteRoot.isEmpty) {
      throw MultiRegistryException(
        'Remote registry URL is not configured for namespace "$namespace".',
      );
    }
    return Registry.load(
      registryRoot: RegistryLocation.remote(remoteRoot, offline: offline),
      sourceRoot: RegistryLocation.remote(remoteRoot, offline: offline),
      componentsPath: entry.componentsPath ?? 'components.json',
      schemaPath: entry.componentsSchemaPath,
      cachePath: p.join(
        projectRoot,
        '.shadcn',
        'cache',
        'components_${namespace.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.json',
      ),
      offline: offline,
      logger: logger,
    );
  }

  static String? _resolveLocalPath(String projectRoot, String? path) {
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    final trimmed = path.trim();
    if (p.isAbsolute(trimmed)) {
      return p.normalize(trimmed);
    }
    return p.normalize(p.join(projectRoot, trimmed));
  }
}

class _AddRequest {
  final String namespace;
  final String componentId;

  const _AddRequest({
    required this.namespace,
    required this.componentId,
  });
}

class QualifiedComponentRef {
  final String namespace;
  final String componentId;

  const QualifiedComponentRef({
    required this.namespace,
    required this.componentId,
  });
}

class RegistrySummary {
  final String namespace;
  final String displayName;
  final bool isDefault;
  final bool enabled;
  final String source;
  final String? mode;
  final String? baseUrl;
  final String? registryPath;
  final String? installRoot;

  const RegistrySummary({
    required this.namespace,
    required this.displayName,
    required this.isDefault,
    required this.enabled,
    required this.source,
    required this.mode,
    required this.baseUrl,
    required this.registryPath,
    required this.installRoot,
  });

  Map<String, dynamic> toJson() {
    return {
      'namespace': namespace,
      'displayName': displayName,
      'isDefault': isDefault,
      'enabled': enabled,
      'source': source,
      'mode': mode,
      'baseUrl': baseUrl,
      'registryPath': registryPath,
      'installRoot': installRoot,
    };
  }
}
