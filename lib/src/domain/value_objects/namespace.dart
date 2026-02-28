class Namespace {
  final String value;

  const Namespace(this.value);

  bool get isValid => value.trim().isNotEmpty;
}
