import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'registry.dart';
import 'config.dart';
import 'logger.dart';
import 'theme_css.dart';
import 'package:flutter_shadcn_cli/registry/shared/theme/preset_theme_data.dart'
    show RegistryThemePresetData;

class Installer {
  final Registry registry;
  final String targetDir; // The user's project root
  final CliLogger logger;
  Set<String>? _installedComponentCache;
  final Set<String> _installedSharedCache = {};

  Installer({
    required this.registry,
    required this.targetDir,
    CliLogger? logger,
  }) : logger = logger ?? const CliLogger();

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

    await installShared('theme');
    await installShared('util');
    if (themePreset != null && themePreset.isNotEmpty) {
      await applyThemeById(themePreset);
    } else if (!skipPrompts) {
      await _promptThemeSelection();
    }
    await generateAliases();
    
    // Also install a few commonly used ones to be safe?
    // Or just wait for 'add' to pull them in.
    // Let's stick to theme/util for init + structure.
    
    logger.success('Initialization complete');
    logger.detail('Aliases written to lib/ui/shadcn/app_components.dart');
  }

  Future<void> addComponent(String name) async {
    await _ensureConfigLoaded();
    final component = registry.getComponent(name);
    if (component == null) {
      logger.warn('Component "$name" not found');
      return;
    }

    final installed = await _installedComponentIds();
    if (installed.contains(component.id)) {
      logger.detail('Skipping ${component.id} (already installed)');
      return;
    }

    logger.action('Installing ${component.name} (${component.id})');
    
    // 1. Install dependencies first
    for (final dep in component.dependsOn) {
      await addComponent(dep);
    }

    // 2. Install shared dependencies
    for (final sharedId in component.shared) {
      await installShared(sharedId);
    }

    // 3. Install component files
    for (final file in component.files) {
      await _installFile(file);
    }

    // 4. Update pubspec (print instructions for now, or use dcli/automator)
    if (component.pubspec.isNotEmpty) {
      final deps = component.pubspec['dependencies'] as Map<String, dynamic>;
      await _updateDependencies(deps);
    }
    await generateAliases();
    _installedComponentCache?.add(component.id);
  }

  Future<void> installShared(String id) async {
    await _ensureConfigLoaded();
    final sharedItem = registry.shared.firstWhere((s) => s.id == id, orElse: () => throw Exception('Shared item $id not found'));

    if (_installedSharedCache.contains(id)) {
      return;
    }

    for (final file in sharedItem.files) {
      await _installFile(file);
    }

    _installedSharedCache.add(id);
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
    for (final entity in componentsDir.listSync()) {
      if (entity is! Directory) {
        continue;
      }
      final componentDir = entity;
      final componentName = p.basename(componentDir.path);
      final mainFile = File(p.join(componentDir.path, '$componentName.dart'));
      if (!mainFile.existsSync()) {
        continue;
      }
      imports.add("components/$componentName/$componentName.dart");
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

  Future<void> _interactiveThemeSelection({required bool skipIfConfigured}) async {
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
      label: 'Install directory (inside lib/)',
      current: existing.installPath ?? _defaultInstallPath,
      requireLib: true,
      aliases: resolvedAliases,
    );
    final resolvedSharedPath = _promptPath(
      label: 'Shared directory (inside lib/)',
      current: existing.sharedPath ?? _defaultSharedPath,
      requireLib: true,
      aliases: resolvedAliases,
    );

    final includeReadme = _promptYesNo(
      'Include README.md files? (optional)',
      defaultValue: existing.includeReadme ?? false,
    );
    final includeMeta = _promptYesNo(
      'Include meta.json files? (recommended)',
      defaultValue: existing.includeMeta ?? true,
    );
    final includePreview = _promptYesNo(
      'Include preview.dart files? (optional)',
      defaultValue: existing.includePreview ?? false,
    );

    String? prefix = existing.classPrefix;
    if (prefix == null || prefix.isEmpty) {
      final defaultPrefix = _defaultPrefix();
      stdout.write(
        'App class prefix (optional, e.g. $defaultPrefix, leave blank to skip): ',
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

    final normalizedAliases = overrides.pathAliases == null
        ? null
        : overrides.pathAliases!.map(
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
    await _ensureConfigLoaded();
    final component = registry.getComponent(name);
    if (component == null) {
      logger.warn('Component "$name" not found in registry.');
      return;
    }

    final installed = await _installedComponentIds();
    if (!installed.contains(component.id)) {
      logger.warn('Component "${component.id}" is not installed.');
      return;
    }

    if (!force) {
      final dependents = _dependentComponents(component.id, installed);
      if (dependents.isNotEmpty) {
        logger.warn('Cannot remove "${component.id}" because it is required by:');
        for (final dependent in dependents) {
          logger.info('  - $dependent');
        }
        logger.info('Remove dependent components first or use --force.');
        return;
      }
    }

    for (final file in component.files) {
      final destPath = _resolveDestinationPath(file.destination);
      final destFile = File(destPath);
      if (await destFile.exists()) {
        await destFile.delete();
        _cleanupEmptyParents(destFile.parent, component.id);
      }
    }

    logger.success('Removed component: ${component.id}');
    await generateAliases();
  }

  Future<Set<String>> _installedComponentIds() async {
    await _ensureConfigLoaded();
    if (_installedComponentCache != null) {
      return _installedComponentCache!;
    }
    final installPath = _installPath(_cachedConfig);
    final componentsDir = Directory(p.join(targetDir, installPath, 'components'));
    if (!componentsDir.existsSync()) {
      _installedComponentCache = {};
      return _installedComponentCache!;
    }

    final installed = <String>{};
    for (final entry in componentsDir.listSync(recursive: true)) {
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
      p.join(targetDir, installPath, 'components', componentId),
    );
    var current = dir;
    while (p.normalize(current.path).startsWith(componentRoot)) {
      if (current.listSync().isNotEmpty) {
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
      stdout.write('$label (default: $current): ');
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
      logger.warn('Path must be inside lib/. Try again.');
    }
  }

  Map<String, String> _promptAliases(Map<String, String> current) {
    if (current.isNotEmpty) {
      stdout.write('Path aliases (current: ${_formatAliases(current)}). Enter to keep: ');
    } else {
      stdout.write('Path aliases (optional, e.g. ui=lib/ui, hooks=lib/hooks): ');
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
    stdout.write('$label [${defaultLabel}/' + (defaultValue ? 'n' : 'Y') + ']: ');
    final input = stdin.readLineSync()?.trim().toLowerCase();
    if (input == null || input.isEmpty) {
      return defaultValue;
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

  _DependencyUpdateResult _applyDependencies(
    List<String> lines,
    Map<String, dynamic> deps,
  ) {
    final existing = _collectExistingDependencies(lines);
    final additions = <String, String>{};
    deps.forEach((key, value) {
      if (!existing.contains(key)) {
        additions[key] = value.toString();
      }
    });

    if (additions.isEmpty) {
      return _DependencyUpdateResult(lines, const []);
    }

    final update = _insertDependencies(lines, additions);
    return _DependencyUpdateResult(update, additions.keys.toList()..sort());
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
    Map<String, String> additions,
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
        updated.add('$indent${entry.key}: ${entry.value}');
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
    final linesToInsert = entries
        .map((entry) => '$childIndent${entry.key}: ${entry.value}')
        .toList();
    updated.insertAll(insertIndex, linesToInsert);
    return updated;
  }

  int _findSectionIndex(List<String> lines, String section) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim() == section) {
        return i;
      }
    }
    return -1;
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

final _classRegex = RegExp(r'^\s*(abstract\s+)?class\s+([A-Z]\w*)(\s*<[^>{}]+>)?', multiLine: true);


final _partRegex = RegExp(r'''part\s+['"]([^'"]+)['"];''');

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
