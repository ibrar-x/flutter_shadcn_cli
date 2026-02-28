class AppResult<T> {
  final T? data;
  final String? error;
  final int exitCode;

  const AppResult.success(this.data, {this.exitCode = 0}) : error = null;
  const AppResult.failure(this.error, {this.exitCode = 1}) : data = null;

  bool get isSuccess => error == null;
}
