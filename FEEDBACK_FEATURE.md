# Feedback Feature

The `flutter_shadcn feedback` command provides a structured way for users to submit feedback and report issues.

## Features

✅ **6 Feedback Categories** with custom templates:
- 🐛 **Bug Report** - For crashes, errors, or unexpected behavior
- ✨ **Feature Request** - For new component or enhancement ideas
- 📖 **Documentation** - For docs improvements or clarifications
- ❓ **Question** - For usage questions or help requests
- ⚡ **Performance** - For slow builds or runtime performance issues
- 💡 **Other** - For general feedback and suggestions

✅ **Auto-filled Context**:
- CLI version (e.g., `0.1.8`)
- Operating system (e.g., `macOS 14.2.1`)
- Dart SDK version (e.g., `3.3.0`)

✅ **Smart GitHub Integration**:
- Opens pre-filled GitHub issue in default browser
- Applies appropriate labels automatically
- Uses structured templates for each feedback type
- URL-encoded for proper formatting

✅ **Cross-Platform Support**:
- macOS: Uses `open` command
- Linux: Uses `xdg-open` command
- Windows: Uses `cmd /c start` command

## Usage

```bash
# Interactive feedback menu
flutter_shadcn feedback

# Show help
flutter_shadcn feedback --help
```

## Example Workflow

1. **Run command**:
   ```bash
   flutter_shadcn feedback
   ```

2. **Select feedback type**:
   ```
   ╭─────────────────────────────────────────────────╮
   │           Submit Feedback or Report Issues      │
   ╰─────────────────────────────────────────────────╯
   
   Select feedback type:
   
   🐛 1. Report a bug
   ✨ 2. Request a feature
   📖 3. Documentation improvement
   ❓ 4. Ask a question
   ⚡ 5. Performance issue
   💡 6. Other feedback
   
   0. Cancel
   
   Enter your choice (0-6):
   ```

3. **Enter title**:
   ```
   Enter a brief title for your bug report:
   > Button component crashes on null theme
   ```

4. **Enter description**:
   ```
   Enter a detailed description (press Enter twice when done):
   > When initializing button without theme context,
   > the app crashes with null pointer exception...
   >
   ```

5. **GitHub issue opens** in browser with:
   - Title: "🐛 Button component crashes on null theme"
   - Pre-filled template with your description
   - Environment section with CLI version, OS, and Dart SDK
   - Labels: `bug`, `needs-triage`

## Templates

### Bug Report Template
```
## Bug Description
[User's description]

## Steps to Reproduce
1. 
2. 
3. 

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]

## Environment
**CLI Version**: 0.1.8
**OS**: macOS 14.2.1
**Dart SDK**: 3.3.0
```

### Feature Request Template
```
## Problem Statement
[User's description]

## Proposed Solution
[How you'd like it to work]

## Alternatives Considered
[Other solutions you've thought about]

## Environment
**CLI Version**: 0.1.8
**OS**: macOS 14.2.1
**Dart SDK**: 3.3.0
```

### Documentation Template
```
## Documentation Issue
[User's description]

## Location
**Page/Section**: [Where in the docs]
**URL**: [Link if applicable]

## Suggested Improvement
[What should be changed or added]

## Example
[Code snippet or example if helpful]

## Environment
**CLI Version**: 0.1.8
```

### Question Template
```
## Question
[User's description]

## Context
[What you're trying to accomplish]

## What I've Tried
[Steps or solutions you've attempted]

## Expected Outcome
[What you expect to happen]

## Environment
**CLI Version**: 0.1.8
```

### Performance Issue Template
```
## Performance Issue
[User's description]

## Impact
[How it affects your workflow]

## Environment
**CLI Version**: 0.1.8
**OS**: macOS 14.2.1
**Dart SDK**: 3.3.0
**Flutter Version**: 

## Steps to Reproduce
1. 
2. 
3. 
```

### Other Feedback Template
```
## Feedback
[User's description]

## Additional Context
[Any other relevant information]

## Environment
**CLI Version**: 0.1.8
```

## Benefits

1. **Structured**: Templates ensure all necessary information is collected
2. **Time-saving**: Auto-fills environment details users might forget
3. **Better triage**: Labels help maintainers prioritize and route issues
4. **Lower barrier**: Simple interactive flow encourages user feedback
5. **Context-rich**: Version and platform info aids debugging

## Implementation

- **File**: `lib/src/feedback_manager.dart`
- **Class**: `FeedbackManager`
- **Dependencies**: `CliLogger`, `Platform`, `Process`
- **Integration**: Wired into `bin/shadcn.dart` main switch statement

## Documentation

- ✅ README.md - Usage section added
- ✅ CHANGELOG.md - v0.1.8 section updated
- ✅ FULL_COMMANDS_DOCS.md - Complete command documentation
- ✅ Help text - Integrated into CLI help output
