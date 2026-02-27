abstract class FileRepository {
  Future<bool> exists(String path);
  Future<void> write(String path, String contents);
}
