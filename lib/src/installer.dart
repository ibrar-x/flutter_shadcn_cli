import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'registry.dart';
import 'config.dart';
import 'logger.dart';
import 'theme_css.dart';
import 'state.dart';
import 'package:flutter_shadcn_cli/registry/shared/theme/preset_theme_data.dart'
    show RegistryThemePresetData;

class Installer {
  static const int _fileCopyConcurrency = 4;
  final Registry registry;
  final String targetDir; // The user's project root
  final CliLogger logger;
  Set<String>? _installedComponentCache;
  final Set<String> _installingComponentIds = {};
  final Set<String> _installingSharedIds = {};
  final Set<String> _installedSharedCache = {};
  bool _initFilesEnsured = false;
  bool _deferAliases = false;
  bool _deferDependencyUpdates = false;
  final Map<String, dynamic> _pendingDependencies = {};
  final Set<String> _pendingAssets = {};
  final List<FontEntry> _pendingFonts = [];
  final Map<String, Future<void>> _componentInstallTasks = {};
  bool _deferComponentManifest = false;
  Map<String, _RegistryFileOwner>? _registryFileIndex;
  final Map<String, Set<String>> _sharedDependencyCache = {};

  Installer({
    required this.registry,
    required this.targetDir,
    CliLogger? logger,
  }) : logger = logger ?? CliLogger();

  Future<void> init({
    bool skipPrompts = false,
    InitConfigOverrides? configOverrides,
    String? themePreset,
  }) async {
    logger.header('Initializing flutter_shadcn');
    // Install all shared items that are marked as default/core if there were any,
    // but typically we install shared items on demand or all of them for init?
    // The "shared" list in components.json contains ALL shared items.
    // For init, we probably want to ensure the base structure exists.
    // But let's just create the folders for now.

    // Actually, shadcn-ui usually installs a "utils" file during init.
    // Here we have specific shared modules.
    // Let's install 'theme' and 'util' as they are core.

    if (configOverrides != null && configOverrides.hasAny) {
      await _ensureConfigOverrides(configOverrides);
    } else if (skipPrompts) {
      await _ensureConfigDefaults();
    } else {
      await _ensureConfig();
    }

    final config = await ShadcnConfig.load(targetDir);
    if (!skipPrompts) {
      _printInitSummary(config, themePreset);
      final proceed = _confirmInitProceed();
      if (!proceed) {
        logger.warn('Initialization cancelled.');
        return;
      }
    }

    const coreShared = [
      'theme',
      'util',
      'color_extensions',
      'form_control',
      'form_value_supplier',
    ];
    final sharedToInstall = (await _resolveSharedDependencyClosure(
      coreShared.toSet(),
    ))
      ..removeWhere((id) => id.isEmpty);
    final sharedList = sharedToInstall.toList()..sort();
    
    // Show what will be installed
    logger.section('Installing core shared modules');
    var totalFiles = 0;
    for (final sharedId in sharedList) {
      final shared = registry.shared.firstWhere(
        (s) => s.id == sharedId,
        orElse: () => throw Exception('Shared module $sharedId not found'),
      );
      logger.detail('  • $sharedId (${shared.files.length} files)');
      totalFiles += shared.files.length;
    }
    logger.detail('  Total: $totalFiles files');
    print('');
    
    for (final sharedId in sharedList) {
      await installShared(sharedId);
    }
    await _updateDependencies({
      'data_widget': '^0.0.2',
      'gap': '^3.0.1',
    });
    if (themePreset != null && themePreset.isNotEmpty) {
      await applyThemeById(themePreset);
    } else if (!skipPrompts) {
      await _promptThemeSelection();
    }
    await generateAliases();
    await _updateComponentManifest();
    await _updateState();

    // Also install a few commonly used ones to be safe?
    // Or just wait for 'add' to pull them in.
    // Let's stick to theme/util for init + structure.

    logger.success('Initialization complete');
    logger.detail('Aliases written to lib/ui/shadcn/app_components.dart');
  }

