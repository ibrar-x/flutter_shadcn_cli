import 'package:flutter_shadcn_cli/src/index_loader.dart';
import 'package:flutter_shadcn_cli/src/logger.dart';

/// Handles `flutter_shadcn list` command.
/// 
/// Loads the index and prints all components with id, category, and description.
Future<void> handleListCommand({
  required String registryBaseUrl,
  required String registryId,
  required bool refresh,
  required CliLogger logger,
}) async {
  logger.section('📦 Available Components');

  try {
    final loader = IndexLoader(
      registryId: registryId,
      registryBaseUrl: registryBaseUrl,
      refresh: refresh,
    );

    final index = await loader.load();
    final components = (index['components'] as List?)
        ?.map((c) => IndexComponent.fromJson(c as Map<String, dynamic>))
        .toList() ??
        [];

    if (components.isEmpty) {
      logger.info('No components found.');
      return;
    }

    // Group by category
    final byCategory = <String, List<IndexComponent>>{};
    for (final comp in components) {
      byCategory.putIfAbsent(comp.category, () => []).add(comp);
    }

    // Print grouped with beautiful formatting
    final sortedCategories = byCategory.keys.toList()..sort();
    
    for (final category in sortedCategories) {
      // Category header with emoji
      final categoryEmoji = _getCategoryEmoji(category);
      print('');
      print('$categoryEmoji  \x1B[1m${category.toUpperCase()}\x1B[0m');
      print('─' * 60);
      
      final categoryComponents = byCategory[category]!;
      for (var i = 0; i < categoryComponents.length; i++) {
        final comp = categoryComponents[i];
        final isLast = i == categoryComponents.length - 1;
        
        // Component name with box drawing
        final prefix = isLast ? '└─' : '├─';
        print('  $prefix \x1B[36m${comp.id.padRight(20)}\x1B[0m \x1B[1m${comp.name}\x1B[0m');
        
        // Description with subtle color
        if (comp.description.isNotEmpty) {
          final descPrefix = isLast ? '   ' : '│  ';
          final wrappedDesc = _wrapText(comp.description, 56);
          for (final line in wrappedDesc) {
            print('  $descPrefix \x1B[90m$line\x1B[0m');
          }
        }
      }
    }

    print('');
    print('═' * 60);
    logger.info('${components.length} components total.');
  } catch (e) {
    logger.error('Failed to load components: $e');
    logger.info('Tip: Check your registry URL or run with --registry-url for a custom location.');
    return;
  }
}

/// Handles `flutter_shadcn search <query>` command.
/// 
/// Loads the index, filters and ranks by relevance, and prints matches.
Future<void> handleSearchCommand({
  required String query,
  required String registryBaseUrl,
  required String registryId,
  required bool refresh,
  required CliLogger logger,
}) async {
  if (query.isEmpty) {
    logger.error('Please provide a search query.');
    return;
  }

  logger.section('🔍 Search Results: "$query"');

  try {
    final loader = IndexLoader(
      registryId: registryId,
      registryBaseUrl: registryBaseUrl,
      refresh: refresh,
    );

    final index = await loader.load();
    var components = (index['components'] as List?)
        ?.map((c) => IndexComponent.fromJson(c as Map<String, dynamic>))
        .toList() ??
        [];

    // Filter by query
    components = components.where((c) => c.matches(query)).toList();

    if (components.isEmpty) {
      logger.info('No matches found for "$query".');
      return;
    }

    // Sort by relevance score
    components.sort((a, b) => b.relevanceScore(query).compareTo(a.relevanceScore(query)));

    print('');
    for (var i = 0; i < components.length; i++) {
      final comp = components[i];
      final score = comp.relevanceScore(query);
      final scoreBar = '\x1B[32m${'█' * ((score / 10).ceil().clamp(0, 10))}\x1B[0m';
      final isLast = i == components.length - 1;
      final prefix = isLast ? '└─' : '├─';
      
      print('  $prefix \x1B[36m${comp.id.padRight(20)}\x1B[0m \x1B[1m${comp.name}\x1B[0m');
      if (comp.description.isNotEmpty) {
        final descPrefix = isLast ? '   ' : '│  ';
        print('  $descPrefix \x1B[90m${comp.description}\x1B[0m');
      }
      if (comp.tags.isNotEmpty) {
        final tagsPrefix = isLast ? '   ' : '│  ';
        print('  $tagsPrefix \x1B[35m🏷️  ${comp.tags.join(", ")}\x1B[0m');
      }
      final scorePrefix = isLast ? '   ' : '│  ';
      print('  $scorePrefix $scoreBar \x1B[90m($score pts)\x1B[0m');
      
      if (!isLast) print('  │');
    }

    print('');
    print('═' * 60);
    logger.info('Found ${components.length} matching components.');
  } catch (e) {
    logger.error('Failed to search components: $e');
    logger.info('Tip: Check your registry URL or run with --registry-url for a custom location.');
    return;
  }
}

