import 'package:flutter_shadcn_cli/src/application/dto/add_request.dart';
import 'package:flutter_shadcn_cli/src/application/dto/qualified_component_ref.dart';
import 'package:flutter_shadcn_cli/src/config.dart';

typedef ComponentExistsInNamespace = Future<bool> Function(
  String namespace,
  String componentId,
);

class AddResolutionService {
  const AddResolutionService();

  static QualifiedComponentRef? parseQualifiedComponentRef(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('@')) {
      final slash = trimmed.indexOf('/');
      if (slash <= 1 || slash == trimmed.length - 1) {
        return null;
      }
      final namespace = trimmed.substring(1, slash).trim();
      final componentId = trimmed.substring(slash + 1).trim();
      if (namespace.isEmpty || componentId.isEmpty) {
        return null;
      }
      return QualifiedComponentRef(
        namespace: namespace,
        componentId: componentId,
      );
    }

    final split = trimmed.split(':');
    if (split.length == 2 && split[0].isNotEmpty && split[1].isNotEmpty) {
      return QualifiedComponentRef(
        namespace: split[0].trim(),
        componentId: split[1].trim(),
      );
    }

    return null;
  }

  Future<List<AddRequest>> resolveAddRequests({
    required List<String> requested,
    required ShadcnConfig config,
    required ComponentExistsInNamespace componentExists,
  }) async {
    final resolved = <AddRequest>[];

    final enabled = (config.registries ?? const <String, RegistryConfigEntry>{})
        .entries
        .where((entry) => entry.value.enabled)
        .map((entry) => entry.key)
        .toSet();
    final defaultNamespace = config.effectiveDefaultNamespace;
    if (enabled.isEmpty) {
      enabled.add(defaultNamespace);
    }

    for (final token in requested) {
      final qualified = parseQualifiedComponentRef(token);
      if (qualified != null) {
        resolved.add(
          AddRequest(
            namespace: qualified.namespace,
            componentId: qualified.componentId,
          ),
        );
        continue;
      }

      if (enabled.contains(defaultNamespace) &&
          await componentExists(defaultNamespace, token)) {
        resolved.add(AddRequest(namespace: defaultNamespace, componentId: token));
        continue;
      }

      final candidates = <String>[];
      for (final namespace in enabled) {
        if (await componentExists(namespace, token)) {
          candidates.add(namespace);
        }
      }

      if (candidates.isEmpty) {
        throw Exception('Component "$token" not found.');
      }
      if (candidates.length > 1) {
        candidates.sort();
        throw Exception(
          'Component "$token" is ambiguous across registries (${candidates.join(', ')}). '
          'Use namespace-qualified form: @<namespace>/$token',
        );
      }
      resolved.add(
        AddRequest(namespace: candidates.first, componentId: token),
      );
    }

    return resolved;
  }
}