  Future<void> addComponent(
    String name, {
    bool installDependencies = true,
    Set<String>? ancestry,
  }) async {
    await ensureInitFiles(allowPrompts: false);
    await _ensureConfigLoaded();
    final component = registry.getComponent(name);
    if (component == null) {
      logger.warn('Component "$name" not found');
      return;
    }

    final stack = ancestry ?? <String>{};
    if (stack.contains(component.id)) {
      logger.detail('Skipping ${component.id} (dependency cycle)');
      return;
    }
    stack.add(component.id);

    final existingTask = _componentInstallTasks[component.id];
    if (existingTask != null) {
      await existingTask;
      return;
    }

    final completer = Completer<void>();
    _componentInstallTasks[component.id] = completer.future;

    if (_installingComponentIds.contains(component.id)) {
      logger.detail('Skipping ${component.id} (already installing)');
      _componentInstallTasks.remove(component.id);
      completer.complete();
      return;
    }

    try {
      final installed = await _installedComponentIds();
      if (installed.contains(component.id)) {
        logger.detail('Skipping ${component.id} (already installed)');
        return;
      }

      logger.action('Installing ${component.name} (${component.id})');
      _installingComponentIds.add(component.id);
      // 1. Install dependencies first
      if (installDependencies) {
        for (final dep in component.dependsOn) {
          await addComponent(dep, ancestry: stack);
        }
      }

      // 2. Install shared dependencies
      for (final sharedId in component.shared) {
        await installShared(sharedId);
      }

      // 3. Install component files (bounded concurrency)
      await _installComponentFiles(component);

      // 3b. Apply platform instructions (if any)
      await _applyPlatformInstructions(component);

      // 4. Update pubspec (print instructions for now, or use dcli/automator)
      if (component.pubspec.isNotEmpty) {
        final deps = component.pubspec['dependencies'] as Map<String, dynamic>;
        await _queueDependencyUpdates(deps);
      }
      if (component.assets.isNotEmpty) {
        await _queueAssetUpdates(component.assets);
      }
      if (component.fonts.isNotEmpty) {
        await _queueFontUpdates(component.fonts);
      }
      if (component.postInstall.isNotEmpty) {
        _reportPostInstall(component);
      }
      try {
        await _writeComponentManifest(component);
      } catch (e) {
        logger.warn('Failed to write component manifest: $e');
      }
      if (!_deferAliases) {
        await generateAliases();
      }
      if (!_deferComponentManifest) {
        await _updateComponentManifest();
      }
      if (!_deferComponentManifest) {
        await _updateState();
      }
      if (!_deferDependencyUpdates) {
        await _syncDependenciesWithInstalled();
      }
      _installedComponentCache?.add(component.id);
    } catch (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
      rethrow;
    } finally {
      _installingComponentIds.remove(component.id);
      _componentInstallTasks.remove(component.id);
      stack.remove(component.id);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> installAllComponents({int concurrency = 6}) async {
    await ensureInitFiles(allowPrompts: false);
    final ids = registry.components.map((c) => c.id).toList();
    if (ids.isEmpty) {
      return;
    }

    var index = 0;
    Future<void> worker() async {
      while (true) {
        if (index >= ids.length) {
          break;
        }
        final id = ids[index++];
        await addComponent(id, installDependencies: false);
      }
    }

    final workerCount = concurrency.clamp(1, ids.length);
    await Future.wait(
      List.generate(workerCount, (_) => worker()),
    );
  }

  Future<DryRunPlan> buildDryRunPlan(
    List<String> componentIds, {
    bool includeDependencies = true,
  }) async {
    await _ensureConfigLoaded();
    final requested = componentIds.toList();
    final missing = <String>[];
    final resolved = <String, Component>{};
    final dependencyGraph = <String, List<String>>{};

    void visit(Component component, Set<String> stack) {
      if (resolved.containsKey(component.id)) {
        return;
      }
      if (stack.contains(component.id)) {
        return;
      }
      stack.add(component.id);
      resolved[component.id] = component;
      dependencyGraph[component.id] = component.dependsOn;
      if (includeDependencies) {
        for (final depId in component.dependsOn) {
          final dep = registry.getComponent(depId);
          if (dep == null) {
            missing.add(depId);
          } else {
            visit(dep, stack);
          }
        }
      }
      stack.remove(component.id);
    }

    for (final id in componentIds) {
      final component = registry.getComponent(id);
      if (component == null) {
        missing.add(id);
        continue;
      }
      visit(component, <String>{});
    }

    final shared = <String>{};
    final pubspecDependencies = <String, dynamic>{};
    final assets = <String>{};
    final fontsByFamily = <String, FontEntry>{};
    final postInstall = <String>{};
    final fileDependencies = <String>{};
    final platformChanges = <String, Set<String>>{};
    final componentFiles = <String, List<Map<String, String>>>{};
    final manifestPreview = <String, Map<String, dynamic>>{};

    for (final component in resolved.values) {
      for (final sharedId in component.shared) {
        shared.add(_normalizeSharedId(sharedId));
      }
      final deps = component.pubspec['dependencies'] as Map<String, dynamic>?;
      deps?.forEach((key, value) {
        if (value != null && !pubspecDependencies.containsKey(key)) {
          pubspecDependencies[key] = value;
        }
      });
      assets.addAll(component.assets);
      for (final font in component.fonts) {
        fontsByFamily.putIfAbsent(font.family, () => font);
      }
      postInstall.addAll(component.postInstall);

      for (final file in component.files) {
        for (final dep in file.dependsOn) {
          final label = dep.optional ? '${dep.source} (optional)' : dep.source;
          fileDependencies.add(label);
        }
      }

      component.platform.forEach((platform, entry) {
        final sections = <String>{};
        if (entry.permissions.isNotEmpty) {
          sections.add('permissions');
        }
        if (entry.infoPlist.isNotEmpty) {
          sections.add('infoPlist');
        }
        if (entry.entitlements.isNotEmpty) {
          sections.add('entitlements');
        }
        if (entry.podfile.isNotEmpty) {
          sections.add('podfile');
        }
        if (entry.gradle.isNotEmpty) {
          sections.add('gradle');
        }
        if (entry.config.isNotEmpty) {
          sections.add('config');
        }
        if (entry.notes.isNotEmpty) {
          sections.add('notes');
        }
        if (sections.isNotEmpty) {
          platformChanges
              .putIfAbsent(platform, () => <String>{})
              .addAll(sections);
        }
      });

      final fileEntries = <Map<String, String>>[];
      for (final file in component.files) {
        final destination = _resolveComponentDestination(component, file);
        fileEntries.add({
          'source': file.source,
          'destination': destination,
        });
      }
      componentFiles[component.id] = fileEntries;
      manifestPreview[component.id] = {
        'id': component.id,
        'name': component.name,
        'version': component.version,
        'tags': component.tags,
        'shared': component.shared.toList()..sort(),
        'dependsOn': component.dependsOn.toList()..sort(),
        'files': component.files.map((f) => f.source).toList()..sort(),
        'registryRoot': registry.registryRoot.root,
      };
    }

    final components = resolved.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return DryRunPlan(
      requested: requested,
      missing: missing.toSet().toList()..sort(),
      components: components,
      dependencyGraph: dependencyGraph,
      shared: shared.toList()..sort(),
      pubspecDependencies: pubspecDependencies,
      assets: assets.toList()..sort(),
      fonts: fontsByFamily.values.toList()
        ..sort((a, b) => a.family.compareTo(b.family)),
      postInstall: postInstall.toList()..sort(),
      fileDependencies: fileDependencies.toList()..sort(),
      platformChanges: platformChanges,
      componentFiles: componentFiles,
      manifestPreview: manifestPreview,
    );
  }

  void printDryRunPlan(DryRunPlan plan) {
    logger.header('Dry Run Preview');

    void section(String title, List<String> lines) {
      if (lines.isEmpty) {
        return;
      }
      final countLabel = lines.length == 1 ? '1 item' : '${lines.length} items';
      print('\n$title ($countLabel)');
      print('─' * (title.length + countLabel.length + 3));
      for (final line in lines) {
        print('  • $line');
      }
    }

    section('Requested components', plan.requested);
    section('Missing components', plan.missing);

    if (plan.components.isNotEmpty) {
      final componentLines = <String>[];
      for (final component in plan.components) {
        final deps = plan.dependencyGraph[component.id] ?? const [];
        if (deps.isEmpty) {
          componentLines.add(component.id);
        } else {
          componentLines
              .add('${component.id}  ↳ dependsOn: ${deps.join(', ')}');
        }
      }
      section('Components to install', componentLines);
    }

    section('Shared modules', plan.shared);

    if (plan.pubspecDependencies.isNotEmpty) {
      final keys = plan.pubspecDependencies.keys.toList()..sort();
      final dependencyLines = <String>[];
      for (final key in keys) {
        dependencyLines.add('$key: ${plan.pubspecDependencies[key]}');
      }
      section('Pubspec dependencies', dependencyLines);
    }

    section('Assets', plan.assets);

    if (plan.fonts.isNotEmpty) {
      final fontLines = <String>[];
      for (final font in plan.fonts) {
        fontLines.add(font.family);
        for (final fontAsset in font.fonts) {
          final weight =
              fontAsset.weight != null ? ' weight ${fontAsset.weight}' : '';
          final style = fontAsset.style != null ? ' ${fontAsset.style}' : '';
          fontLines.add('  - ${fontAsset.asset}$weight$style');
        }
      }
      section('Fonts', fontLines);
    }

    section('File dependencies', plan.fileDependencies);

    if (plan.componentFiles.isNotEmpty) {
      final fileLines = <String>[];
      final ids = plan.componentFiles.keys.toList()..sort();
      for (final id in ids) {
        final entries = plan.componentFiles[id] ?? const [];
        for (final entry in entries) {
          fileLines.add('$id: ${entry['source']} -> ${entry['destination']}');
        }
      }
      section('File destinations', fileLines);
    }

    if (plan.manifestPreview.isNotEmpty) {
      final previewLines = <String>[];
      final ids = plan.manifestPreview.keys.toList()..sort();
      for (final id in ids) {
        final entry = plan.manifestPreview[id] ?? const {};
        final version = entry['version'] ?? 'unknown';
        final tags = (entry['tags'] as List?)?.join(', ') ?? '';
        previewLines.add('$id: version=$version tags=[$tags]');
      }
      section('Manifest preview', previewLines);
    }

    if (plan.platformChanges.isNotEmpty) {
      final platformLines = <String>[];
      final platforms = plan.platformChanges.keys.toList()..sort();
      for (final platform in platforms) {
        final sections = plan.platformChanges[platform]!.toList()..sort();
        platformLines.add('$platform: ${sections.join(', ')}');
      }
      section('Platform changes', platformLines);
    }

    section('Post-install notes', plan.postInstall);
  }

  Future<void> installShared(String id) async {
    await _ensureConfigLoaded();
    final resolvedId = _normalizeSharedId(id);
    final sharedMatches = registry.shared.where((s) => s.id == resolvedId);
    if (sharedMatches.isEmpty) {
      final fallbackComponent = registry.getComponent(resolvedId);
      if (fallbackComponent != null) {
        await addComponent(resolvedId);
        return;
      }
      logger.warn('Shared item "$id" not found');
      return;
    }
    final sharedItem = sharedMatches.first;

    if (_installedSharedCache.contains(resolvedId)) {
      return;
    }

    if (_installingSharedIds.contains(resolvedId)) {
      return;
    }

    _installingSharedIds.add(resolvedId);
    try {
      final sharedDeps = await _loadSharedDependencies(resolvedId);
      for (final depId in sharedDeps) {
        if (depId == resolvedId) {
          continue;
        }
        await installShared(depId);
      }
      for (final file in sharedItem.files) {
        await _installFileWithDependencies(
          file,
          sharedItem.files,
          sharedId: sharedItem.id,
        );
      }

      _installedSharedCache.add(resolvedId);
    } finally {
      _installingSharedIds.remove(resolvedId);
    }
  }

  Future<void> ensureInitFiles({bool allowPrompts = false}) async {
    if (_initFilesEnsured) {
      return;
    }
    _initFilesEnsured = true;
    final configFile = ShadcnConfig.configFile(targetDir);
    final hasConfig = await configFile.exists();
    if (!hasConfig) {
      if (allowPrompts) {
        await _ensureConfig();
      } else {
        await _ensureConfigDefaults();
      }
    } else {
      await _ensureConfigLoaded();
    }

    final themeFile = File(_colorSchemeFilePath);
    if (!themeFile.existsSync()) {
      const coreShared = [
        'theme',
        'util',
        'color_extensions',
        'form_control',
        'form_value_supplier',
      ];
      final sharedToInstall = (await _resolveSharedDependencyClosure(
        coreShared.toSet(),
      ))
        ..removeWhere((id) => id.isEmpty);
      final sharedList = sharedToInstall.toList()..sort();
      for (final sharedId in sharedList) {
        await installShared(sharedId);
      }
      await _updateDependencies({
        'data_widget': '^0.0.2',
        'gap': '^3.0.1',
      });
    }
  }

  Future<void> runBulkInstall(Future<void> Function() action) async {
    final previousAlias = _deferAliases;
    final previousDeps = _deferDependencyUpdates;
    final previousManifest = _deferComponentManifest;
    _deferAliases = true;
    _deferDependencyUpdates = true;
    _deferComponentManifest = true;
    try {
      await action();
    } finally {
      _deferAliases = previousAlias;
      _deferDependencyUpdates = previousDeps;
      _deferComponentManifest = previousManifest;
      if (_pendingDependencies.isNotEmpty) {
        final pending = Map<String, dynamic>.from(_pendingDependencies);
        _pendingDependencies.clear();
        await _updateDependencies(pending);
      }
      if (_pendingAssets.isNotEmpty) {
        final pending = _pendingAssets.toList()..sort();
        _pendingAssets.clear();
        await _updateAssets(pending);
      }
      if (_pendingFonts.isNotEmpty) {
        final pending = List<FontEntry>.from(_pendingFonts);
        _pendingFonts.clear();
        await _updateFonts(pending);
      }
      await _syncDependenciesWithInstalled();
      if (!_deferAliases) {
        await generateAliases();
      }
      if (!_deferComponentManifest) {
        await _updateComponentManifest();
      }
      await _updateState();
    }
  }

  Future<void> _queueDependencyUpdates(Map<String, dynamic> deps) async {
    if (!_deferDependencyUpdates) {
      await _updateDependencies(deps);
      return;
    }
    deps.forEach((key, value) {
      if (value == null) {
        return;
      }
      _pendingDependencies[key] = value;
    });
  }

  Future<void> _queueAssetUpdates(List<String> assets) async {
    if (assets.isEmpty) {
      return;
    }
    if (!_deferDependencyUpdates) {
      await _updateAssets(assets);
      return;
    }
    _pendingAssets.addAll(assets);
  }

  Future<void> _queueFontUpdates(List<FontEntry> fonts) async {
    if (fonts.isEmpty) {
      return;
    }
    if (!_deferDependencyUpdates) {
      await _updateFonts(fonts);
      return;
    }
    _pendingFonts.addAll(fonts);
  }

  String _normalizeSharedId(String id) {
    switch (id) {
      case 'utils':
        return 'util';
      default:
        return id;
    }
  }

  Future<Set<String>> _resolveSharedDependencyClosure(
    Set<String> seedIds,
  ) async {
    final resolved = <String>{};
    final pending = <String>[];
    for (final id in seedIds) {
      pending.add(_normalizeSharedId(id));
    }
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!resolved.add(id)) {
        continue;
      }
      final deps = await _loadSharedDependencies(id);
      for (final dep in deps) {
        final normalized = _normalizeSharedId(dep);
        if (!resolved.contains(normalized)) {
          pending.add(normalized);
        }
      }
    }
    return resolved;
  }

  Future<Set<String>> _loadSharedDependencies(String sharedId) async {
    final cached = _sharedDependencyCache[sharedId];
    if (cached != null) {
      return cached;
    }

    final matches = registry.shared.where((s) => s.id == sharedId);
    if (matches.isEmpty) {
      _sharedDependencyCache[sharedId] = {};
      return {};
    }

    final deps = <String>{};
    final sharedItem = matches.first;
    for (final file in sharedItem.files) {
      if (!file.source.endsWith('.dart')) {
        continue;
      }
      try {
        final bytes = await registry.readSourceBytes(file.source);
        final content = utf8.decode(bytes);
        final dir = p.posix.dirname(_normalizeRegistryPath(file.source));
        for (final line in content.split('\n')) {
          if (_partOfDirectiveRegex.hasMatch(line)) {
            continue;
          }
          final match = _importDirectiveRegex.firstMatch(line);
          if (match == null) {
            continue;
          }
          final importPath = match.group(2);
          if (importPath == null || !_isRelativeImport(importPath)) {
            continue;
          }
          final resolved = p.posix.normalize(p.posix.join(dir, importPath));
          final owner = _lookupRegistryFileOwner(resolved);
          if (owner != null && owner.isShared) {
            deps.add(owner.id);
          }
        }
      } catch (_) {
        continue;
      }
    }

    _sharedDependencyCache[sharedId] = deps;
    return deps;
  }

