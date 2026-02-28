part of 'init_action_engine.dart';

class InitActionEngineException implements Exception {
  final String message;

  InitActionEngineException(this.message);

  @override
  String toString() => message;
}
