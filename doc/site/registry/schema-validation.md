# Schema Validation

The CLI validates `components.json` using JSON Schema.

## Schema Source Resolution

Order of precedence:

1. `$schema` in `components.json` (relative to registry root if not absolute)
2. `components.schema.json` in the registry root

## Behavior

- Validation errors are reported in `doctor`
- Validation warnings are logged during registry load

## Example

```bash
flutter_shadcn doctor
```
