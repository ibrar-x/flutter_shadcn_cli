class LegacyUrlResolver {
  static Uri resolveUrl(String baseUrl, String relativePath) {
    final normalizedBase = _normalizeBaseUrl(baseUrl);
    final normalizedRelative = _normalizeRelativePath(relativePath);
    return Uri.parse('$normalizedBase$normalizedRelative');
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw Exception('baseUrl cannot be empty');
    }

    final uri = Uri.parse(trimmed);
    if (uri.scheme.isEmpty || uri.host.isEmpty) {
      throw Exception('baseUrl must be an absolute URL');
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw Exception('baseUrl cannot include query or fragment');
    }

    final path = uri.path.replaceAll(RegExp(r'/+'), '/');
    final withoutTrailing = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    final withTrailing =
        withoutTrailing.endsWith('/') ? withoutTrailing : '$withoutTrailing/';
    return uri.replace(path: withTrailing).toString();
  }

  static String _normalizeRelativePath(String relativePath) {
    final trimmed = relativePath.trim();
    if (trimmed.isEmpty) {
      throw Exception('relativePath cannot be empty');
    }
    if (trimmed.contains('..')) {
      throw Exception('relativePath cannot contain ".."');
    }
    if (trimmed.contains(r'\')) {
      throw Exception('relativePath cannot contain backslashes');
    }
    if (trimmed.contains('?') || trimmed.contains('#')) {
      throw Exception(
        'relativePath cannot contain query or fragment tokens',
      );
    }

    final normalized = trimmed.replaceFirst(RegExp(r'^/+'), '');
    if (normalized.isEmpty) {
      throw Exception('relativePath cannot resolve to empty');
    }
    final segments = normalized.split('/');
    if (segments.any((segment) => segment.isEmpty)) {
      throw Exception('relativePath cannot contain empty path segments');
    }
    return normalized;
  }
}
