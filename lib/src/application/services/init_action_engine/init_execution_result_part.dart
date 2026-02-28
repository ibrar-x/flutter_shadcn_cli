part of 'init_action_engine.dart';

class InitExecutionResult {
  final int dirsCreated;
  final int filesWritten;
  final List<String> messages;
  final InitExecutionRecord record;

  const InitExecutionResult({
    required this.dirsCreated,
    required this.filesWritten,
    required this.messages,
    required this.record,
  });
}
