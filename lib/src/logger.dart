import 'dart:io';

class CliLogger {
  final bool verbose;

  const CliLogger({this.verbose = false});

  void header(String message) => _write('✨ $message');

  void action(String message) => _write('• $message');

  void success(String message) => _write('✓ $message');

  void warn(String message) => _write('! $message');

  void info(String message) => _write(message);

  void detail(String message) {
    if (verbose) {
      _write('  - $message');
    }
  }

  void _write(String message) {
    stdout.writeln(message);
  }
}
