# Contributor Rules (Refactor Guardrails)

1. Do not add new monolithic command logic to `bin/shadcn.dart`.
2. Keep `bin/shadcn.dart` as a thin handoff to `presentation/cli/bootstrap.dart`.
3. Add/modify command behavior in `lib/src/presentation/cli/commands/*`.
4. Keep bootstrap decision logic in `bootstrap_support.dart`, not inline in `bootstrap.dart`.
5. Keep installer and multi-registry logic in their focused split modules.
6. Keep path traversal and resolver checks centralized.
7. Every behavior change requires integration test coverage.
8. Run `dart analyze` and command matrix + CLI integration tests before merging.
