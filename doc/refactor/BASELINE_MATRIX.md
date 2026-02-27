# Refactor Baseline Matrix

Date: 2026-02-22

This file freezes expected CLI behavior before and during architecture refactor.

## Baseline command coverage
- Source of truth test: `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/command_matrix_test.dart`
- Command help coverage: all documented commands must resolve with `--help`
- Namespace selector coverage: `@namespace` across list/search/theme/sync/validate/audit/deps/remove/feedback

## Non-regression gates
1. Legacy config/state migration
- Old `.shadcn/config.json` and `.shadcn/state.json` auto-migrate to registries map
- `managedDependencies` semantics preserved
- Gate tests:
  - `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/config_state_migration_test.dart`
  - `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/command_matrix_test.dart`

2. Single-registry flow
- Existing local/remote single registry commands keep behavior
- Gate tests:
  - `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/installer_test.dart`
  - `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/cli_integration_test.dart`

3. Multi-registry flow
- Default namespace selection
- Qualified refs `@namespace/component` and `namespace:component`
- Ambiguity failure on unqualified add
- Gate tests:
  - `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/multi_registry_manager_test.dart`
  - `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/cli_integration_test.dart`

4. Inline init actions
- `init <namespace>` executes `registries.json` inline actions
- Filesystem safety and resolver restrictions enforced
- Gate tests:
  - `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/init_action_engine_test.dart`
  - `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/resolver_v1_test.dart`
  - `/Users/ibrar/Desktop/infinora.noworkspace/shadcn_copy_paste/shadcn_flutter_cli/test/e2e_multi_registry_fixture_test.dart`

## Refactor checkpoint rule
After each extraction step:
1. `dart analyze`
2. command matrix + integration + migration + inline init tests
3. no behavior changes unless explicitly documented
