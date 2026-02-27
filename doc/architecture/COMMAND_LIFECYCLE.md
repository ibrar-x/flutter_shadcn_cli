# Command Lifecycle

1. Parse arguments in `lib/src/presentation/cli/cli_parser.dart`
2. Bootstrap resolves runtime roots + routing strategy in:
- `lib/src/presentation/cli/bootstrap.dart`
- `lib/src/presentation/cli/bootstrap_support.dart`
3. Dispatch to command module in `lib/src/presentation/cli/commands/*.dart`
4. Command orchestrates installer/multi-registry/application service
5. Persist config/state/manifests through existing persistence paths
6. Return exit code via dispatcher

## Standard result model
- Commands should return a uniform result shape:
  - `exitCode`
  - `errors[]`
  - `warnings[]`
  - optional payload
