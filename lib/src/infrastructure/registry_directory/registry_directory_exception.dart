class RegistryDirectoryException implements Exception {
  final String message;

  RegistryDirectoryException(this.message);

  @override
  String toString() => message;
}
