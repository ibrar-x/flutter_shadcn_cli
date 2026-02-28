import 'package:flutter_shadcn_cli/src/domain/entities/registry_entry.dart';

abstract class RegistryRepository {
  Future<List<DomainRegistryEntry>> listRegistries();
}
