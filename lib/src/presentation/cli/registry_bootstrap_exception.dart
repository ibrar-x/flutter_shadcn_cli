import 'package:flutter_shadcn_cli/src/exit_codes.dart';

class RegistryBootstrapException implements Exception {
  final String registryRoot;
  final String message;

  const RegistryBootstrapException(this.registryRoot, this.message);

  int exitCode() {
    if (message.contains('Offline mode')) {
      return ExitCodes.offlineUnavailable;
    }
    if (message.contains('Failed to fetch')) {
      return ExitCodes.networkError;
    }
    return ExitCodes.registryNotFound;
  }
}
