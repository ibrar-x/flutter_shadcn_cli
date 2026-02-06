# Registry Resolution

The CLI resolves the registry in the following priority order:

1. `--registry-path` (explicit local path)
2. `.shadcn/config.json` values
3. Local kit registry (parent directories)
4. Pub cache global registry
5. Remote registry base URL

## Flow Diagram

```mermaid
flowchart TD
  A[Start] --> B{Registry mode?}
  B -->|local or auto| C[Check explicit path]
  C -->|found| D[Use local registry]
  C -->|not found| E[Search parent directories]
  E -->|found| D
  E -->|not found| F[Check pub cache]
  F -->|found| D
  F -->|not found| G[Use remote registry]
  B -->|remote| G
```

## Remote Registry Structure

The CLI assumes a base URL that contains `/registry/components.json` and `/registry/shared/...`.
