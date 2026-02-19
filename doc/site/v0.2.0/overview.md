# Overview (v0.2.0)

`v0.2.0` is the active multi-registry system.

## Core Behavior

- Registry directory (`registries.json`) drives namespace discovery and inline init.
- `add` supports explicit namespace installs via `@namespace/component`.
- Unqualified `add component` resolves through enabled registries; ambiguity fails with qualification requirement.
- Config/state include migration support from legacy format.

## Key Compatibility Guarantees

- Legacy config/state auto-migrates.
- Existing dependency/state semantics are preserved.
- Single-registry workflows continue to operate.
