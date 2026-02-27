import 'package:flutter_shadcn_cli/src/installer.dart';

class InstallerOrchestrator {
  final Installer installer;

  const InstallerOrchestrator(this.installer);

  Future<void> runInit({
    required bool skipPrompts,
    required InitConfigOverrides configOverrides,
    required String? themePreset,
  }) {
    return installer.init(
      skipPrompts: skipPrompts,
      configOverrides: configOverrides,
      themePreset: themePreset,
    );
  }

  Future<void> addComponents(Iterable<String> componentIds) async {
    for (final componentId in componentIds) {
      await installer.addComponent(componentId);
    }
  }

  Future<void> removeComponents(
    Iterable<String> componentIds, {
    required bool force,
  }) async {
    for (final componentId in componentIds) {
      await installer.removeComponent(componentId, force: force);
    }
  }

  Future<void> runBulkInstall(Future<void> Function() action) {
    return installer.runBulkInstall(action);
  }

  Future<void> ensureInitFiles() {
    return installer.ensureInitFiles(allowPrompts: false);
  }

  Future<void> installAllComponents() {
    return installer.installAllComponents();
  }

  Future<void> removeAllComponents() {
    return installer.removeAllComponents(force: true);
  }

  Future<void> regenerateAliases() {
    return installer.generateAliases();
  }
}
