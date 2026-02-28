import 'package:flutter_shadcn_cli/src/core/result/result.dart';

class ChooseDefaultRegistryUseCase {
  Future<AppResult<String>> call() async {
    return const AppResult.success('shadcn');
  }
}
