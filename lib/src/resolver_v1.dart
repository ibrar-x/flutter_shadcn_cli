import 'package:path/path.dart' as p;

class ResolverV1Exception implements Exception {
  final String message;

  ResolverV1Exception(this.message);

  @override
  String toString() => message;
}

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

class ProjectPathGuard {
  static String resolveSafeWritePath({
    required String projectRoot,
    required String destinationRelativePath,
  }) {
    final rootAbs = p.normalize(p.absolute(projectRoot));
    final relative = destinationRelativePath.trim();
    if (relative.isEmpty) {
      throw ResolverV1Exception('destination path cannot be empty');
    }
    if (p.isAbsolute(relative)) {
      throw ResolverV1Exception('destination path must be project-relative');
    }

    final destinationAbs = p.normalize(p.join(rootAbs, relative));
    final withinRoot =
        destinationAbs == rootAbs || p.isWithin(rootAbs, destinationAbs);
    if (!withinRoot) {
      throw ResolverV1Exception(
        'destination escapes project root: $destinationRelativePath',
      );
    }
    return destinationAbs;
  }
}

class InitPathMapper {
  static String mapCopyFileDestination({
    required String filePath,
    String? base,
    String? destBase,
  }) {
    if ((base == null) != (destBase == null)) {
      throw ResolverV1Exception('base and destBase must be provided together');
    }
    if (base == null) {
      return filePath;
    }

    final expectedPrefix = '$base/';
    if (!filePath.startsWith(expectedPrefix)) {
      throw ResolverV1Exception(
        'file path does not start with required base prefix: $filePath',
      );
    }
    final stripped = filePath.substring(expectedPrefix.length);
    if (stripped.isEmpty) {
      throw ResolverV1Exception('file path cannot map to empty destination');
    }
    return p.posix.join(destBase!, stripped);
  }

  static String mapCopyDirDestination({
    required String filePath,
    required String from,
    required String to,
    String? base,
    String? destBase,
  }) {
    if ((base == null) != (destBase == null)) {
      throw ResolverV1Exception('base and destBase must be provided together');
    }

    final normalizedFrom = from.replaceAll('\\', '/');
    final filePrefix =
        base == null ? '$normalizedFrom/' : '$base/$normalizedFrom/';
    if (!filePath.startsWith(filePrefix)) {
      throw ResolverV1Exception(
        'copyDir source file is outside expected prefix: $filePath',
      );
    }

    final relativeTail = filePath.substring(filePrefix.length);
    if (relativeTail.isEmpty) {
      throw ResolverV1Exception('copyDir source file must point to a file');
    }
    var destination = p.posix.join(to, relativeTail);
    if (destBase != null) {
      destination = p.posix.join(destBase, destination);
    }
    return destination;
  }
}
