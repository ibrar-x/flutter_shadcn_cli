class MultiRegistryException implements Exception {
  final String message;

  MultiRegistryException(this.message);

  @override
  String toString() => message;
}
