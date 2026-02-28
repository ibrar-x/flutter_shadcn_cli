class ResolverV1Exception implements Exception {
  final String message;

  ResolverV1Exception(this.message);

  @override
  String toString() => message;
}
