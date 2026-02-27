# CLI Clean Architecture (v1)

## Layers

### Presentation
- CLI bootstrap, parser, usage/help output
- Command dispatch and command handlers
- Thin command modules that delegate orchestration

Paths:
- `lib/src/presentation/cli/bootstrap.dart`
- `lib/src/presentation/cli/bootstrap_support.dart`
- `lib/src/presentation/cli/cli_parser.dart`
- `lib/src/presentation/cli/commands/*.dart`

### Application
- Use-cases and orchestration services
- Installer orchestration and multi-registry add-resolution services

Paths:
- `lib/src/application/use_cases/**`
- `lib/src/application/services/**`

### Domain
- Entities, value objects, and policies
- Repository contracts

Paths:
- `lib/src/domain/entities/**`
- `lib/src/domain/value_objects/**`
- `lib/src/domain/policies/**`
- `lib/src/domain/repositories/**`

### Infrastructure
- Filesystem/network/process/cache adapters
- Registry/persistence/schema implementations

Paths:
- `lib/src/infrastructure/io/**`
- `lib/src/infrastructure/network/**`
- `lib/src/infrastructure/cache/**`
- `lib/src/infrastructure/registry/**`
- `lib/src/infrastructure/persistence/**`
- `lib/src/infrastructure/validation/**`
- `lib/src/infrastructure/resolver/**`

## Refactor outcomes (completed)
1. `installer.dart` decomposed into focused modules:
- `installer_dry_run_part.dart`
- `installer_shared_part.dart`
- `installer_manifest_part.dart`
- `installer_file_install_part.dart`
- `installer_platform_alias_part.dart`
- `installer_pubspec_part.dart`
- existing: `installer_theme_part.dart`, `installer_config_part.dart`, `installer_remove_part.dart`
2. `multi_registry_manager.dart` decomposed into focused modules:
- `multi_registry_init_part.dart`
- `multi_registry_add_part.dart`
- `multi_registry_assets_part.dart`
- `multi_registry_directory_part.dart`
3. Bootstrap routing/preload decision logic extracted to `bootstrap_support.dart`.

## Dependency rules
1. `presentation` may call `application` services/use-cases and stable orchestration APIs.
2. `domain` has no dependency on presentation/application/infrastructure.
3. `infrastructure` implements domain repository contracts.
4. Resolver/path safety rules remain centralized and reused across command flows.
