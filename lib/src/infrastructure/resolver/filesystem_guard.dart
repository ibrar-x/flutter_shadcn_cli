import 'package:path/path.dart' as p;

class FilesystemGuard {
  const FilesystemGuard();

  void assertWithinRoot({required String root, required String targetPath}) {
    final normalizedRoot = p.normalize(root);
    final normalizedTarget = p.normalize(targetPath);
    if (!normalizedTarget.startsWith(normalizedRoot)) {
      throw Exception('Path escapes root: $targetPath');
    }
  }
}
