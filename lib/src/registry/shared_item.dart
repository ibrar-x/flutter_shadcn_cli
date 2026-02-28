import 'package:flutter_shadcn_cli/src/registry/registry_file.dart';

class SharedItem {
  final String id;
  final List<RegistryFile> files;

  SharedItem.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        files = (json['files'] as List)
            .map((e) => RegistryFile.fromJson(e))
            .toList();
}
