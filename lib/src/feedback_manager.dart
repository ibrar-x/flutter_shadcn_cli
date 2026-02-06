import 'dart:io';
import 'package:flutter_shadcn_cli/src/logger.dart';

/// Manages user feedback and GitHub issue creation
class FeedbackManager {
  final CliLogger logger;
  
  static const String repoOwner = 'ibrar-x';
  static const String repoName = 'shadcn_flutter_kit';
  
  FeedbackManager({required this.logger});
  
  /// Shows feedback menu and handles user selection
  /// If [typeStr], [titleStr], and [bodyStr] are provided, skips interactive mode
  Future<void> showFeedbackMenu({
    String? type,
    String? title,
    String? body,
  }) async {
    // Non-interactive mode if all parameters provided
    if (type != null && title != null && body != null) {
      final feedbackType = _parseFeedbackType(type);
      if (feedbackType == null) {
        logger.error('Invalid feedback type: $type');
        logger.info('Valid types: bug, feature, docs, question, performance, other');
        return;
      }
      
      await _submitFeedback(
        feedbackType: feedbackType,
        title: title,
        description: body,
      );
      return;
    }
    
    // Interactive mode
    logger.section('💬 Feedback & Support');
    print('');
    print('Help us improve flutter_shadcn_cli! Choose feedback type:');
    print('');
    print('  \x1B[31m1.\x1B[0m \x1B[1m🐛 Bug Report\x1B[0m       - Something isn\'t working');
    print('  \x1B[32m2.\x1B[0m \x1B[1m✨ Feature Request\x1B[0m  - Suggest an idea');
    print('  \x1B[33m3.\x1B[0m \x1B[1m📖 Documentation\x1B[0m    - Improve or fix docs');
    print('  \x1B[36m4.\x1B[0m \x1B[1m❓ Question\x1B[0m         - Ask for help');
    print('  \x1B[35m5.\x1B[0m \x1B[1m⚡ Performance\x1B[0m      - Speed or memory issues');
    print('  \x1B[90m6.\x1B[0m \x1B[1m💡 Other\x1B[0m            - General feedback');
    print('');
    
    stdout.write('\x1B[1m❯\x1B[0m Select feedback type (1-6): ');
    final input = stdin.readLineSync()?.trim() ?? '';
    
    final typeNum = int.tryParse(input);
    if (typeNum == null || typeNum < 1 || typeNum > 6) {
      logger.error('Invalid selection. Please choose 1-6.');
      return;
    }
    
    await _handleFeedbackType(typeNum);
  }
  
  Future<void> _handleFeedbackType(int typeNum) async {
    final FeedbackType feedbackType;
    
    switch (typeNum) {
      case 1:
        feedbackType = FeedbackType.bug;
        break;
      case 2:
        feedbackType = FeedbackType.feature;
        break;
      case 3:
        feedbackType = FeedbackType.documentation;
        break;
      case 4:
        feedbackType = FeedbackType.question;
        break;
      case 5:
        feedbackType = FeedbackType.performance;
        break;
      case 6:
        feedbackType = FeedbackType.other;
        break;
      default:
        logger.error('Invalid feedback type.');
        return;
    }
    
    await _collectAndSubmitFeedback(feedbackType);
  }
  
  /// Parses feedback type string to FeedbackType enum
  FeedbackType? _parseFeedbackType(String type) {
    switch (type.toLowerCase()) {
      case 'bug':
        return FeedbackType.bug;
      case 'feature':
        return FeedbackType.feature;
      case 'docs':
      case 'documentation':
        return FeedbackType.documentation;
      case 'question':
        return FeedbackType.question;
      case 'performance':
      case 'perf':
        return FeedbackType.performance;
      case 'other':
        return FeedbackType.other;
      default:
        return null;
    }
  }
  
  Future<void> _collectAndSubmitFeedback(FeedbackType type) async {
    print('');
    logger.section('${type.emoji} ${type.title}');
    print('');
    
    // Collect title
    stdout.write('Title (brief summary): ');
    final title = stdin.readLineSync()?.trim() ?? '';
    
    if (title.isEmpty) {
      logger.error('Title cannot be empty.');
      return;
    }
    
    // Collect description
    print('');
    print('Description (press Enter twice when done):');
    final descriptionLines = <String>[];
    var emptyLineCount = 0;
    
    while (emptyLineCount < 2) {
      final line = stdin.readLineSync() ?? '';
      if (line.isEmpty) {
        emptyLineCount++;
      } else {
        emptyLineCount = 0;
      }
      descriptionLines.add(line);
    }
    
    // Remove trailing empty lines
    while (descriptionLines.isNotEmpty && descriptionLines.last.isEmpty) {
      descriptionLines.removeLast();
    }
    
    final description = descriptionLines.join('\n');
    
    if (description.isEmpty) {
      logger.error('Description cannot be empty.');
      return;
    }
    
    await _submitFeedback(
      feedbackType: type,
      title: title,
      description: description,
    );
  }
  
