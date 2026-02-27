import 'package:flutter_shadcn_cli/src/application/services/multi_registry_types.dart';
import 'package:flutter_shadcn_cli/src/application/services/add_resolution_service.dart';
import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/core/utils/path_utils.dart';
import 'package:flutter_shadcn_cli/src/init_action_engine.dart';
import 'package:flutter_shadcn_cli/src/inline_action_journal.dart';
import 'package:flutter_shadcn_cli/src/installer.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';
import 'package:flutter_shadcn_cli/src/multi_registry_exception.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';
import 'package:flutter_shadcn_cli/src/registry_directory.dart';
import 'package:flutter_shadcn_cli/src/state.dart';
import 'package:flutter_shadcn_cli/src/version_manager.dart';

export 'package:flutter_shadcn_cli/src/multi_registry_exception.dart';

part 'multi_registry_init_part.dart';
part 'multi_registry_add_part.dart';
part 'multi_registry_assets_part.dart';
part 'multi_registry_directory_part.dart';

class MultiRegistryManager {
  final String targetDir;
  final bool offline;
  final CliLogger logger;
  final String directoryUrl;
  final String? directoryPath;
  final RegistryDirectoryClient directoryClient;
  final InitActionEngine initActionEngine;
  final AddResolutionService addResolutionService;

  RegistryDirectory? _directoryCache;
  final Map<String, RegistrySource> _sources = {};
  final Map<String, Registry> _registryCache = {};

  MultiRegistryManager({
    required this.targetDir,
    required this.offline,
    required this.logger,
    this.directoryUrl = defaultRegistriesDirectoryUrl,
    this.directoryPath,
    RegistryDirectoryClient? directoryClient,
    InitActionEngine? initActionEngine,
    AddResolutionService? addResolutionService,
  })  : directoryClient = directoryClient ?? RegistryDirectoryClient(),
        initActionEngine = initActionEngine ?? InitActionEngine(),
        addResolutionService = addResolutionService ?? const AddResolutionService();

  void close() {
    directoryClient.close();
  }

  static QualifiedComponentRef? parseComponentRef(String token) {
    return AddResolutionService.parseQualifiedComponentRef(token);
  }
}
