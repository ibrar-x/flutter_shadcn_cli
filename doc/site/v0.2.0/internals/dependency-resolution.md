# Dependency Resolution

The CLI resolves dependencies at multiple levels:

- Component dependsOn (component -> component)
- Shared dependencies (component -> shared)
- File dependsOn (file -> file)
- Pubspec dependencies (component -> packages)

## File Dependency Handling

File `dependsOn` entries are resolved across the full registry index, not just a single component. Shared file dependencies trigger shared installs.