  /// Submits feedback by opening GitHub issue
  Future<void> _submitFeedback({
    required FeedbackType feedbackType,
    required String title,
    required String description,
  }) async {
    // Build GitHub issue URL
    final issueUrl = _buildGitHubIssueUrl(
      type: feedbackType,
      title: title,
      description: description,
    );
    
    print('');
    logger.info('Opening GitHub issue in your browser...');
    print('');
    print('If it doesn\'t open automatically, visit:');
    print('\x1B[36m$issueUrl\x1B[0m');
    print('');
    
    // Try to open in browser
    await _openInBrowser(issueUrl);
    
    logger.success('Thank you for your feedback! 🙏');
  }
  
  String _buildGitHubIssueUrl({
    required FeedbackType type,
    required String title,
    required String description,
  }) {
    final labels = type.labels.join(',');
    final issueTitle = Uri.encodeComponent('${type.emoji} $title');
    
    // Replace the first comment placeholder with user's description
    final filledTemplate = _fillTemplate(type.template, description);
    
    final issueBody = '''
$filledTemplate

---
**CLI Version:** v0.1.8
**OS:** ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
**Dart:** ${Platform.version}
''';
    
    final encodedBody = Uri.encodeComponent(issueBody);
    
    return 'https://github.com/$repoOwner/$repoName/issues/new?title=$issueTitle&body=$encodedBody&labels=$labels';
  }
  
  /// Fills the template by replacing the first comment placeholder with user input
  String _fillTemplate(String template, String userInput) {
    // Find the first comment placeholder (<!-- ... -->)
    final commentRegex = RegExp(r'<!--[^>]*-->');
    final match = commentRegex.firstMatch(template);
    
    if (match == null) {
      // No placeholder found, just append user input at the end
      return '${template.trim()}\n$userInput';
    }
    
    // Replace the first comment with user input
    return template.replaceFirst(commentRegex, userInput);
  }
  
  Future<void> _openInBrowser(String url) async {
    try {
      String command;
      List<String> args;
      
      if (Platform.isMacOS) {
        command = 'open';
        args = [url];
      } else if (Platform.isLinux) {
        command = 'xdg-open';
        args = [url];
      } else if (Platform.isWindows) {
        command = 'cmd';
        args = ['/c', 'start', url];
      } else {
        logger.warn('Unable to open browser automatically on this platform.');
        return;
      }
      
      await Process.run(command, args);
    } catch (e) {
      logger.warn('Failed to open browser automatically: $e');
    }
  }
}

enum FeedbackType {
  bug,
  feature,
  documentation,
  question,
  performance,
  other;
  
  String get emoji {
    switch (this) {
      case FeedbackType.bug:
        return '🐛';
      case FeedbackType.feature:
        return '✨';
      case FeedbackType.documentation:
        return '📖';
      case FeedbackType.question:
        return '❓';
      case FeedbackType.performance:
        return '⚡';
      case FeedbackType.other:
        return '💡';
    }
  }
  
  String get title {
    switch (this) {
      case FeedbackType.bug:
        return 'Bug Report';
      case FeedbackType.feature:
        return 'Feature Request';
      case FeedbackType.documentation:
        return 'Documentation';
      case FeedbackType.question:
        return 'Question';
      case FeedbackType.performance:
        return 'Performance Issue';
      case FeedbackType.other:
        return 'General Feedback';
    }
  }
  
  String get prefix {
    switch (this) {
      case FeedbackType.bug:
        return 'BUG';
      case FeedbackType.feature:
        return 'FEATURE';
      case FeedbackType.documentation:
        return 'DOCS';
      case FeedbackType.question:
        return 'QUESTION';
      case FeedbackType.performance:
        return 'PERF';
      case FeedbackType.other:
        return 'FEEDBACK';
    }
  }
  
  List<String> get labels {
    switch (this) {
      case FeedbackType.bug:
        return ['bug', 'cli'];
      case FeedbackType.feature:
        return ['enhancement', 'cli'];
      case FeedbackType.documentation:
        return ['documentation', 'cli'];
      case FeedbackType.question:
        return ['question', 'cli'];
      case FeedbackType.performance:
        return ['performance', 'cli'];
      case FeedbackType.other:
        return ['feedback', 'cli'];
    }
  }
  
  String get template {
    switch (this) {
      case FeedbackType.bug:
        return '''
## Expected Behavior
<!-- What should happen? -->

## Actual Behavior
<!-- What actually happens? -->

## Steps to Reproduce
1. 
2. 
3. 

## Additional Context
<!-- Screenshots, error messages, etc. -->
''';
      case FeedbackType.feature:
        return '''
## Problem Statement
<!-- What problem does this solve? -->

## Proposed Solution
<!-- How should it work? -->

## Alternatives Considered
<!-- What other approaches did you think about? -->

## Additional Context
<!-- Examples, mockups, references, etc. -->
''';
      case FeedbackType.documentation:
        return '''
## Documentation Issue
<!-- What's wrong or missing in the docs? -->

## Suggested Improvement
<!-- How should it be improved? -->

## Location
<!-- Which file or page? -->
''';
      case FeedbackType.question:
        return '''
## Question
<!-- What would you like to know? -->

## What I've Tried
<!-- What have you already attempted? -->

## Context
<!-- What are you trying to accomplish? -->
''';
      case FeedbackType.performance:
        return '''
## Performance Issue
<!-- What operation is slow? -->

## Impact
<!-- How does it affect your workflow? -->

## Environment
<!-- Project size, file count, etc. -->
''';
      case FeedbackType.other:
        return '''
## Feedback
<!-- Share your thoughts -->
''';
    }
  }
}
