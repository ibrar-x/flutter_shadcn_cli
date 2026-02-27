import 'package:flutter_shadcn_cli/src/infrastructure/resolver/v1/resolver_v1_exception.dart';

class ResolverV1 {
  static Uri resolveUrl(String baseUrl, String relativePath) {
    final normalizedBase = normalizeBaseUrl(baseUrl);
    final normalizedRelative = normalizeRelativePath(relativePath);
    return Uri.parse('$normalizedBase$normalizedRelative');
  }

  static String normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw ResolverV1Exception('baseUrl cannot be empty');
    }
    final uri = Uri.parse(trimmed);
    if (uri.scheme.isEmpty || uri.host.isEmpty) {
      throw ResolverV1Exception('baseUrl must be an absolute URL');
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw ResolverV1Exception('baseUrl cannot include query or fragment');
    }

    final cleanPath = uri.path.replaceAll(RegExp(r'/+'), '/');
    final withoutTrailing = cleanPath.endsWith('/') && cleanPath.length > 1
        ? cleanPath.substring(0, cleanPath.length - 1)
        : cleanPath;
    final withTrailing =
        withoutTrailing.endsWith('/') ? withoutTrailing : '$withoutTrailing/';
    return uri.replace(path: withTrailing).toString();
  }

  static String normalizeRelativePath(String relativePath) {
    final trimmed = relativePath.trim();
    if (trimmed.isEmpty) {
      throw ResolverV1Exception('relativePath cannot be empty');
    }
    if (trimmed.contains('..')) {
      throw ResolverV1Exception('relativePath cannot contain ".."');
    }
    if (trimmed.contains(r'\')) {
      throw ResolverV1Exception('relativePath cannot contain backslashes');
    }
    if (trimmed.contains('?') || trimmed.contains('#')) {
      throw ResolverV1Exception(
        'relativePath cannot contain query or fragment tokens',
      );
    }

    final normalized = trimmed.replaceFirst(RegExp(r'^/+'), '');
    if (normalized.isEmpty) {
      throw ResolverV1Exception('relativePath cannot resolve to empty');
    }
    final segments = normalized.split('/');
    if (segments.any((segment) => segment.isEmpty)) {
      throw ResolverV1Exception(
        'relativePath cannot contain empty path segments',
      );
    }
    return normalized;
  }
}