  bool _isRelativeImport(String path) {
    return path.startsWith('.');
  }

  Map<String, _RegistryFileOwner> _buildRegistryFileIndex() {
    final cached = _registryFileIndex;
    if (cached != null) {
      return cached;
    }
    final index = <String, _RegistryFileOwner>{};
    for (final sharedItem in registry.shared) {
      for (final file in sharedItem.files) {
        final normalized = _normalizeRegistryPath(file.source);
        index[normalized] = _RegistryFileOwner.shared(sharedItem.id, file);
      }
    }
    for (final component in registry.components) {
      for (final file in component.files) {
        final normalized = _normalizeRegistryPath(file.source);
        index[normalized] = _RegistryFileOwner.component(component.id, file);
      }
    }
    _registryFileIndex = index;
    return index;
  }

  _RegistryFileOwner? _lookupRegistryFileOwner(String source) {
    final normalized = _normalizeRegistryPath(source);
    return _buildRegistryFileIndex()[normalized];
  }

  String _normalizeRegistryPath(String source) {
    final normalized = source.replaceAll('\\', '/');
    return p.posix.normalize(normalized);
  }

  Future<void> _updateComponentManifest() async {
    await _ensureConfigLoaded();
    final installPath = _installPath(_cachedConfig);
    final manifestFile =
        File(p.join(targetDir, installPath, 'components.json'));
    final installed = await _installedComponentIds();
    if (installed.isEmpty) {
      if (await manifestFile.exists()) {
        await manifestFile.delete();
      }
      await _clearComponentManifests();
      return;
    }
    final requiredDeps = _collectRequiredDependencies(installed);
    final installedList = installed.toList()..sort();
    final componentMeta = <String, dynamic>{};
    for (final id in installedList) {
      final component = registry.getComponent(id);
      if (component == null) {
        continue;
      }
      componentMeta[id] = {
        'version': component.version,
        'tags': component.tags,
      };
    }
    final payload = {
      'schemaVersion': 1,
      'installPath': installPath,
      'sharedPath': _sharedPath(_cachedConfig),
      'installed': installedList,
      'managedDependencies': requiredDeps.keys.toList()..sort(),
      'componentMeta': componentMeta,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    if (!await manifestFile.parent.exists()) {
      await manifestFile.parent.create(recursive: true);
    }
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Directory _componentManifestDirectory() {
    return Directory(p.join(targetDir, '.shadcn', 'components'));
  }

  Future<void> _writeComponentManifest(Component component) async {
    final dir = _componentManifestDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, '${component.id}.json'));
    String? installedAt;
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        if (data is Map<String, dynamic>) {
          final value = data['installedAt']?.toString();
          if (value != null && value.isNotEmpty) {
            installedAt = value;
          }
        }
      } catch (_) {
        installedAt = null;
      }
    }
    final payload = {
      'schemaVersion': 1,
      'id': component.id,
      'name': component.name,
      'version': component.version,
      'tags': component.tags,
      'installedAt': installedAt ?? DateTime.now().toUtc().toIso8601String(),
      'shared': component.shared.toList()..sort(),
      'dependsOn': component.dependsOn.toList()..sort(),
      'files': component.files.map((f) => f.source).toList()..sort(),
      'registryRoot': registry.registryRoot.root,
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<void> _removeComponentManifest(String componentId) async {
    final file = File(
      p.join(_componentManifestDirectory().path, '$componentId.json'),
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _clearComponentManifests() async {
    final dir = _componentManifestDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> _refreshComponentManifests() async {
    final installed = await _installedComponentIds();
    for (final id in installed) {
      final component = registry.getComponent(id);
      if (component == null) {
        continue;
      }
      await _writeComponentManifest(component);
    }
  }

  Map<String, dynamic> _collectRequiredDependencies(Set<String> installed) {
    final required = <String, dynamic>{};
    for (final id in installed) {
      final component = registry.getComponent(id);
      if (component == null || component.pubspec.isEmpty) {
        continue;
      }
      final deps = component.pubspec['dependencies'] as Map<String, dynamic>?;
      if (deps == null) {
        continue;
      }
      deps.forEach((key, value) {
        if (!required.containsKey(key)) {
          required[key] = value;
        }
      });
    }
    return required;
  }

  Future<void> _syncDependenciesWithInstalled({
    Set<String>? installedOverride,
    Set<String>? managedOverride,
  }) async {
    final pubspecFile = File(p.join(targetDir, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return;
    }
    final installed = installedOverride ?? await _installedComponentIds();
    final required = _collectRequiredDependencies(installed);

    final managedDeps = managedOverride ?? await _loadManagedDependencies();
    final registryDeps = _collectAllRegistryDependencies();
    final toRemove = (managedDeps.isEmpty ? registryDeps : managedDeps)
        .difference(required.keys.toSet());

    // Batch remove dependencies in a single command
    if (toRemove.isNotEmpty) {
      logger.info('Removing dependencies: ${toRemove.join(', ')}');
      final result = await Process.run(
        'dart',
        ['pub', 'remove', ...toRemove],
        workingDirectory: targetDir,
      );
      if (result.exitCode != 0) {
        // Some packages might not exist, that's fine
        logger
            .detail('Some dependencies could not be removed: ${result.stderr}');
      }
    }

    // Collect dependencies to add (filter out already existing ones)
    final lines = pubspecFile.readAsLinesSync();
    final toAdd = <String>[];
    for (final entry in required.entries) {
      final dep = entry.key;
      final version = entry.value;
      final alreadyExists = lines.any((l) => l.trim().startsWith('$dep:'));
      if (alreadyExists) {
        continue;
      }
      // Format: package:version or just package
      if (version is String && version.isNotEmpty) {
        final cleanVersion =
            version.startsWith('^') ? version.substring(1) : version;
        toAdd.add('$dep:$cleanVersion');
      } else {
        toAdd.add(dep);
      }
    }

    // Batch add dependencies in a single command
    if (toAdd.isNotEmpty) {
      logger.info('Adding dependencies: ${toAdd.join(', ')}');
      final result = await Process.run(
        'dart',
        ['pub', 'add', ...toAdd],
        workingDirectory: targetDir,
      );
      if (result.exitCode != 0) {
        logger.warn('Some dependencies could not be added: ${result.stderr}');
      }
    }
  }

  Future<Set<String>> _loadManagedDependencies() async {
    final state = await ShadcnState.load(targetDir);
    return state.managedDependencies?.toSet() ?? {};
  }

  Set<String> _collectAllRegistryDependencies() {
    final deps = <String>{};
    for (final component in registry.components) {
      if (component.pubspec.isEmpty) {
        continue;
      }
      final map = component.pubspec['dependencies'] as Map<String, dynamic>?;
      if (map == null) {
        continue;
      }
      deps.addAll(map.keys);
    }
    deps.addAll(_coreInitDependencies);
    return deps;
  }

  static const Set<String> _coreInitDependencies = {
    'data_widget',
    'gap',
  };

  Future<void> _updateState() async {
    await _ensureConfigLoaded();
    final config = _cachedConfig ?? const ShadcnConfig();
    final installed = await _installedComponentIds();
    final required = _collectRequiredDependencies(installed);
    final managed = <String>{...required.keys, ..._coreInitDependencies};
    await ShadcnState.save(
      targetDir,
      ShadcnState(
        installPath: _installPath(config),
        sharedPath: _sharedPath(config),
        themeId: config.themeId,
        managedDependencies: managed.toList()..sort(),
      ),
    );
  }

  Future<void> syncFromConfig() async {
    await ensureInitFiles(allowPrompts: false);
    await _ensureConfigLoaded();
    final config = _cachedConfig ?? const ShadcnConfig();
    final state = await ShadcnState.load(targetDir);

    final newInstall = _installPath(config);
    final newShared = _sharedPath(config);

    if (state.installPath != null && state.installPath != newInstall) {
      final oldDir = Directory(p.join(targetDir, state.installPath!));
      final newDir = Directory(p.join(targetDir, newInstall));
      if (oldDir.existsSync()) {
        if (!newDir.parent.existsSync()) {
          newDir.parent.createSync(recursive: true);
        }
        oldDir.renameSync(newDir.path);
      }
    }

    if (state.sharedPath != null && state.sharedPath != newShared) {
      final oldShared = Directory(p.join(targetDir, state.sharedPath!));
      final newSharedDir = Directory(p.join(targetDir, newShared));
      if (oldShared.existsSync()) {
        if (!newSharedDir.parent.existsSync()) {
          newSharedDir.parent.createSync(recursive: true);
        }
        oldShared.renameSync(newSharedDir.path);
      }
    }

    if (config.themeId != null && config.themeId != state.themeId) {
      await applyThemeById(config.themeId!);
    }

    await _updateComponentManifest();
    await _refreshComponentManifests();
    await generateAliases();
    await _updateState();
    logger.success('Sync complete');
  }

  Future<void> _installFile(RegistryFile file) async {
    await _ensureConfigLoaded();
    final destFile = File(_resolveDestinationPath(file.destination));

    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    if (!_shouldInstallFile(file.destination)) {
      logger.detail('Skipping optional ${file.destination}');
      return;
    }

    logger.detail('Writing ${destFile.path}');
    // In real implementation, we might need to rewrite imports if they change.
    // But our registry structure design (relative imports or absolute package imports?)
    // The source code in registry/components/... usually imports dependencies.
    // If they import via 'package:shadcn_flutter/...', we need to rewrite to relative or project-local paths.
    // Currently, the registry source files likely import from registry/shared/...

    // Let's simple-copy first, and see if we need import rewriting.
    // If the files in registry/ use relative imports like `../../shared/theme.dart`, that might break if structure changes.
    // But if we preserve the structure 'components/foo/foo.dart' and 'shared/theme/theme.dart', relative imports might ok.
    // Wait, registry/components/button/button.dart might import registry/shared/theme/theme.dart.
    // That is `../../shared/theme/theme.dart`.
    // In target: `lib/ui/shadcn/components/button/button.dart` and `lib/ui/shadcn/shared/theme/theme.dart`.
    // Depth is same. Relative import should work IF the registry source uses relative imports.
    // Let's verify that later.

    final bytes = await registry.readSourceBytes(file.source);
    await destFile.writeAsBytes(bytes, flush: true);
  }

  Future<void> _installComponentFile(
    Component component,
    RegistryFile file,
    List<RegistryFile> availableFiles,
  ) async {
    await _ensureConfigLoaded();
    await _installFileDependencies(component, file, availableFiles);
    final destination = _resolveComponentDestination(component, file);
    final patched = RegistryFile(
      source: file.source,
      destination: destination,
      dependsOn: file.dependsOn,
    );
    await _installFile(patched);
  }

  Future<void> _installComponentFiles(Component component) async {
    final files = component.files;
    if (files.isEmpty) {
      return;
    }
    var index = 0;
    Future<void> worker() async {
      while (true) {
        if (index >= files.length) {
          return;
        }
        final file = files[index++];
        await _installComponentFile(component, file, files);
      }
    }

    final workerCount = _fileCopyConcurrency.clamp(1, files.length);
    await Future.wait(
      List.generate(workerCount, (_) => worker()),
    );
  }

  Future<void> _installFileWithDependencies(
    RegistryFile file,
    List<RegistryFile> availableFiles, {
    String? sharedId,
  }) async {
    await _ensureConfigLoaded();
    await _installSharedFileDependencies(
      file,
      availableFiles,
      sharedId: sharedId,
    );
    await _installFile(file);
  }

  Future<void> _installFileDependencies(
    Component component,
    RegistryFile file,
    List<RegistryFile> availableFiles,
  ) async {
    if (file.dependsOn.isEmpty) {
      return;
    }
    for (final dep in file.dependsOn) {
      final normalizedSource = _normalizeRegistryPath(dep.source);
      final mapping = _findFileMapping(availableFiles, normalizedSource);
      final owner = _lookupRegistryFileOwner(normalizedSource);

      if (owner != null && owner.isShared) {
        await installShared(owner.id);
        continue;
      }

      if (owner != null && owner.isComponent && owner.id != component.id) {
        if (!dep.optional) {
          logger.warn(
            'File dependency ${dep.source} belongs to component ${owner.id}.',
          );
        }
        continue;
      }

      final resolvedMapping = mapping ??
          owner?.file ??
          RegistryFile(source: dep.source, destination: dep.source);
      final destination =
          _resolveComponentDestination(component, resolvedMapping);
      final target = File(destination);
      if (await target.exists()) {
        continue;
      }
      if (!await _safeInstallDependency(
          component, resolvedMapping, availableFiles)) {
        if (!dep.optional) {
          logger.warn('Missing dependency file: ${dep.source}');
        }
      }
    }
  }

  Future<void> _installSharedFileDependencies(
    RegistryFile file,
    List<RegistryFile> availableFiles, {
    String? sharedId,
  }) async {
    if (file.dependsOn.isEmpty) {
      return;
    }
    for (final dep in file.dependsOn) {
      final normalizedSource = _normalizeRegistryPath(dep.source);
      final mapping = _findFileMapping(availableFiles, normalizedSource);
      final owner = _lookupRegistryFileOwner(normalizedSource);

      if (owner != null && owner.isShared && owner.id != sharedId) {
        await installShared(owner.id);
        continue;
      }

      if (owner != null && owner.isComponent) {
        if (!dep.optional) {
          logger.warn(
            'Shared file dependency ${dep.source} belongs to component ${owner.id}.',
          );
        }
        continue;
      }

      final resolvedMapping = mapping ??
          owner?.file ??
          RegistryFile(source: dep.source, destination: dep.source);
      final target = File(_resolveDestinationPath(resolvedMapping.destination));
      if (await target.exists()) {
        continue;
      }
      await _installFile(resolvedMapping);
    }
  }

  Future<bool> _safeInstallDependency(
    Component component,
    RegistryFile mapping,
    List<RegistryFile> availableFiles,
  ) async {
    try {
      await _installComponentFile(component, mapping, availableFiles);
      return true;
    } catch (_) {
      return false;
    }
  }

  RegistryFile? _findFileMapping(
    List<RegistryFile> availableFiles,
    String source,
  ) {
    final normalizedSource = _normalizeRegistryPath(source);
    for (final file in availableFiles) {
      if (_normalizeRegistryPath(file.source) == normalizedSource) {
        return file;
      }
    }
    return null;
  }

  String _resolveComponentDestination(Component component, RegistryFile file) {
    final config = _cachedConfig;
    final installPath = _installPath(config);
    final source = file.source.replaceAll('\\', '/');

    const registryPrefix = 'registry/';
    if (source.startsWith(registryPrefix)) {
      final relative = source.substring(registryPrefix.length);
      return p.join(targetDir, installPath, relative);
    }

    return _resolveDestinationPath(file.destination);
  }

  Map<String, Map<String, String>> _platformTargets(ShadcnConfig? config) {
    final defaults = <String, Map<String, String>>{
      'android': {
        'permissions': 'android/app/src/main/AndroidManifest.xml',
        'gradle': 'android/app/build.gradle',
        'notes': '.shadcn/platform/android.md',
      },
      'ios': {
        'infoPlist': 'ios/Runner/Info.plist',
        'podfile': 'ios/Podfile',
        'notes': '.shadcn/platform/ios.md',
      },
      'macos': {
        'entitlements': 'macos/Runner/DebugProfile.entitlements',
        'notes': '.shadcn/platform/macos.md',
      },
      'desktop': {
        'config': '.shadcn/platform/desktop.md',
      },
    };
    final overrides = config?.platformTargets ?? const {};
    final merged = <String, Map<String, String>>{};
    for (final entry in defaults.entries) {
      merged[entry.key] = Map<String, String>.from(entry.value);
    }
    overrides.forEach((platform, value) {
      merged.putIfAbsent(platform, () => {});
      merged[platform]!.addAll(value);
    });
    return merged;
  }

  Future<void> _applyPlatformInstructions(Component component) async {
    if (component.platform.isEmpty) {
      return;
    }
    await _ensureConfigLoaded();
    final targets = _platformTargets(_cachedConfig);
    for (final entry in component.platform.entries) {
      final platform = entry.key;
      final instructions = entry.value;
      final platformTargets = targets[platform] ?? const {};

      await _writePlatformSection(
        platform: platform,
        section: 'permissions',
        targetPath: platformTargets['permissions'],
        lines: instructions.permissions,
      );
      await _writePlatformSection(
        platform: platform,
        section: 'gradle',
        targetPath: platformTargets['gradle'],
        lines: instructions.gradle,
      );
      await _writePlatformSection(
        platform: platform,
        section: 'podfile',
        targetPath: platformTargets['podfile'],
        lines: instructions.podfile,
      );
      await _writePlatformSection(
        platform: platform,
        section: 'entitlements',
        targetPath: platformTargets['entitlements'],
        lines: instructions.entitlements,
      );
      await _writePlatformSection(
        platform: platform,
        section: 'config',
        targetPath: platformTargets['config'],
        lines: instructions.config,
      );
      await _writePlatformSection(
        platform: platform,
        section: 'notes',
        targetPath: platformTargets['notes'],
        lines: instructions.notes,
      );

      if (instructions.infoPlist.isNotEmpty) {
        final plistLines = instructions.infoPlist.entries
            .map((e) => '${e.key}: ${e.value}')
            .toList();
        await _writePlatformSection(
          platform: platform,
          section: 'infoPlist',
          targetPath: platformTargets['infoPlist'],
          lines: plistLines,
        );
      }
    }
  }

  Future<void> _writePlatformSection({
    required String platform,
    required String section,
    required String? targetPath,
    required List<String> lines,
  }) async {
    if (lines.isEmpty) {
      return;
    }
    if (targetPath == null || targetPath.isEmpty) {
      logger.detail('No target configured for $platform/$section.');
      return;
    }
    final fullPath = p.join(targetDir, targetPath);
    final file = File(fullPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    final marker = 'shadcn_flutter_cli:$platform:$section';
    final existing = await file.exists() ? await file.readAsString() : '';
    if (existing.contains(marker)) {
      return;
    }
    final block = _formatPlatformBlock(fullPath, marker, lines);
    await file.writeAsString(existing + block);
    logger.detail('Updated $targetPath ($platform/$section)');
  }

  String _formatPlatformBlock(String path, String marker, List<String> lines) {
    final ext = p.extension(path).toLowerCase();
    final isXml = ext == '.xml' || ext == '.plist' || ext == '.entitlements';
    final isMd = ext == '.md';
    if (isXml) {
      final buffer = StringBuffer();
      buffer.writeln('\n<!-- $marker:start -->');
      for (final line in lines) {
        buffer.writeln('<!-- $line -->');
      }
      buffer.writeln('<!-- $marker:end -->\n');
      return buffer.toString();
    }
    if (isMd) {
      final buffer = StringBuffer();
      buffer.writeln('\n## $marker');
      for (final line in lines) {
        buffer.writeln('- $line');
      }
      buffer.writeln('');
      return buffer.toString();
    }
    final buffer = StringBuffer();
    buffer.writeln('\n// $marker:start');
    for (final line in lines) {
      buffer.writeln('// $line');
    }
    buffer.writeln('// $marker:end\n');
    return buffer.toString();
  }

  void _reportPostInstall(Component component) {
    logger.section('Post-install notes for ${component.name}');
    for (final line in component.postInstall) {
      logger.info('  • $line');
    }
  }

  Future<void> generateAliases() async {
    await _ensureConfigLoaded();
    final config = _cachedConfig ?? const ShadcnConfig();
    final prefix = config.classPrefix;
    if (prefix == null || prefix.isEmpty) {
      return;
    }
    final componentsDir = Directory(
      p.join(targetDir, _installPath(config), 'components'),
    );
    if (!componentsDir.existsSync()) {
      return;
    }

    final aliases = <String, _AliasEntry>{};
    final imports = <String>{};
    final componentDirs = <String>{};
    for (final entity in componentsDir.listSync(recursive: true)) {
      if (entity is! Directory) {
        continue;
      }
      final dir = entity;
      final name = p.basename(dir.path);
      final mainFile = File(p.join(dir.path, '$name.dart'));
      if (mainFile.existsSync()) {
        componentDirs.add(dir.path);
      }
    }

    for (final dirPath in componentDirs) {
      final componentDir = Directory(dirPath);
      final componentName = p.basename(componentDir.path);
      final mainFile = File(p.join(componentDir.path, '$componentName.dart'));
      if (!mainFile.existsSync()) {
        continue;
      }
      final relativeDir = p.relative(
        componentDir.path,
        from: p.join(targetDir, _installPath(config)),
      );
      final importPath =
          p.join(relativeDir, '$componentName.dart').replaceAll('\\', '/');
      imports.add(importPath);
      final contents = <String>[];
      final mainContent = mainFile.readAsStringSync();
      contents.add(mainContent);
      for (final part in _partRegex.allMatches(mainContent)) {
        final partPath = part.group(1);
        if (partPath == null) {
          continue;
        }
        final partFile = File(p.join(componentDir.path, partPath));
        if (partFile.existsSync()) {
          contents.add(partFile.readAsStringSync());
        }
      }
      final matches =
          contents.expand((content) => _classRegex.allMatches(content));
      for (final match in matches) {
        final className = match.group(2);
        if (className == null || className.startsWith('_')) {
          continue;
        }
        final typeParams = match.group(3);
        final aliasName = '$prefix$className';
        aliases.putIfAbsent(
          aliasName,
          () => _AliasEntry(className, typeParams),
        );
      }
    }

    final output = StringBuffer()
      ..writeln('// Generated by flutter_shadcn. Do not edit by hand.')
      ..writeln('library app_components;')
      ..writeln('');
    for (final importPath in imports.toList()..sort()) {
      output.writeln("import '$importPath';");
    }
    output.writeln('');
    final aliasEntries = aliases.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in aliasEntries) {
      final aliasName = entry.key;
      final className = entry.value.className;
      final typeParams = entry.value.typeParams;
      if (typeParams == null || typeParams.isEmpty) {
        output.writeln('typedef $aliasName = $className;');
      } else {
        final typeArgs = _typeArgsFromParams(typeParams);
        output.writeln('typedef $aliasName$typeParams = $className$typeArgs;');
      }
    }

    final outputFile = File(
      p.join(targetDir, _installPath(config), 'app_components.dart'),
    );
    await outputFile.writeAsString(output.toString());
  }

  Future<void> _promptThemeSelection() async {
    await _interactiveThemeSelection(skipIfConfigured: true);
  }

  Future<void> chooseTheme() async {
    await _interactiveThemeSelection(skipIfConfigured: false);
  }

  Future<void> listThemes() async {
    final presets = await loadThemePresets();
    if (presets.isEmpty) {
      logger.info('No theme presets available.');
      return;
    }
    final config = await ShadcnConfig.load(targetDir);
    final currentTheme = config.themeId;
    logger.info('Installed theme presets:');
    for (var i = 0; i < presets.length; i++) {
      final preset = presets[i];
      final marker = preset.id == currentTheme ? ' (current)' : '';
      logger.info('  ${i + 1}) ${preset.name} (${preset.id})$marker');
    }
  }

  Future<void> applyThemeById(String identifier) async {
    final presets = await loadThemePresets();
    if (presets.isEmpty) {
      logger.info('No theme presets available.');
      return;
    }
    final preset = _findPreset(identifier, presets);
    if (preset == null) {
      logger.warn(
        'Theme "$identifier" not found. Use "--list" to view available presets.',
      );
      return;
    }
    await _applyThemePreset(preset);
  }

  Future<void> applyThemeFromFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      logger.warn('Theme file not found: $filePath');
      return;
    }
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) {
        logger.warn('Theme file must contain a JSON object.');
        return;
      }
      await applyThemeFromJson(data, sourceLabel: filePath);
    } catch (e) {
      logger.warn('Failed to read theme file: $e');
    }
  }

  Future<void> applyThemeFromUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      logger.warn('Theme URL must be a valid http/https URL.');
      return;
    }
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        logger
            .warn('Failed to fetch theme URL (status ${response.statusCode}).');
        return;
      }
      final content = await response.transform(utf8.decoder).join();
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) {
        logger.warn('Theme URL must return a JSON object.');
        return;
      }
      await applyThemeFromJson(data, sourceLabel: url);
    } catch (e) {
      logger.warn('Failed to fetch theme URL: $e');
    } finally {
      client.close();
    }
  }

  Future<void> applyThemeFromJson(
    Map<String, dynamic> data, {
    String? sourceLabel,
  }) async {
    final idRaw = data['id']?.toString().trim();
    final nameRaw = data['name']?.toString().trim();
    final id = (idRaw == null || idRaw.isEmpty) ? 'custom' : idRaw;
    final name = (nameRaw == null || nameRaw.isEmpty) ? 'Custom' : nameRaw;
    final light = _parseThemeColors(data['light'], 'light');
    final dark = _parseThemeColors(data['dark'], 'dark');
    if (light == null || dark == null) {
      logger.warn('Theme JSON must include "light" and "dark" color maps.');
      return;
    }
    final preset = RegistryThemePresetData(
      id: id,
      name: name,
      light: light,
      dark: dark,
    );
    await _applyThemePreset(preset);
    if (sourceLabel != null && sourceLabel.isNotEmpty) {
      logger.detail('Applied custom theme from: $sourceLabel');
    }
  }

  Map<String, String>? _parseThemeColors(Object? raw, String label) {
    if (raw is! Map) {
      logger.warn('Theme "$label" must be an object of key/value colors.');
      return null;
    }
    final result = <String, String>{};
    raw.forEach((key, value) {
      if (key == null) {
        return;
      }
      final name = key.toString();
      if (name.isEmpty || value == null) {
        return;
      }
      result[name] = value.toString();
    });
    if (result.isEmpty) {
      logger.warn('Theme "$label" contains no color entries.');
      return null;
    }
    return result;
  }

  Future<void> _interactiveThemeSelection(
      {required bool skipIfConfigured}) async {
    final presets = await loadThemePresets();
    if (presets.isEmpty) {
      return;
    }
    if (skipIfConfigured) {
      final config = await ShadcnConfig.load(targetDir);
      if (config.themeId != null && config.themeId!.isNotEmpty) {
        return;
      }
    }
    final config = await ShadcnConfig.load(targetDir);
    logger.info('Select a starter theme (press Enter to skip):');
    for (var i = 0; i < presets.length; i++) {
      final preset = presets[i];
      final isCurrent = preset.id == config.themeId;
      final suffix = isCurrent ? ' (current)' : '';
      logger.info('  ${i + 1}) ${preset.name} (${preset.id})$suffix');
    }
    stdout.write('Theme number: ');
    final input = stdin.readLineSync();
    if (input == null || input.trim().isEmpty) {
      logger.info('Skipping theme selection.');
      return;
    }
    final trimmed = input.trim();
    RegistryThemePresetData? chosen;
    final index = int.tryParse(trimmed);
    if (index != null && index >= 1 && index <= presets.length) {
      chosen = presets[index - 1];
    } else {
      chosen = _findPreset(trimmed, presets);
    }
    if (chosen == null) {
      logger.warn('Invalid selection. Skipping theme selection.');
      return;
    }
    await _applyThemePreset(chosen);
  }

  Future<void> _applyThemePreset(RegistryThemePresetData preset) async {
    await _ensureConfigLoaded();
    final themeFile = File(_colorSchemeFilePath);
    if (!themeFile.existsSync()) {
      logger.warn('Theme file not found. Run "flutter_shadcn init" first.');
      return;
    }
    await applyPresetToColorScheme(filePath: themeFile.path, preset: preset);
    final config = await ShadcnConfig.load(targetDir);
    await ShadcnConfig.save(targetDir, config.copyWith(themeId: preset.id));
    logger.success('Applied theme: ${preset.name}');
  }

  RegistryThemePresetData? _findPreset(
    String identifier,
    List<RegistryThemePresetData> presets,
  ) {
    final normalized = identifier.toLowerCase();
    for (final preset in presets) {
      if (preset.id.toLowerCase() == normalized ||
          preset.name.toLowerCase() == normalized) {
        return preset;
      }
    }
    return null;
  }

  String get _colorSchemeFilePath {
    return p.join(
      targetDir,
      _sharedPath(_cachedConfig),
      'theme',
      'color_scheme.dart',
    );
  }

  Future<void> _ensureConfig() async {
    final existing = await ShadcnConfig.load(targetDir);

    final resolvedAliases = _promptAliases(existing.pathAliases ?? const {});

    final resolvedInstallPath = _promptPath(
      label:
          'Component install path inside lib/ (e.g. lib/ui/shadcn or lib/pages/docs)',
      current: existing.installPath ?? _defaultInstallPath,
      requireLib: true,
      aliases: resolvedAliases,
    );
    final resolvedSharedPath = _promptPath(
      label: 'Shared files path inside lib/ (e.g. lib/ui/shadcn/shared)',
      current: existing.sharedPath ?? _defaultSharedPath,
      requireLib: true,
      aliases: resolvedAliases,
    );

    final includeReadme = _promptYesNo(
      'Include README.md files for each component? (docs only)',
      defaultValue: existing.includeReadme ?? false,
    );
    final includeMeta = _promptYesNo(
      'Include meta.json files (used by the CLI to track installs)?',
      defaultValue: existing.includeMeta ?? true,
    );
    final includePreview = _promptYesNo(
      'Include preview.dart files (gallery previews)?',
      defaultValue: existing.includePreview ?? false,
    );

    String? prefix = existing.classPrefix;
    if (prefix == null || prefix.isEmpty) {
      final defaultPrefix = _defaultPrefix();
      stdout.write(
        'App class prefix for widgets (optional, e.g. $defaultPrefix). Enter to skip: ',
      );
      final input = stdin.readLineSync()?.trim();
      if (input != null && input.isNotEmpty) {
        prefix = _sanitizePrefix(input);
      }
    }

    await ShadcnConfig.save(
      targetDir,
      existing.copyWith(
        classPrefix: prefix,
        installPath: resolvedInstallPath,
        sharedPath: resolvedSharedPath,
        includeReadme: includeReadme,
        includeMeta: includeMeta,
        includePreview: includePreview,
        pathAliases: resolvedAliases.isEmpty ? null : resolvedAliases,
      ),
    );
    _cachedConfig = await ShadcnConfig.load(targetDir);
  }

  Future<void> _ensureConfigDefaults() async {
    final existing = await ShadcnConfig.load(targetDir);
    await ShadcnConfig.save(
      targetDir,
      existing.copyWith(
        installPath: existing.installPath ?? _defaultInstallPath,
        sharedPath: existing.sharedPath ?? _defaultSharedPath,
        includeReadme: existing.includeReadme ?? false,
        includeMeta: existing.includeMeta ?? true,
        includePreview: existing.includePreview ?? false,
      ),
    );
    _cachedConfig = await ShadcnConfig.load(targetDir);
  }

  Future<void> _ensureConfigOverrides(InitConfigOverrides overrides) async {
    final existing = await ShadcnConfig.load(targetDir);
    final normalizedInstall = _normalizePathOverride(
      overrides.installPath,
      _defaultInstallPath,
    );
    final normalizedShared = _normalizePathOverride(
      overrides.sharedPath,
      _defaultSharedPath,
    );

    final normalizedAliases = overrides.pathAliases?.map(
      (key, value) => MapEntry(key, _stripLibPrefix(value)),
    );

    await ShadcnConfig.save(
      targetDir,
      existing.copyWith(
        installPath: normalizedInstall,
        sharedPath: normalizedShared,
        includeReadme: overrides.includeReadme ?? existing.includeReadme,
        includeMeta: overrides.includeMeta ?? existing.includeMeta,
        includePreview: overrides.includePreview ?? existing.includePreview,
        classPrefix: overrides.classPrefix ?? existing.classPrefix,
        pathAliases: normalizedAliases ?? existing.pathAliases,
      ),
    );
    _cachedConfig = await ShadcnConfig.load(targetDir);
  }

  String _normalizePathOverride(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }
    final trimmed = _stripLibPrefix(value.trim());
    return p.join('lib', trimmed);
  }

  String _stripLibPrefix(String value) {
    final normalized = p.normalize(value);
    if (normalized == 'lib') {
      return '';
    }
    if (normalized.startsWith('lib${p.separator}')) {
      return normalized.substring('lib'.length + 1);
    }
    return normalized;
  }

  String _defaultPrefix() {
    final pubspec = File(p.join(targetDir, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return 'App';
    }
    final lines = pubspec.readAsLinesSync();
    for (final line in lines) {
      if (line.startsWith('name:')) {
        final name = line.split(':').sublist(1).join(':').trim();
        return _toPascalCase(name);
      }
    }
    return 'App';
  }

  String _sanitizePrefix(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.isEmpty) {
      return 'App';
    }
    return _toPascalCase(cleaned);
  }

  String _toPascalCase(String input) {
    final parts = input.split(RegExp(r'[^A-Za-z0-9]+'));
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part.isEmpty) {
        continue;
      }
      buffer.write(part[0].toUpperCase());
      buffer.write(part.substring(1));
    }
    return buffer.toString();
  }

  String _typeArgsFromParams(String params) {
    final trimmed = params.replaceAll('<', '').replaceAll('>', '');
    final parts = trimmed.split(',');
    final args = <String>[];
    for (final part in parts) {
      final token = part.trim().split(' ').first;
      if (token.isNotEmpty) {
        args.add(token);
      }
    }
    return '<${args.join(', ')}>';
  }

  Future<void> removeComponent(String name, {bool force = false}) async {
    await ensureInitFiles(allowPrompts: false);
    await _ensureConfigLoaded();
    final component = registry.getComponent(name);
    if (component == null) {
      logger.warn('Component "$name" not found');
      return;
    }

    final installed = await _installedComponentIds();
    if (!installed.contains(component.id)) {
      logger.detail('Skipping ${component.id} (not installed)');
      return;
    }

    final dependents = _dependentComponents(component.id, installed);
    if (dependents.isNotEmpty && !force) {
      logger.warn(
        'Cannot remove ${component.id}; required by ${dependents.join(', ')}',
      );
      return;
    }

    logger.action('Removing ${component.name} (${component.id})');
    for (final file in component.files) {
      final destination = _resolveComponentDestination(component, file);
      final targetFile = File(destination);
      if (await targetFile.exists()) {
        await targetFile.delete();
        _cleanupEmptyParents(targetFile.parent, component.id);
      }
    }
    await _removeComponentManifest(component.id);

    _installedComponentCache?.remove(component.id);
    if (!_deferAliases) {
      await generateAliases();
    }
    if (!_deferComponentManifest) {
      await _updateComponentManifest();
      await _updateState();
    }
    if (!_deferDependencyUpdates) {
      await _syncDependenciesWithInstalled();
    }
    // Dependency sync already handled before removal.
  }

  Future<void> removeAllComponents({bool force = true}) async {
    await ensureInitFiles(allowPrompts: false);
    await _ensureConfigLoaded();
    final managedDeps = await _loadManagedDependencies();
    final installed = await _installedComponentIds();
    if (installed.isEmpty) {
      logger.info('No installed components to remove.');
      await _removeAllInstallArtifacts();
      _installedComponentCache = null;
      if (!_deferDependencyUpdates) {
        await _syncDependenciesWithInstalled(
          installedOverride: const {},
          managedOverride: managedDeps,
        );
      }
      return;
    }
    if (!_deferDependencyUpdates) {
      await _syncDependenciesWithInstalled(
        installedOverride: const {},
        managedOverride: managedDeps,
      );
    }
    await runBulkInstall(() async {
      // Convert to list to avoid concurrent modification while iterating
      for (final id in installed.toList()) {
        await removeComponent(id, force: force);
      }
    });
    await _removeAllInstallArtifacts();
    _installedComponentCache = null;
  }

  Future<void> _removeAllInstallArtifacts() async {
    final config = _cachedConfig ?? const ShadcnConfig();
    final installRoot = Directory(p.join(targetDir, _installPath(config)));
    final sharedRoot = Directory(p.join(targetDir, _sharedPath(config)));
    final configRoot = Directory(p.join(targetDir, '.shadcn'));

    if (installRoot.existsSync()) {
      await installRoot.delete(recursive: true);
    }
    if (sharedRoot.existsSync()) {
      await sharedRoot.delete(recursive: true);
    }
    if (configRoot.existsSync()) {
      await configRoot.delete(recursive: true);
    }

    // Clean up empty parent directories (e.g., lib/ui/shadcn -> lib/ui -> lib)
    final installPath = _installPath(config);
    final parts = p.split(installPath);
    for (var i = parts.length - 1; i >= 0; i--) {
      final parentPath = p.joinAll(parts.sublist(0, i + 1));
      final parentDir = Directory(p.join(targetDir, parentPath));
      if (parentDir.existsSync()) {
        final contents = parentDir.listSync();
        if (contents.isEmpty) {
          await parentDir.delete();
          logger.detail('Removed empty directory: $parentPath');
        } else {
          break; // Stop if directory is not empty
        }
      }
    }
  }

  Future<Set<String>> _installedComponentIds() async {
    await _ensureConfigLoaded();
    if (_installedComponentCache != null) {
      return _installedComponentCache!;
    }
    final installPath = _installPath(_cachedConfig);
    final componentsDir =
        Directory(p.join(targetDir, installPath, 'components'));
    final compositesDir =
        Directory(p.join(targetDir, installPath, 'composites'));
    if (!componentsDir.existsSync() && !compositesDir.existsSync()) {
      _installedComponentCache = {};
      return _installedComponentCache!;
    }

    final installed = <String>{};
    final dirs = <Directory>[];
    if (componentsDir.existsSync()) {
      dirs.add(componentsDir);
    }
    if (compositesDir.existsSync()) {
      dirs.add(compositesDir);
    }
    for (final dir in dirs) {
      for (final entry in dir.listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('meta.json')) {
          continue;
        }
        try {
          final content = await entry.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          final id = data['id']?.toString();
          if (id != null && id.isNotEmpty) {
            installed.add(id);
          }
        } catch (_) {}
      }
    }
    _installedComponentCache = installed;
    return installed;
  }

  List<String> _dependentComponents(String id, Set<String> installed) {
    final dependents = <String>[];
    for (final installedId in installed) {
      if (installedId == id) {
        continue;
      }
      final component = registry.getComponent(installedId);
      if (component != null && component.dependsOn.contains(id)) {
        dependents.add(installedId);
      }
    }
    return dependents;
  }

  void _cleanupEmptyParents(Directory dir, String componentId) {
    final installPath = _installPath(_cachedConfig);
    final componentRoot = p.normalize(
      p.join(targetDir, installPath, 'components'),
    );
    var current = dir;
    while (p.normalize(current.path).startsWith(componentRoot)) {
      if (current.listSync().isNotEmpty) {
        break;
      }
      if (p.normalize(current.path) == componentRoot) {
        break;
      }
      current.deleteSync();
      current = current.parent;
    }
  }

  String _resolveDestinationPath(String destination) {
    final config = _cachedConfig;
    final variables = {
      'installPath': _installPath(config),
      'sharedPath': _sharedPath(config),
    };

    String destPath = destination;
    variables.forEach((key, value) {
      destPath = destPath.replaceAll('{$key}', value);
    });

    return p.join(targetDir, destPath);
  }

  String _installPath(ShadcnConfig? config) {
    final override = config?.installPath;
    if (override != null && override.isNotEmpty) {
      return _expandAliases(override, config?.pathAliases);
    }
    return _defaultInstallPath;
  }

  String _sharedPath(ShadcnConfig? config) {
    final override = config?.sharedPath;
    if (override != null && override.isNotEmpty) {
      return _expandAliases(override, config?.pathAliases);
    }
    return _defaultSharedPath;
  }

  bool _shouldInstallFile(String destination) {
    final lower = destination.toLowerCase();
    final config = _cachedConfig ?? const ShadcnConfig();
    if (lower.endsWith('readme.md')) {
      return config.includeReadme ?? false;
    }
    if (lower.endsWith('meta.json')) {
      return config.includeMeta ?? true;
    }
    if (lower.endsWith('preview.dart')) {
      return config.includePreview ?? false;
    }
    return true;
  }

  ShadcnConfig? _cachedConfig;

  Future<void> _ensureConfigLoaded() async {
    _cachedConfig ??= await ShadcnConfig.load(targetDir);
  }

  String _promptPath({
    required String label,
    required String current,
    bool requireLib = false,
    Map<String, String>? aliases,
  }) {
    while (true) {
      stdout.write('$label (default: $current). Enter to keep: ');
      final input = stdin.readLineSync()?.trim();
      if (input == null || input.isEmpty) {
        return current;
      }
      final resolved = _expandAliases(input, aliases);
      if (!requireLib) {
        return input;
      }
      final normalized = p.normalize(resolved);
      if (normalized == 'lib' || normalized.startsWith('lib${p.separator}')) {
        return input;
      }
      logger.warn('Path must start with lib/. Try again.');
    }
  }

  Map<String, String> _promptAliases(Map<String, String> current) {
    if (current.isNotEmpty) {
      stdout.write(
        'Path aliases (current: ${_formatAliases(current)}). Format: name=lib/path. Enter to keep: ',
      );
    } else {
      stdout.write(
        'Path aliases (optional). Format: name=lib/path (e.g. ui=lib/ui, hooks=lib/hooks): ',
      );
    }
    final input = stdin.readLineSync()?.trim();
    if (input == null || input.isEmpty) {
      return current;
    }
    final aliases = _parseAliases(input);
    return aliases;
  }

  Map<String, String> _parseAliases(String input) {
    final aliases = <String, String>{};
    final entries = input.split(',');
    for (final entry in entries) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final parts = trimmed.split('=');
      if (parts.length != 2) {
        logger.warn('Invalid alias format: "$trimmed". Use name=lib/path.');
        continue;
      }
      final name = parts.first.trim();
      final path = parts.last.trim();
      if (name.isEmpty || path.isEmpty) {
        continue;
      }
      final normalized = p.normalize(path);
      if (normalized != 'lib' && !normalized.startsWith('lib${p.separator}')) {
        logger.warn('Alias "$name" must point inside lib/. Skipping.');
        continue;
      }
      aliases[name] = path;
    }
    return aliases;
  }

  String _formatAliases(Map<String, String> aliases) {
    final entries = aliases.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value}').join(', ');
  }

  String _expandAliases(String path, Map<String, String>? aliases) {
    if (aliases == null || aliases.isEmpty) {
      return path;
    }
    if (path.startsWith('@')) {
      final index = path.indexOf('/');
      final name = index == -1 ? path.substring(1) : path.substring(1, index);
      final aliasPath = aliases[name];
      if (aliasPath != null) {
        final suffix = index == -1 ? '' : path.substring(index + 1);
        return suffix.isEmpty ? aliasPath : p.join(aliasPath, suffix);
      }
    }
    return path;
  }

  bool _promptYesNo(String label, {required bool defaultValue}) {
    final defaultLabel = defaultValue ? 'Y' : 'n';
    stdout.write('$label [$defaultLabel/${defaultValue ? 'n' : 'Y'}]: ');
    final input = stdin.readLineSync()?.trim().toLowerCase();
    if (input == null || input.isEmpty) {
      return defaultValue;
    }
    return input.startsWith('y');
  }

  void _printInitSummary(ShadcnConfig config, String? themePreset) {
    logger.section('Init summary');
    logger.info('  installPath: ${config.installPath ?? _defaultInstallPath}');
    logger.info('  sharedPath: ${config.sharedPath ?? _defaultSharedPath}');
    logger.info(
        '  includeReadme: ${config.includeReadme ?? false ? 'yes' : 'no'}');
    logger.info('  includeMeta: ${config.includeMeta ?? true ? 'yes' : 'no'}');
    logger.info(
        '  includePreview: ${config.includePreview ?? false ? 'yes' : 'no'}');
    if (config.classPrefix != null && config.classPrefix!.isNotEmpty) {
      logger.info('  classPrefix: ${config.classPrefix}');
    }
    if (config.pathAliases != null && config.pathAliases!.isNotEmpty) {
      logger.info('  pathAliases: ${_formatAliases(config.pathAliases!)}');
    }
    if (themePreset != null && themePreset.isNotEmpty) {
      logger.info('  themePreset: $themePreset');
    }
    logger.info(
        '  shared core: theme, util, color_extensions, form_control, form_value_supplier');
    logger.info('  dependencies: data_widget, gap');
  }

  bool _confirmInitProceed() {
    stdout.write('Proceed with initialization? [Y/n]: ');
    final input = stdin.readLineSync()?.trim().toLowerCase();
    if (input == null || input.isEmpty) {
      return true;
    }
    return input.startsWith('y');
  }

  String get _defaultInstallPath {
    return registry.defaults['installPath'] ?? 'lib/ui/shadcn';
  }

  String get _defaultSharedPath {
    return registry.defaults['sharedPath'] ?? 'lib/ui/shadcn/shared';
  }

  Future<void> _updateDependencies(Map<String, dynamic> deps) async {
    if (deps.isEmpty) {
      return;
    }

    final pubspecFile = File(p.join(targetDir, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      logger.warn('pubspec.yaml not found; skipping dependency updates.');
      return;
    }

    final lines = pubspecFile.readAsLinesSync();
    final result = _applyDependencies(lines, deps);
    if (result.added.isEmpty) {
      logger.detail('Dependencies already present.');
      return;
    }

    await pubspecFile.writeAsString(result.lines.join('\n'));
    logger.success('Added dependencies: ${result.added.join(', ')}');
  }

  Future<void> _updateAssets(List<String> assets) async {
    if (assets.isEmpty) {
      return;
    }
    final pubspecFile = File(p.join(targetDir, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      logger.warn('pubspec.yaml not found; skipping asset updates.');
      return;
    }

    final lines = pubspecFile.readAsLinesSync();
    final result = _applyAssets(lines, assets);
    if (result.added.isEmpty) {
      logger.detail('Assets already present.');
      return;
    }

    await pubspecFile.writeAsString(result.lines.join('\n'));
    logger.success('Added assets: ${result.added.join(', ')}');
  }

  Future<void> _updateFonts(List<FontEntry> fonts) async {
    if (fonts.isEmpty) {
      return;
    }
    final pubspecFile = File(p.join(targetDir, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      logger.warn('pubspec.yaml not found; skipping font updates.');
      return;
    }

    final lines = pubspecFile.readAsLinesSync();
    final result = _applyFonts(lines, fonts);
    if (result.added.isEmpty) {
      logger.detail('Fonts already present.');
      return;
    }

    await pubspecFile.writeAsString(result.lines.join('\n'));
    logger.success('Added font families: ${result.added.join(', ')}');
  }

  _DependencyUpdateResult _applyDependencies(
    List<String> lines,
    Map<String, dynamic> deps,
  ) {
    final existing = _collectExistingDependencies(lines);
    final additions = <String, dynamic>{};
    deps.forEach((key, value) {
      if (!existing.contains(key)) {
        additions[key] = value;
      }
    });

    if (additions.isEmpty) {
      return _DependencyUpdateResult(lines, const []);
    }

    final update = _insertDependencies(lines, additions);
    return _DependencyUpdateResult(update, additions.keys.toList()..sort());
  }

  _AssetsUpdateResult _applyAssets(List<String> lines, List<String> assets) {
    final normalized = assets.where((a) => a.trim().isNotEmpty).toSet().toList()
      ..sort();
    if (normalized.isEmpty) {
      return _AssetsUpdateResult(lines, const []);
    }

    final flutterRange = _findFlutterSection(lines);
    if (flutterRange.start == -1) {
      final addedLines = <String>[
        'flutter:',
        '  assets:',
        ...normalized.map((a) => '    - $a'),
      ];
      return _AssetsUpdateResult(
        [...lines, if (lines.isNotEmpty) '', ...addedLines],
        normalized,
      );
    }

    final flutterIndent = _leadingSpaces(lines[flutterRange.start]);
    final assetsIndex = _findSectionLine(lines, flutterRange, 'assets:');
    if (assetsIndex == -1) {
      final insertIndex = flutterRange.end;
      final assetsIndent = ' ' * (flutterIndent + 2);
      final assetItemIndent = ' ' * (flutterIndent + 4);
      final insertion = <String>[
        '$assetsIndent' 'assets:',
        ...normalized.map((a) => '$assetItemIndent- $a'),
      ];
      final updated = [...lines]..insertAll(insertIndex, insertion);
      return _AssetsUpdateResult(updated, normalized);
    }

    final assetsIndentCount = _leadingSpaces(lines[assetsIndex]);
    final assetItemIndent = ' ' * (assetsIndentCount + 2);
    final existing = <String>{};
    var insertAt = assetsIndex + 1;
    for (var i = assetsIndex + 1; i < flutterRange.end; i++) {
      final line = lines[i];
      if (line.trim().isEmpty || line.trim().startsWith('#')) {
        continue;
      }
      if (_leadingSpaces(line) <= assetsIndentCount) {
        break;
      }
      if (line.trim().startsWith('- ')) {
        existing.add(line.trim().substring(2).trim());
        insertAt = i + 1;
      }
    }

    final additions = normalized.where((a) => !existing.contains(a)).toList();
    if (additions.isEmpty) {
      return _AssetsUpdateResult(lines, const []);
    }
    final updated = [...lines]
      ..insertAll(insertAt, additions.map((a) => '$assetItemIndent- $a'));
    return _AssetsUpdateResult(updated, additions);
  }

  _FontsUpdateResult _applyFonts(List<String> lines, List<FontEntry> fonts) {
    if (fonts.isEmpty) {
      return _FontsUpdateResult(lines, const []);
    }

    final flutterRange = _findFlutterSection(lines);
    if (flutterRange.start == -1) {
      final addedLines = <String>['flutter:', ..._formatFontSection(fonts, 2)];
      final addedFamilies = fonts.map((f) => f.family).toList()..sort();
      return _FontsUpdateResult(
        [...lines, if (lines.isNotEmpty) '', ...addedLines],
        addedFamilies,
      );
    }

    final flutterIndent = _leadingSpaces(lines[flutterRange.start]);
    final fontsIndex = _findSectionLine(lines, flutterRange, 'fonts:');
    if (fontsIndex == -1) {
      final insertIndex = flutterRange.end;
      final insertion = _formatFontSection(fonts, flutterIndent + 2);
      final updated = [...lines]..insertAll(insertIndex, insertion);
      final addedFamilies = fonts.map((f) => f.family).toList()..sort();
      return _FontsUpdateResult(updated, addedFamilies);
    }

    final fontsIndentCount = _leadingSpaces(lines[fontsIndex]);
    final fontsRange = _findSectionEnd(lines, fontsIndex, fontsIndentCount);
    final existingFamilies = <String>{};
    for (var i = fontsIndex + 1; i < fontsRange.end; i++) {
      final line = lines[i].trimLeft();
      if (line.startsWith('- family:')) {
        final family = line.split(':').skip(1).join(':').trim();
        if (family.isNotEmpty) {
          existingFamilies.add(family);
        }
      }
    }

    final additions =
        fonts.where((f) => !existingFamilies.contains(f.family)).toList();
    if (additions.isEmpty) {
      return _FontsUpdateResult(lines, const []);
    }

    final insertion = _formatFontSection(additions, fontsIndentCount + 2);
    final updated = [...lines]..insertAll(fontsRange.end, insertion);
    final addedFamilies = additions.map((f) => f.family).toList()..sort();
    return _FontsUpdateResult(updated, addedFamilies);
  }

  Set<String> _collectExistingDependencies(List<String> lines) {
    final deps = <String>{};
    bool inDeps = false;
    int depsIndent = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      if (trimmed == 'dependencies:') {
        inDeps = true;
        depsIndent = line.indexOf('dependencies:');
        continue;
      }
      if (inDeps) {
        final currentIndent = line.indexOf(trimmed);
        if (currentIndent <= depsIndent) {
          inDeps = false;
          continue;
        }
        final match = RegExp(r'^([A-Za-z0-9_\-]+):').firstMatch(trimmed);
        if (match != null) {
          deps.add(match.group(1)!);
        }
      }
    }

    if (!inDeps) {
      // Also consider dev_dependencies to avoid duplicates
      bool inDev = false;
      int devIndent = 0;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        if (trimmed == 'dev_dependencies:') {
          inDev = true;
          devIndent = line.indexOf('dev_dependencies:');
          continue;
        }
        if (inDev) {
          final currentIndent = line.indexOf(trimmed);
          if (currentIndent <= devIndent) {
            inDev = false;
            continue;
          }
          final match = RegExp(r'^([A-Za-z0-9_\-]+):').firstMatch(trimmed);
          if (match != null) {
            deps.add(match.group(1)!);
          }
        }
      }
    }

    return deps;
  }

  List<String> _insertDependencies(
    List<String> lines,
    Map<String, dynamic> additions,
  ) {
    final updated = List<String>.from(lines);
    final depsIndex = _findSectionIndex(updated, 'dependencies:');
    if (depsIndex == -1) {
      updated.add('');
      updated.add('dependencies:');
      final indent = '  ';
      final entries = additions.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in entries) {
        updated.addAll(_formatDependencyLines(entry.key, entry.value, indent));
      }
      return updated;
    }

    final depsIndent = _leadingSpaces(updated[depsIndex]);
    final childIndent = ' ' * (depsIndent + 2);
    var insertIndex = depsIndex + 1;
    while (insertIndex < updated.length) {
      final line = updated[insertIndex];
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        insertIndex++;
        continue;
      }
      final indent = _leadingSpaces(line);
      if (indent <= depsIndent) {
        break;
      }
      insertIndex++;
    }

    final entries = additions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final linesToInsert = <String>[];
    for (final entry in entries) {
      linesToInsert
          .addAll(_formatDependencyLines(entry.key, entry.value, childIndent));
    }
    updated.insertAll(insertIndex, linesToInsert);
    return updated;
  }

  List<String> _formatDependencyLines(
      String key, dynamic value, String indent) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('sdk:')) {
        final sdkValue = trimmed.split(':').skip(1).join(':').trim();
        return [
          '$indent$key:',
          '$indent  sdk: $sdkValue',
        ];
      }
    }
    if (value is Map) {
      final lines = <String>['$indent$key:'];
      final childIndent = '$indent  ';
      value.forEach((k, v) {
        lines.add('$childIndent$k: $v');
      });
      return lines;
    }
    return ['$indent$key: ${value.toString()}'];
  }

  int _findSectionIndex(List<String> lines, String section) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim() == section) {
        return i;
      }
    }
    return -1;
  }

  _SectionRange _findFlutterSection(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim() == 'flutter:' && _leadingSpaces(lines[i]) == 0) {
        final end = _findSectionEnd(lines, i, 0).end;
        return _SectionRange(i, end);
      }
    }
    return const _SectionRange(-1, -1);
  }

  int _findSectionLine(List<String> lines, _SectionRange range, String key) {
    for (var i = range.start + 1; i < range.end; i++) {
      final line = lines[i].trim();
      if (line == key) {
        return i;
      }
    }
    return -1;
  }

  _SectionRange _findSectionEnd(List<String> lines, int start, int indent) {
    var end = lines.length;
    for (var i = start + 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty || line.trim().startsWith('#')) {
        continue;
      }
      if (_leadingSpaces(line) <= indent) {
        end = i;
        break;
      }
    }
    return _SectionRange(start, end);
  }

  List<String> _formatFontSection(List<FontEntry> fonts, int indentCount) {
    final indent = ' ' * indentCount;
    final itemIndent = ' ' * (indentCount + 2);
    final innerIndent = ' ' * (indentCount + 4);
    final assetIndent = ' ' * (indentCount + 6);
    final lines = <String>['$indent' 'fonts:'];
    for (final entry in fonts) {
      lines.add('$itemIndent- family: ${entry.family}');
      lines.add('$innerIndent' 'fonts:');
      for (final font in entry.fonts) {
        lines.add('$assetIndent- asset: ${font.asset}');
        if (font.weight != null) {
          lines.add('$assetIndent  weight: ${font.weight}');
        }
        if (font.style != null) {
          lines.add('$assetIndent  style: ${font.style}');
        }
      }
    }
    return lines;
  }

  int _leadingSpaces(String line) {
    var count = 0;
    for (final char in line.split('')) {
      if (char == ' ') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }
}