/// Handles `flutter_shadcn info <id>` command.
/// 
/// Loads the index, finds the component, and displays full details.
Future<void> handleInfoCommand({
  required String componentId,
  required String registryBaseUrl,
  required String registryId,
  required bool refresh,
  required CliLogger logger,
}) async {
  if (componentId.isEmpty) {
    logger.error('Please provide a component id.');
    return;
  }

  try {
    final loader = IndexLoader(
      registryId: registryId,
      registryBaseUrl: registryBaseUrl,
      refresh: refresh,
    );

    final index = await loader.load();
    final components = (index['components'] as List?)
        ?.map((c) => IndexComponent.fromJson(c as Map<String, dynamic>))
        .toList() ??
        [];

    final comp = components.firstWhere(
      (c) => c.id == componentId,
      orElse: () => throw Exception('Component "$componentId" not found'),
    );

    logger.section('📋 Component: ${comp.name}');
    print('');
    print('  \x1B[1mID:\x1B[0m           \x1B[36m${comp.id}\x1B[0m');
    print('  \x1B[1mName:\x1B[0m         ${comp.name}');
    print('  \x1B[1mCategory:\x1B[0m     \x1B[35m${_getCategoryEmoji(comp.category)} ${comp.category}\x1B[0m');
    print('  \x1B[1mDescription:\x1B[0m  \x1B[90m${comp.description}\x1B[0m');
    print('');

    if (comp.tags.isNotEmpty) {
      print('  \x1B[1mTags:\x1B[0m');
      for (final tag in comp.tags) {
        print('    \x1B[35m🏷️  $tag\x1B[0m');
      }
      print('');
    }

    if (comp.install.isNotEmpty) {
      print('  \x1B[1mInstall:\x1B[0m      \x1B[32m${comp.install}\x1B[0m');
    }
    if (comp.import_.isNotEmpty) {
      print('  \x1B[1mImport:\x1B[0m       \x1B[90m${comp.import_}\x1B[0m');
    }
    if (comp.importPath.isNotEmpty) {
      print('  \x1B[1mImport Path:\x1B[0m  \x1B[90m${comp.importPath}\x1B[0m');
    }
    print('');

    if (comp.api.isNotEmpty) {
      print('  \x1B[1mAPI:\x1B[0m');
      final constructors = comp.api['constructors'] as List? ?? [];
      final callbacks = comp.api['callbacks'] as List? ?? [];
      if (constructors.isNotEmpty) {
        print('    \x1B[1mConstructors:\x1B[0m');
        for (final c in constructors) {
          print('      \x1B[33m▸\x1B[0m $c');
        }
      }
      if (callbacks.isNotEmpty) {
        print('    \x1B[1mCallbacks:\x1B[0m');
        for (final cb in callbacks) {
          print('      \x1B[33m▸\x1B[0m $cb');
        }
      }
      print('');
    }

    if (comp.examples.isNotEmpty) {
      print('  \x1B[1mExamples:\x1B[0m');
      for (final entry in comp.examples.entries) {
        final label = entry.key;
        final value = entry.value;
        print('    \x1B[32m●\x1B[0m \x1B[1m$label\x1B[0m');
        if (value is String && value.trim().isNotEmpty) {
          final lines = value.trimRight().split('\n');
          for (final line in lines) {
            print('      \x1B[90m$line\x1B[0m');
          }
        }
      }
      print('');
    }

    if ((comp.dependencies['shared'] as List?)?.isNotEmpty ?? false) {
      print('  \x1B[1mShared Dependencies:\x1B[0m');
      for (final dep in comp.dependencies['shared'] as List) {
        print('    \x1B[34m📦\x1B[0m $dep');
      }
      print('');
    }

    if ((comp.dependencies['pubspec'] as Map?)?.isNotEmpty ?? false) {
      print('  \x1B[1mPackage Dependencies:\x1B[0m');
      for (final dep in (comp.dependencies['pubspec'] as Map).keys) {
        print('    \x1B[34m📦\x1B[0m $dep');
      }
      print('');
    }

    if (comp.related.isNotEmpty) {
      print('  \x1B[1mRelated:\x1B[0m');
      for (final rel in comp.related) {
        print('    \x1B[35m→\x1B[0m $rel');
      }
      print('');
    }
  } catch (e) {
    logger.error('Failed to load component info: $e');
    logger.info('Tip: Check your registry URL or run with --registry-url for a custom location.');
    return;
  }
}

/// Returns an emoji for each category
String _getCategoryEmoji(String category) {
  switch (category.toLowerCase()) {
    case 'layout':
      return '📐';
    case 'overlay':
      return '🎭';
    case 'utility':
      return '🔧';
    case 'form':
      return '📝';
    case 'display':
      return '💎';
    case 'navigation':
      return '🧭';
    case 'control':
      return '🎮';
    case 'animation':
      return '✨';
    default:
      return '📦';
  }
}

/// Wraps text to a maximum width
List<String> _wrapText(String text, int maxWidth) {
  final words = text.split(' ');
  final lines = <String>[];
  var currentLine = '';

  for (final word in words) {
    if (currentLine.isEmpty) {
      currentLine = word;
    } else if ((currentLine.length + word.length + 1) <= maxWidth) {
      currentLine += ' $word';
    } else {
      lines.add(currentLine);
      currentLine = word;
    }
  }

  if (currentLine.isNotEmpty) {
    lines.add(currentLine);
  }

  return lines.isEmpty ? [''] : lines;
}
