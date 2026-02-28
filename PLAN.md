# Clean Architecture Refactor Plan

## Execution order
1. Stabilize baseline + regression gates
2. Define architecture boundaries
3. Split CLI entrypoint
4. Extract command routing and command-wise handlers
5. Decompose installer + multi-registry internals
6. Introduce interfaces + dependency injection
7. Remove dead code and finalize docs

## Non-regression gates
- Legacy config/state migration
- Single-registry behavior
- Multi-registry behavior
- Inline init action execution

## Mandatory checks per step
- dart analyze
- command matrix test
- cli integration smoke for changed commands