class DryRunPlan {
  final List<String> requested;
  final List<String> missing;
  final List<Component> components;
  final Map<String, List<String>> dependencyGraph;
  final List<String> shared;
  final Map<String, dynamic> pubspecDependencies;
  final List<String> assets;
  final List<FontEntry> fonts;
  final List<String> postInstall;
  final List<String> fileDependencies;
  final Map<String, Set<String>> platformChanges;
  final Map<String, List<Map<String, String>>> componentFiles;
  final Map<String, Map<String, dynamic>> manifestPreview;

  DryRunPlan({
    required this.requested,
    required this.missing,
    required this.components,
    required this.dependencyGraph,
    required this.shared,
    required this.pubspecDependencies,
    required this.assets,
    required this.fonts,
    required this.postInstall,
    required this.fileDependencies,
    required this.platformChanges,
    required this.componentFiles,
    required this.manifestPreview,
  });

  Map<String, dynamic> toJson() {
    return {
      'requested': requested,
      'missing': missing,
      'components': components.map((c) => c.id).toList(),
      'dependencyGraph': dependencyGraph,
      'shared': shared,
      'pubspecDependencies': pubspecDependencies,
      'assets': assets,
      'fonts': fonts
          .map((font) => {
                'family': font.family,
                'fonts': font.fonts
                    .map((entry) => {
                          'asset': entry.asset,
                          'weight': entry.weight,
                          'style': entry.style,
                        })
                    .toList(),
              })
          .toList(),
      'postInstall': postInstall,
      'fileDependencies': fileDependencies,
      'platformChanges': platformChanges.map(
        (key, value) => MapEntry(key, value.toList()..sort()),
      ),
      'componentFiles': componentFiles,
      'manifestPreview': manifestPreview,
    };
  }
}

