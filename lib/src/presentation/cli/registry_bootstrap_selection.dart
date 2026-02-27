import 'package:flutter_shadcn_cli/src/presentation/cli/registry_selection.dart';
import 'package:flutter_shadcn_cli/src/registry.dart';

class RegistryBootstrapSelection {
  final RegistrySelection selection;
  final Registry registry;

  const RegistryBootstrapSelection({
    required this.selection,
    required this.registry,
  });
}
