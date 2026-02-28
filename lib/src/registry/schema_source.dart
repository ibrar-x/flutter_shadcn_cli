class SchemaSource {
  final String label;
  final Future<String> Function() read;

  const SchemaSource({
    required this.label,
    required this.read,
  });
}
