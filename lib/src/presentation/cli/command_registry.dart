import 'package:flutter_shadcn_cli/src/presentation/cli/cli_command_category.dart';
import 'package:flutter_shadcn_cli/src/presentation/cli/cli_command_entry.dart';

const List<CliCommandCategory> cliCommandCategories = [
  CliCommandCategory('Project & Registry Setup', [
    CliCommandEntry('init', 'Initialize shadcn_flutter in the current project'),
    CliCommandEntry('theme', 'Manage registry theme presets'),
    CliCommandEntry('assets', 'Install font/icon assets'),
    CliCommandEntry('platform', 'Configure platform targets'),
    CliCommandEntry('sync', 'Sync changes from .shadcn/config.json'),
    CliCommandEntry('registries', 'List available/configured registries'),
    CliCommandEntry('default', 'Set default registry namespace'),
  ]),
  CliCommandCategory('Component Workflow', [
    CliCommandEntry('add', 'Add a widget'),
    CliCommandEntry('remove (alias: rm)', 'Remove a widget'),
    CliCommandEntry('dry-run', 'Preview what would be installed'),
    CliCommandEntry('list (alias: ls)', 'List available components'),
    CliCommandEntry('search', 'Search for components'),
    CliCommandEntry('info (alias: i)', 'Show component details'),
  ]),
  CliCommandCategory('Verification & Diagnostics', [
    CliCommandEntry('validate', 'Validate registry integrity'),
    CliCommandEntry('audit', 'Audit installed components'),
    CliCommandEntry('deps', 'Compare registry deps vs pubspec'),
    CliCommandEntry('doctor', 'Diagnose registry resolution'),
  ]),
  CliCommandCategory('Tooling & Maintenance', [
    CliCommandEntry('docs', 'Regenerate documentation site'),
    CliCommandEntry('feedback', 'Submit feedback or report issues'),
    CliCommandEntry('version', 'Show CLI version'),
    CliCommandEntry('upgrade', 'Upgrade CLI to latest version'),
    CliCommandEntry('install-skill', 'Install AI skills (🧪 experimental)'),
  ]),
];
