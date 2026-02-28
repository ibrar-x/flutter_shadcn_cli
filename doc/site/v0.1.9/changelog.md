> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

# Changelog Summary

This page summarizes the release notes. For full details, see `CHANGELOG.md` in the repository root.

## Latest (0.2.0)

- Multi-registry architecture with registry namespace isolation
- `registries.json` directory support with JSON Schema validation and cache/ETag
- Inline namespace bootstrap via `flutter_shadcn init <namespace>` (no `meta.json` bootstrap requirement)
- Namespace component addressing with `@namespace/component` and legacy `namespace:component`
- Default namespace management with `flutter_shadcn default <namespace>`
- Registry listing with `flutter_shadcn registries` / `--json`
- Backward-compatible migration for legacy `.shadcn/config.json` and `.shadcn/state.json`
- Resolver and filesystem traversal hardening for remote fetch/write safety

## 0.1.9

- Pretty-printed JSON output for discovery, doctor, dry-run, validate, audit, and deps
- Standardized JSON envelope and exit codes
- New commands: validate, audit, deps, docs
- Offline mode for cache-only usage
- Command aliases: `ls`, `rm`, `i`
