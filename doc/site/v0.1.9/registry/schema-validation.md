> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

# Schema Validation

The CLI validates `components.json` using JSON Schema.

## Schema Source Resolution

Order of precedence:

1. `$schema` in `components.json` (relative to registry root if not absolute)
2. `components.schema.json` in the registry root

## Behavior

- Validation errors are reported in `doctor`
- Full validation is available via `validate`
- Validation warnings are logged during registry load

## Example

```bash
flutter_shadcn doctor
flutter_shadcn validate
```
