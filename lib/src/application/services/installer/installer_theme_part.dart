part of 'installer.dart';

extension InstallerThemePart on Installer {
  Future<void> _promptThemeSelection() async {
    await _interactiveThemeSelection(skipIfConfigured: true);
  }

  Future<void> chooseTheme({bool refresh = false}) async {
    await _interactiveThemeSelection(
      skipIfConfigured: false,
      refresh: refresh,
    );
  }

  Future<void> listThemes({bool refresh = false}) async {
    final presets = await _loadResolvedThemePresets(refresh: refresh);
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

  Future<void> applyThemeById(String identifier, {bool refresh = false}) async {
    final presets = await _loadResolvedThemePresets(refresh: refresh);
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
        logger.warn('Failed to fetch theme URL (status ${response.statusCode}).');
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

  Future<void> _interactiveThemeSelection({
    required bool skipIfConfigured,
    bool refresh = false,
  }) async {
    final presets = await _loadResolvedThemePresets(refresh: refresh);
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

  Future<List<RegistryThemePresetData>> _loadResolvedThemePresets({
    bool refresh = false,
  }) async {
    await _ensureConfigLoaded();
    final config = _cachedConfig ?? const ShadcnConfig();
    final entry = config.registryConfig(registryNamespace);
    final themesPath = entry?.themesPath;

    if (themesPath == null || themesPath.trim().isEmpty) {
      return loadThemePresets(logger: logger);
    }

    final registryBaseUrl =
        entry?.baseUrl ?? entry?.registryUrl ?? registry.sourceRoot.root;
    final registryId = _themeRegistryId(registryBaseUrl);
    final indexLoader = ThemeIndexLoader(
      registryId: registryId,
      registryBaseUrl: registryBaseUrl,
      themesPath: themesPath,
      themesSchemaPath: entry?.themesSchemaPath,
      refresh: refresh,
      offline: registry.sourceRoot.offline,
      logger: logger,
    );
    final presetLoader = ThemePresetLoader(
      registryId: registryId,
      registryBaseUrl: registryBaseUrl,
      themesPath: themesPath,
      themesSchemaPath: entry?.themesSchemaPath,
      themeConverterDartPath: entry?.themeConverterDartPath,
      refresh: refresh,
      offline: registry.sourceRoot.offline,
      logger: logger,
    );
    return loadThemePresets(
      themeIndexLoader: indexLoader,
      themePresetLoader: presetLoader,
      logger: logger,
    );
  }

  String _themeRegistryId(String registryBaseUrl) {
    final safe = registryBaseUrl.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.length <= 80) {
      return safe;
    }
    return safe.substring(0, 80);
  }

  Future<void> _applyThemePreset(RegistryThemePresetData preset) async {
    await _ensureConfigLoaded();
    final themeFilePath = _resolveColorSchemeFilePath();
    if (themeFilePath == null) {
      logger.warn('Theme file not found. Run "flutter_shadcn init" first.');
      return;
    }
    final themeFile = File(themeFilePath);
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

  String? _resolveColorSchemeFilePath() {
    final sharedPath = _sharedPath(_cachedConfig);
    final candidates = <String>[
      p.join(targetDir, sharedPath, 'theme', 'color_scheme.dart'),
      p.join(targetDir, sharedPath, 'theme', '_impl', 'core',
          'color_schemes.dart'),
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }
}
