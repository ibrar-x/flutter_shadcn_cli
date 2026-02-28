part of 'init_action_engine.dart';

class InitRollbackResult {
  final int filesRemoved;
  final int dirsRemoved;
  final InitPubspecDelta reverted;

  const InitRollbackResult({
    required this.filesRemoved,
    required this.dirsRemoved,
    required this.reverted,
  });
}
