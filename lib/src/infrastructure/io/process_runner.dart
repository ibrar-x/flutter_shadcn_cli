import 'dart:io';

class ProcessRunner {
  const ProcessRunner();

  Future<ProcessResult> run(String executable, List<String> args,
      {String? workingDirectory}) {
    return Process.run(executable, args, workingDirectory: workingDirectory);
  }
}
