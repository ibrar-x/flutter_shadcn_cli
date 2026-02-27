part of 'multi_registry_manager.dart';

extension MultiRegistryInitPart on MultiRegistryManager {
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
    final projectRoot = findProjectRootFrom(targetDir);
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
        ? RegistrySource.fromDirectory(directoryEntry)
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
}
