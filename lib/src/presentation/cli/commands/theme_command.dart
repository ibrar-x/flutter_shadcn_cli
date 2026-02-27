import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_shadcn_cli/src/exit_codes.dart';
import 'package:flutter_shadcn_cli/src/installer.dart';

Future<int> runThemeCommand({
  required ArgResults themeCommand,
  required ArgResults rootArgs,
  required Installer? installer,
}) async {
  final activeInstaller = installer;
  if (activeInstaller == null) {
    stderr.writeln('Error: Installer is not available.');
    return ExitCodes.registryNotFound;
  }
  if (themeCommand['help'] == true) {
    print('Usage: flutter_shadcn theme [--list | --apply <preset> | --apply-file <path> | --apply-url <url>]');
    print('');
    print('Options:');
    print('  --list             Show all available theme presets');
    print('  --apply, -a <id>   Apply the preset with the given ID');
    print('  --apply-file       Apply a theme JSON file (experimental)');
    print('  --apply-url        Apply a theme JSON URL (experimental)');
    print('  --help, -h         Show this message');
    print('');
    print('Experimental:');
    print('  Use --experimental to enable apply-file/apply-url.');
    return ExitCodes.success;
  }
  final isExperimental = rootArgs['experimental'] == true;
  if (themeCommand['list'] == true) {
    await activeInstaller.listThemes();
    return ExitCodes.success;
  }
  final applyFile = themeCommand['apply-file'] as String?;
  final applyUrl = themeCommand['apply-url'] as String?;
  if (applyFile != null || applyUrl != null) {
    if (!isExperimental) {
      stderr.writeln('Error: --apply-file/--apply-url require --experimental.');
      return ExitCodes.usage;
    }
    if (applyFile != null) {
      await activeInstaller.applyThemeFromFile(applyFile);
      return ExitCodes.success;
    }
    if (applyUrl != null) {
      await activeInstaller.applyThemeFromUrl(applyUrl);
      return ExitCodes.success;
    }
  }
  final applyOption = themeCommand['apply'] as String?;
  final rest = [...themeCommand.rest];
  if (rest.isNotEmpty && rest.first.startsWith('@') && !rest.first.contains('/')) {
    rest.removeAt(0);
  }
  final presetArg = applyOption ?? (rest.isEmpty ? null : rest.first);
  if (presetArg != null) {
    await activeInstaller.applyThemeById(presetArg);
    return ExitCodes.success;
  }
  await activeInstaller.chooseTheme();
  return ExitCodes.success;
}
