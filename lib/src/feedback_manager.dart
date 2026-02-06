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
      case 'doc':
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
  
  /// Submits feedback by creating GitHub issue via gh CLI or browser
  Future<void> _submitFeedback({
    required FeedbackType feedbackType,
    required String title,
    required String description,
  }) async {
    print('');
    
    // Try gh CLI first (direct issue creation without browser)
    final ghAvailable = await _isGitHubCliAvailable();
    if (ghAvailable) {
      final success = await _createIssueViaGh(
        type: feedbackType,
        title: title,
        description: description,
      );
      
      if (success) {
        logger.success('Thank you for your feedback! 🙏');
        return;
      }
      
      // If gh fails, fall through to browser method
      logger.warn('GitHub CLI failed, falling back to browser...');
      print('');
    }
    
    // Fallback: Build GitHub issue URL and open in browser
    final issueUrl = _buildGitHubIssueUrl(
      type: feedbackType,
      title: title,
      description: description,
    );
    
    logger.info('Opening GitHub issue in your browser...');
    print('');
    print('If it doesn\'t open automatically, visit:');
    print('\x1B[36m$issueUrl\x1B[0m');
    print('');
    
    // Try to open in browser
    await _openInBrowser(issueUrl);
    
    logger.success('Thank you for your feedback! 🙏');
  }
  
  /// Checks if GitHub CLI (gh) is installed and authenticated
  Future<bool> _isGitHubCliAvailable() async {
    try {
      final result = await Process.run('gh', ['--version']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
  
  /// Creates a GitHub issue using gh CLI
  Future<bool> _createIssueViaGh({
    required FeedbackType type,
    required String title,
    required String description,
  }) async {
    try {
      logger.info('Creating issue via GitHub CLI...');
      
      // Build issue body with template
      final filledTemplate = _fillTemplate(type.template, description);
      final issueBody = '''
$filledTemplate

---
**CLI Version:** v0.1.8
**OS:** ${Platform.operatingSystem} ${Platform.operatingSystemVersion}
**Dart:** ${Platform.version}
''';
      
      // Create issue using gh CLI
      final labels = type.labels.join(',');
      final issueTitle = '${type.emoji} $title';
      
      final result = await Process.run('gh', [
        'issue',
        'create',
        '--repo',
        '$repoOwner/$repoName',
        '--title',
        issueTitle,
        '--body',
        issueBody,
        '--label',
        labels,
      ]);
      
      if (result.exitCode == 0) {
        print('');
        logger.success('Issue created successfully! ✨');
        
        // Extract and display issue URL from output
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          print('');
          print('\x1B[36m$output\x1B[0m');
        }
        
        return true;
      } else {
        // Check for authentication errors
        final stderr = result.stderr.toString();
        if (stderr.contains('not logged') || stderr.contains('authentication')) {
          logger.warn('GitHub CLI not authenticated. Run: gh auth login');
        }
        return false;
      }
    } catch (e) {
      return false;
    }
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
## Bug Description
<!-- Describe what's wrong -->

## Steps to Reproduce
<!-- Provide detailed steps to reproduce the issue -->
1. Run command: `flutter_shadcn ...`
2. 
3. 

## Expected Behavior
<!-- What should happen? -->

## Actual Behavior
<!-- What actually happens? Include error messages if any -->

## Environment Details
<!-- Additional context that might be relevant -->
- **Component/Feature**: <!-- e.g., init, add, theme, install-skill -->
- **Project Type**: <!-- e.g., new project, existing project -->
- **Error Messages**: 
```
<!-- Paste error output here if applicable -->
```

## Screenshots/Logs
<!-- Add screenshots or relevant log files if helpful -->
''';
      case FeedbackType.feature:
        return '''
## Problem Statement
<!-- What problem are you trying to solve? Why is this needed? -->

## Proposed Solution
<!-- How should this feature work? Describe the ideal behavior -->

## Use Cases
<!-- Provide specific examples of when/how this would be used -->
1. 
2. 

## Proposed API/Commands
<!-- If applicable, show example commands or usage -->
```bash
# Example usage
flutter_shadcn ...
```

## Alternatives Considered
<!-- What other approaches did you consider? Why is this approach better? -->

## Additional Context
<!-- Mockups, diagrams, references to similar features in other tools, etc. -->
''';
      case FeedbackType.documentation:
        return '''
## Documentation Issue
<!-- What's unclear, missing, incorrect, or confusing in the docs? -->

## Location
<!-- Where is the issue? -->
- **File/Page**: <!-- e.g., README.md, specific command docs -->
- **Section**: <!-- e.g., "Installation", "Commands", specific heading -->
- **URL**: <!-- If applicable -->

## Current State
<!-- What does the documentation currently say (or not say)? -->

## Suggested Improvement
<!-- How should it be improved? What would make it clearer? -->

## Why This Matters
<!-- Who would benefit from this improvement? What confusion does it prevent? -->

## Example/Code Snippet
<!-- If applicable, show example of clearer documentation or code sample that should be documented -->
```bash
# Example of what should be documented
```
''';
      case FeedbackType.question:
        return '''
## Question
<!-- What would you like to know? Be as specific as possible -->

## Context
<!-- What are you trying to accomplish? Describe your goal -->

## What I've Tried
<!-- What approaches have you already attempted? -->
1. 
2. 

## Related Commands/Features
<!-- Which CLI commands or features are you working with? -->

## Expected Outcome
<!-- What result are you hoping to achieve? -->

## Code/Configuration
<!-- Share relevant commands, config files, or code snippets -->
```bash
# Commands you've run
```

```json
// Config files if relevant
```
''';
      case FeedbackType.performance:
        return '''
## Performance Issue
<!-- What operation is slow or consuming excessive resources? -->

## Impact
<!-- How does this affect your workflow? -->
- **Operation Time**: <!-- e.g., "takes 30 seconds, expected 5 seconds" -->
- **Frequency**: <!-- e.g., "happens every time", "intermittent" -->
- **Severity**: <!-- e.g., "blocks development", "minor annoyance" -->

## Steps to Reproduce
<!-- How can we reproduce the performance issue? -->
1. 
2. 
3. 

## Environment Details
<!-- Details that might affect performance -->
- **Project Size**: <!-- e.g., "500+ components", "small test project" -->
- **Number of Components**: 
- **Registry Type**: <!-- local or remote -->
- **Internet Speed**: <!-- if using remote registry -->
- **System Resources**: <!-- RAM, CPU if relevant -->

## Measurements
<!-- If you have timing data, profiling results, or logs -->
```
<!-- Paste relevant performance data here -->
```

## Expected Performance
<!-- What would be acceptable performance? -->
''';
      case FeedbackType.other:
        return '''
## Feedback
<!-- Share your thoughts, suggestions, or general comments -->

## Category
<!-- What aspect of the CLI does this relate to? -->
- [ ] User Experience
- [ ] Developer Experience
- [ ] Design/Aesthetics
- [ ] Workflow/Process
- [ ] Integration with other tools
- [ ] Other: ___________

## Details
<!-- Provide as much context as you'd like -->

## Suggestions
<!-- If you have ideas for improvement, share them here -->
''';
    }
  }
}
