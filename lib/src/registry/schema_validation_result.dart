class SchemaValidationResult {
  final bool isValid;
  final List<String> errors;

  const SchemaValidationResult({
    required this.isValid,
    required this.errors,
  });
}
