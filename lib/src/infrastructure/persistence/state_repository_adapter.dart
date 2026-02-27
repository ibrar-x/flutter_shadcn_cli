import 'package:flutter_shadcn_cli/src/domain/entities/state_model.dart';
import 'package:flutter_shadcn_cli/src/domain/repositories/state_repository.dart';
import 'package:flutter_shadcn_cli/src/state.dart';

class StateRepositoryAdapter implements StateRepository {
  final String projectRoot;
  final String defaultNamespace;

  const StateRepositoryAdapter({
    required this.projectRoot,
    this.defaultNamespace = 'shadcn',
  });

  @override
  Future<DomainStateModel> load() async {
    final state = await ShadcnState.load(
      projectRoot,
      defaultNamespace: defaultNamespace,
    );
    return DomainStateModel(
      managedDependencies:
          List<String>.from(state.managedDependencies ?? const <String>[]),
    );
  }

  @override
  Future<void> save(DomainStateModel stateModel) async {
    final current = await ShadcnState.load(
      projectRoot,
      defaultNamespace: defaultNamespace,
    );
    await ShadcnState.save(
      projectRoot,
      ShadcnState(
        installPath: current.installPath,
        sharedPath: current.sharedPath,
        themeId: current.themeId,
        managedDependencies: List<String>.from(stateModel.managedDependencies),
        registries: current.registries,
      ),
    );
  }
}