final _classRegex = RegExp(
    r'^\s*(abstract\s+)?class\s+([A-Z]\w*)(\s*<[^>{}]+>)?',
    multiLine: true);

final _partRegex = RegExp(r'''part\s+['"]([^'"]+)['"];''');

final _importDirectiveRegex =
    RegExp(r'''^\s*(import|export|part)\s+['"]([^'"]+)['"]''');
final _partOfDirectiveRegex = RegExp(r'^\s*part\s+of\b');

class _RegistryFileOwner {
  final String id;
  final bool isShared;
  final RegistryFile file;

  const _RegistryFileOwner({
    required this.id,
    required this.isShared,
    required this.file,
  });

  factory _RegistryFileOwner.shared(String id, RegistryFile file) {
    return _RegistryFileOwner(id: id, isShared: true, file: file);
  }

  factory _RegistryFileOwner.component(String id, RegistryFile file) {
    return _RegistryFileOwner(id: id, isShared: false, file: file);
  }

  bool get isComponent => !isShared;
}

class _AliasEntry {
  final String className;
  final String? typeParams;

  const _AliasEntry(this.className, this.typeParams);
}

class _DependencyUpdateResult {
  final List<String> lines;
  final List<String> added;

  const _DependencyUpdateResult(this.lines, this.added);
}

class _AssetsUpdateResult {
  final List<String> lines;
  final List<String> added;

  const _AssetsUpdateResult(this.lines, this.added);
}

class _FontsUpdateResult {
  final List<String> lines;
  final List<String> added;

  const _FontsUpdateResult(this.lines, this.added);
}

class _SectionRange {
  final int start;
  final int end;

  const _SectionRange(this.start, this.end);
}

class InitConfigOverrides {
  final String? installPath;
  final String? sharedPath;
  final bool? includeReadme;
  final bool? includeMeta;
  final bool? includePreview;
  final String? classPrefix;
  final Map<String, String>? pathAliases;

  const InitConfigOverrides({
    this.installPath,
    this.sharedPath,
    this.includeReadme,
    this.includeMeta,
    this.includePreview,
    this.classPrefix,
    this.pathAliases,
  });

  bool get hasAny {
    return installPath != null ||
        sharedPath != null ||
        includeReadme != null ||
        includeMeta != null ||
        includePreview != null ||
        classPrefix != null ||
        pathAliases != null;
  }
}
