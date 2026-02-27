import 'package:flutter_shadcn_cli/src/config.dart';
import 'package:flutter_shadcn_cli/src/domain/entities/config_model.dart';
import 'package:flutter_shadcn_cli/src/domain/repositories/config_repository.dart';

class ConfigRepositoryAdapter implements ConfigRepository {
  final String projectRoot;

  const ConfigRepositoryAdapter({required this.projectRoot});

  @override
  Future<DomainConfigModel> load() async {
    final config = await ShadcnConfig.load(projectRoot);
    return DomainConfigModel(
      defaultNamespace: config.effectiveDefaultNamespace,
    );
  }

  @override
  Future<void> save(DomainConfigModel config) async {
    final current = await ShadcnConfig.load(projectRoot);
    await ShadcnConfig.save(
      projectRoot,
      current.copyWith(defaultNamespace: config.defaultNamespace),
    );
  }
}
