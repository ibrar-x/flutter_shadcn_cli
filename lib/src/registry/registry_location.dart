import 'dart:convert';
import 'dart:io';

import 'package:flutter_shadcn_cli/src/resolver_v1.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class RegistryLocation {
  final String root;
  final bool isRemote;
  final bool offline;
  final http.Client _client;

  RegistryLocation.local(this.root, {this.offline = false})
      : isRemote = false,
        _client = http.Client();

  RegistryLocation.remote(this.root, {this.offline = false})
      : isRemote = true,
        _client = http.Client();

  Future<List<int>> readBytes(String relativePath) async {
    if (isRemote) {
      if (offline) {
        throw Exception('Offline mode: remote access disabled.');
      }
      final uri = _resolveRemote(relativePath);
      final response = await _client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed to fetch $uri (${response.statusCode})');
      }
      return response.bodyBytes;
    }
    final candidates = _localPathCandidates(relativePath);
    for (final path in candidates) {
      final file = File(p.join(root, path));
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }

    final attempted = File(p.join(root, relativePath)).path;
    throw Exception('File not found: $attempted');
  }

  Future<String> readString(String relativePath) async {
    final bytes = await readBytes(relativePath);
    return utf8.decode(bytes);
  }

  String describe(String relativePath) {
    if (isRemote) {
      return _resolveRemote(relativePath).toString();
    }
    return p.join(root, relativePath);
  }

  Uri _resolveRemote(String relativePath) {
    return ResolverV1.resolveUrl(root, relativePath);
  }

  List<String> _localPathCandidates(String relativePath) {
    final candidates = <String>[relativePath];
    final normalized = relativePath.replaceAll('\\', '/');
    final rootName = p.basename(root);
    if (rootName == 'registry' && normalized.startsWith('registry/')) {
      final stripped = normalized.substring('registry/'.length);
      if (stripped.isNotEmpty && stripped != relativePath) {
        candidates.add(stripped);
      }
    }
    return candidates;
  }
}
