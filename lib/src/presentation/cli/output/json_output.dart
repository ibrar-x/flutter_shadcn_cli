import 'dart:convert';

const _jsonEncoder = JsonEncoder.withIndent('  ');

Map<String, dynamic> jsonEnvelope({
  required String command,
  required Map<String, dynamic> data,
  List<Map<String, dynamic>> errors = const [],
  List<Map<String, dynamic>> warnings = const [],
  Map<String, dynamic>? meta,
}) {
  return {
    'status': errors.isEmpty ? 'ok' : 'error',
    'command': command,
    'data': data,
    'errors': errors,
    'warnings': warnings,
    'meta': {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (meta != null) ...meta,
    },
  };
}

Map<String, dynamic> jsonError({
  required String code,
  required String message,
  Map<String, dynamic>? details,
}) {
  return {
    'code': code,
    'message': message,
    if (details != null) 'details': details,
  };
}

Map<String, dynamic> jsonWarning({
  required String code,
  required String message,
  Map<String, dynamic>? details,
}) {
  return {
    'code': code,
    'message': message,
    if (details != null) 'details': details,
  };
}

void printJson(Map<String, dynamic> payload) {
  print(_jsonEncoder.convert(payload));
}
