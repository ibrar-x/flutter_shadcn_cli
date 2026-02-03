import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Manages loading and caching of registry index.json with staleness checking.
class IndexLoader {
  static const _cacheDir = '~/.flutter_shadcn/cache';
  static const _stalenessDuration = Duration(hours: 24);

  final String registryId;
  final String registryBaseUrl;
  final bool refresh;

  IndexLoader({
    required this.registryId,
    required this.registryBaseUrl,
    this.refresh = false,
  });

  /// Loads index.json from cache or remote, with staleness checking.
  /// 
  /// Returns the parsed JSON if available, otherwise throws an exception.
  /// 
  /// Strategy:
  /// 1. Check cache directory for existing index.json
  /// 2. If missing or stale (more than 24h old), download from {registryBaseUrl}/dist/index.json
  /// 3. Cache the downloaded file
  /// 4. Parse and return as Map
  Future<Map<String, dynamic>> load() async {
    final cacheFile = _getCacheFile();
    final shouldRefresh = refresh || _isStale(cacheFile);

    if (!shouldRefresh && cacheFile.existsSync()) {
      try {
        return await _parseCache(cacheFile);
      } catch (e) {
        // Cache corrupted, fall through to download
      }
    }

    // Download from remote
    return await _downloadAndCache();
  }

  /// Gets or creates the cache file path.
  File _getCacheFile() {
    final expandedPath = _cacheDir.replaceFirst('~', _getHomeDir());
    final cacheDir = Directory(p.join(expandedPath, registryId));
    
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    return File(p.join(cacheDir.path, 'index.json'));
  }

  /// Returns true if cache file exists and is older than 24 hours.
  bool _isStale(File cacheFile) {
    if (!cacheFile.existsSync()) return true;

    final stat = cacheFile.statSync();
    final age = DateTime.now().difference(stat.modified);
    return age > _stalenessDuration;
  }

  /// Parses cache file as JSON.
  Future<Map<String, dynamic>> _parseCache(File cacheFile) async {
    final content = await cacheFile.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Downloads index.json from remote registry and caches it.
  Future<Map<String, dynamic>> _downloadAndCache() async {
    final url = _resolveIndexUrl();
    final response = await http.get(Uri.parse(url));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to fetch index.json from $url (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    // Cache the downloaded file
    final cacheFile = _getCacheFile();
    await cacheFile.writeAsString(
      jsonEncode(data),
      flush: true,
    );

    return data;
  }

  /// Resolves the full URL to the remote index.json.
  String _resolveIndexUrl() {
    final base = registryBaseUrl.endsWith('/') 
        ? registryBaseUrl 
        : '$registryBaseUrl/';
    return '${base}dist/index.json';
  }

  /// Returns the user's home directory.
  static String _getHomeDir() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return env['USERPROFILE'] ?? env['HOME'] ?? '.';
    }
    return env['HOME'] ?? '.';
  }
}

/// Represents a component from the index.
class IndexComponent {
  final String id;
  final String name;
  final String category;
  final String description;
  final List<String> tags;
  final String install;
  final String import_;
  final String importPath;
  final Map<String, dynamic> api;
  final Map<String, dynamic> examples;
  final Map<String, dynamic> dependencies;
  final List<String> related;

  const IndexComponent({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.tags,
    required this.install,
    required this.import_,
    required this.importPath,
    required this.api,
    required this.examples,
    required this.dependencies,
    required this.related,
  });

  factory IndexComponent.fromJson(Map<String, dynamic> json) {
    return IndexComponent(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      tags: List<String>.from(json['tags'] as List? ?? []),
      install: json['install'] as String? ?? '',
      import_: json['import'] as String? ?? '',
      importPath: json['importPath'] as String? ?? '',
      api: json['api'] as Map<String, dynamic>? ?? {},
      examples: json['examples'] as Map<String, dynamic>? ?? {},
      dependencies: json['dependencies'] as Map<String, dynamic>? ?? {},
      related: List<String>.from(json['related'] as List? ?? []),
    );
  }

  /// Checks if component matches any of the search terms.
  bool matches(String query) {
    final lower = query.toLowerCase();
    return id.contains(lower) ||
        name.toLowerCase().contains(lower) ||
        description.toLowerCase().contains(lower) ||
        tags.any((tag) => tag.toLowerCase().contains(lower)) ||
        related.any((rel) => rel.toLowerCase().contains(lower));
  }

  /// Returns a relevance score for ranking search results (higher = more relevant).
  int relevanceScore(String query) {
    final lower = query.toLowerCase();
    var score = 0;

    if (id.toLowerCase() == lower) score += 100;
    if (id.toLowerCase().contains(lower)) score += 50;
    if (name.toLowerCase() == lower) score += 80;
    if (name.toLowerCase().contains(lower)) score += 40;
    if (tags.contains(lower)) score += 60;
    if (description.toLowerCase().contains(lower)) score += 10;

    return score;
  }
}
