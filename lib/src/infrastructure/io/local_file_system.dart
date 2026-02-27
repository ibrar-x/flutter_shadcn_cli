import 'dart:io';

class LocalFileSystem {
  const LocalFileSystem();

  bool exists(String path) => File(path).existsSync();
}
