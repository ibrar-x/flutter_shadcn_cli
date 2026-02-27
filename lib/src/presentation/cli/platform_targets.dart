import 'dart:io';

import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';

Map<String, Map<String, String>> mergePlatformTargets(
  Map<String, Map<String, String>>? overrides,
) {
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
  final merged = <String, Map<String, String>>{};
  for (final entry in defaults.entries) {
    merged[entry.key] = Map<String, String>.from(entry.value);
  }
  if (overrides != null) {
    overrides.forEach((platform, value) {
      merged.putIfAbsent(platform, () => {});
      merged[platform]!.addAll(value);
    });
  }
  return merged;
}

ShadcnConfig? updatePlatformTargets(
  ShadcnConfig config,
  List<String> sets,
  List<String> resets,
) {
  if (sets.isEmpty && resets.isEmpty) {
    return null;
  }
  final current = config.platformTargets == null
      ? <String, Map<String, String>>{}
      : Map<String, Map<String, String>>.fromEntries(
          config.platformTargets!.entries.map(
            (entry) =>
                MapEntry(entry.key, Map<String, String>.from(entry.value)),
          ),
        );

  for (final reset in resets) {
    final parts = reset.split('.');
    if (parts.length != 2) {
      stderr.writeln('Invalid reset format: $reset (use platform.section)');
      continue;
    }
    final platform = parts[0];
    final section = parts[1];
    final sectionMap = current[platform];
    sectionMap?.remove(section);
    if (sectionMap != null && sectionMap.isEmpty) {
      current.remove(platform);
    }
  }

  for (final set in sets) {
    final parts = set.split('=');
    if (parts.length != 2) {
      stderr.writeln('Invalid set format: $set (use platform.section=path)');
      continue;
    }
    final key = parts[0];
    final value = parts[1];
    final keyParts = key.split('.');
    if (keyParts.length != 2) {
      stderr.writeln('Invalid set key: $key (use platform.section)');
      continue;
    }
    final platform = keyParts[0];
    final section = keyParts[1];
    current.putIfAbsent(platform, () => {});
    current[platform]![section] = value;
  }

  return config.copyWith(platformTargets: current);
}

void printPlatformTargets(Map<String, Map<String, String>> targets) {
  final logger = CliLogger();
  logger.section('Platform targets');
  if (targets.isEmpty) {
    logger.info('  (no targets configured)');
    return;
  }
  targets.forEach((platform, sections) {
    logger.info('  $platform:');
    for (final entry in sections.entries) {
      logger.info('    ${entry.key}: ${entry.value}');
    }
  });
}
