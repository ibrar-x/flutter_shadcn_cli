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

    for (final comp in components) {
      final score = comp.relevanceScore(query);
      final scoreBar = '█' * ((score / 10).ceil().clamp(0, 10));
      print('  ${comp.id.padRight(20)} ${comp.name}');
      print('    ${comp.description}');
      print('    Tags: ${comp.tags.join(", ")}');
      print('    Relevance: $scoreBar ($score)');
      print('');
    }

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
    print('  ID:           ${comp.id}');
    print('  Name:         ${comp.name}');
    print('  Category:     ${comp.category}');
    print('  Description:  ${comp.description}');
    print('');

    if (comp.tags.isNotEmpty) {
      print('  Tags:');
      for (final tag in comp.tags) {
        print('    • $tag');
      }
      print('');
    }

    if (comp.install.isNotEmpty) {
      print('  Install:      ${comp.install}');
    }
    if (comp.import_.isNotEmpty) {
      print('  Import:       ${comp.import_}');
    }
    if (comp.importPath.isNotEmpty) {
      print('  Import Path:  ${comp.importPath}');
    }
    print('');

    if (comp.api.isNotEmpty) {
      print('  API:');
      final constructors = comp.api['constructors'] as List? ?? [];
      final callbacks = comp.api['callbacks'] as List? ?? [];
      if (constructors.isNotEmpty) {
        print('    Constructors:');
        for (final c in constructors) {
          print('      • $c');
        }
      }
      if (callbacks.isNotEmpty) {
        print('    Callbacks:');
        for (final cb in callbacks) {
          print('      • $cb');
        }
      }
      print('');
    }

    if (comp.examples.isNotEmpty) {
      print('  Examples:');
      for (final entry in comp.examples.entries) {
        final label = entry.key;
        final value = entry.value;
        print('    • $label');
        if (value is String && value.trim().isNotEmpty) {
          final lines = value.trimRight().split('\n');
          for (final line in lines) {
            print('      $line');
          }
        }
      }
      print('');
    }

    if ((comp.dependencies['shared'] as List?)?.isNotEmpty ?? false) {
      print('  Shared Dependencies:');
      for (final dep in comp.dependencies['shared'] as List) {
        print('    • $dep');
      }
      print('');
    }

    if ((comp.dependencies['pubspec'] as Map?)?.isNotEmpty ?? false) {
      print('  Package Dependencies:');
      for (final dep in (comp.dependencies['pubspec'] as Map).keys) {
        print('    • $dep');
      }
      print('');
    }

    if (comp.related.isNotEmpty) {
      print('  Related:');
      for (final rel in comp.related) {
        print('    • $rel');
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
