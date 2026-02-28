part of 'installer.dart';

class _RegistryFileOwner {
  final String id;
  final bool isShared;
  final RegistryFile file;

  const _RegistryFileOwner({
    required this.id,
    required this.isShared,
    required this.file,
  });

  factory _RegistryFileOwner.shared(String id, RegistryFile file) {
    return _RegistryFileOwner(id: id, isShared: true, file: file);
  }

  factory _RegistryFileOwner.component(String id, RegistryFile file) {
    return _RegistryFileOwner(id: id, isShared: false, file: file);
  }

  bool get isComponent => !isShared;
}
