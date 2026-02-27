import 'package:flutter_shadcn_cli/src/core/result/result.dart';

class SetDefaultRegistryUseCase {
  Future<AppResult<String>> call(String namespace) async {
    return AppResult.success(namespace);
  }
}
