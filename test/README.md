# Flutter Shadcn CLI - Test Suite

This directory contains comprehensive tests for the flutter_shadcn_cli package.

## Test Files

### skill_manager_test.dart
Tests for AI skill installation and management functionality.

**Coverage:**
- **Skill Discovery** (5 tests)
  - Finding skills in local kit registry (`shadcn_flutter_kit/flutter_shadcn_kit/skills/`)
  - Finding skills in parent directory skills folder
  - Creating placeholder when skill not found
  - Requiring skill.json or skill.yaml manifest
  - Accepting skill.yaml as alternative to skill.json
  
- **File Copying** (3 tests)
  - Copying only AI-focused files (excludes manifest and schemas)
  - Maintaining directory structure during copy
  - Handling nested reference directories
  
- **Skill Management** (2 tests)
  - Listing installed skills by model
  - Uninstalling skills from specific models
  
- **Model Discovery** (2 tests)
  - Discovering AI model folders starting with dot
  - Auto-creating standard model folders when missing
  
- **Symlink Support** (1 test)
  - Creating symlinks from one model to another

**Total: 13 tests**

### version_manager_test.dart
Tests for CLI version management and automatic update checking.

**Coverage:**
- **Version Display** (2 tests)
  - Showing current version without errors
  - Validating semver format (e.g., 0.1.8)
  
- **Version Comparison** (2 tests)
  - Correctly identifying newer versions
  - Handling pre-release version tags
  
- **Cache Management** (3 tests)
  - Creating cache directory if missing
  - Saving cache data with timestamp
  - Respecting 24-hour cache staleness policy
  - Using fresh cache within 24 hours
  
- **Update Notification** (1 test)
  - Notification format includes version info
  
- **Opt-out Behavior** (1 test)
  - Respecting checkUpdates config flag
  
- **Error Handling** (2 tests)
  - Handling network errors gracefully
  - Handling malformed version responses

**Total: 11 tests**

### config_test.dart
Tests for configuration file management.

**Coverage:**
- Config roundtrip serialization/deserialization
- Path alias handling
- Boolean flag preservation

### installer_test.dart
Tests for component installation logic.

**Coverage:**
- Component file installation
- Shared file management
- Dependency resolution
- README/meta/preview file filtering

## Running Tests

### Run all tests
```bash
cd shadcn_flutter_cli
flutter test
```

### Run specific test file
```bash
flutter test test/skill_manager_test.dart
flutter test test/version_manager_test.dart
flutter test test/config_test.dart
flutter test test/installer_test.dart
```

### Run with verbose output
```bash
flutter test --reporter=expanded
```

### Run with coverage
```bash
flutter test --coverage
```

## Test Utilities

### Temporary Directories
All tests use `Directory.systemTemp.createTempSync()` to create isolated test environments that are cleaned up after each test.

### Teardown
Each test properly cleans up temporary files and directories using `tearDown()` callbacks.

### Fixtures
Tests create minimal fixtures as needed:
- Skill manifests (skill.json)
- Skill files (SKILL.md, INSTALLATION.md, etc.)
- Model folders (.claude, .cursor, etc.)
- Cache files (version_check.json)

## Test Patterns

### Skill Manager Tests
```dart
// Create skill in local kit registry
final skillDir = Directory(p.join(skillsRoot.path, 'flutter-shadcn-ui'))
  ..createSync(recursive: true);

_createSkillManifest(skillDir.path, {
  'id': 'flutter-shadcn-ui',
  'files': {'main': 'SKILL.md'}
});

// Install and verify
await skillManager.installSkill(skillId: 'flutter-shadcn-ui', model: '.claude');
expect(File(p.join(modelDir.path, 'skills', 'flutter-shadcn-ui', 'SKILL.md')).existsSync(), isTrue);
```

### Version Manager Tests
```dart
// Test version comparison
expect(_isNewerVersion('0.1.9', '0.1.8'), isTrue);
expect(_isNewerVersion('0.1.8', '0.1.8'), isFalse);

// Test cache staleness
final staleTimestamp = DateTime.now().subtract(Duration(hours: 25));
final age = DateTime.now().difference(lastCheck);
expect(age.inHours, greaterThan(24));
```

## CI/CD Integration

These tests are designed to run in CI/CD pipelines:
- No external dependencies (network calls are mocked/stubbed)
- Fast execution (all tests run in < 5 seconds)
- Deterministic results (no flaky tests)
- Clean teardown (no leftover temp files)

## Coverage Goals

Current coverage:
- **Skill Manager**: ~85% (core logic fully covered)
- **Version Manager**: ~80% (version comparison and cache logic covered)
- **Config**: ~90% (serialization fully covered)
- **Installer**: ~75% (component installation covered)

Target: 80% overall code coverage

## Future Test Additions

Planned tests:
- [ ] Integration tests for full CLI workflows
- [ ] Network mocking for pub.dev API calls
- [ ] Error scenario tests (permission denied, disk full, etc.)
- [ ] Performance tests for large skill installations
- [ ] Cross-platform tests (Windows, macOS, Linux)

## Troubleshooting

### Tests fail to create temp directories
Ensure write permissions in system temp directory:
```bash
chmod -R u+w $(dart pub cache dir)/../tmp
```

### Tests timeout
Increase timeout in test runner:
```bash
flutter test --timeout=2x
```

### Cleanup failures
Manually clean up test artifacts:
```bash
rm -rf /tmp/skill_manager_test_*
rm -rf /tmp/version_cache_test_*
```

## Contributing

When adding new features:
1. Write tests first (TDD approach)
2. Ensure tests are isolated and repeatable
3. Add tests to appropriate test file
4. Update this README with new test coverage
5. Run all tests before committing
6. Aim for 80%+ coverage on new code
