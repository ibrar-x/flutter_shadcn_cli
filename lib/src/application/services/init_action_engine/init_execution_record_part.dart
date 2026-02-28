part of 'init_action_engine.dart';

class InitExecutionRecord {
  final List<String> dirsCreated;
  final List<String> filesWritten;
  final InitPubspecDelta pubspecDelta;

  const InitExecutionRecord({
    required this.dirsCreated,
    required this.filesWritten,
    required this.pubspecDelta,
  });

  static const empty = InitExecutionRecord(
    dirsCreated: <String>[],
    filesWritten: <String>[],
    pubspecDelta: InitPubspecDelta.empty,
  );

  Map<String, dynamic> toJson() {
    return {
      'dirsCreated': dirsCreated,
      'filesWritten': filesWritten,
      'pubspecDelta': pubspecDelta.toJson(),
    };
  }

  factory InitExecutionRecord.fromJson(Map<String, dynamic> json) {
    return InitExecutionRecord(
      dirsCreated:
          (json['dirsCreated'] as List<dynamic>? ?? const []).cast<String>(),
      filesWritten:
          (json['filesWritten'] as List<dynamic>? ?? const []).cast<String>(),
      pubspecDelta: InitPubspecDelta.fromJson(
        (json['pubspecDelta'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value),
            ) ??
            const <String, dynamic>{},
      ),
    );
  }
}
