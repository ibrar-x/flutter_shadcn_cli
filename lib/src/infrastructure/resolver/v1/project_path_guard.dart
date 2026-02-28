import 'package:flutter_shadcn_cli/src/infrastructure/resolver/v1/resolver_v1_exception.dart';
import 'package:path/path.dart' as p;

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
