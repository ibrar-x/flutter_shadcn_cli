# Troubleshooting

## Common Issues

- Flag not found: remove cached snapshots and re-activate
- Registry not found: set `--registry-path` or `--registry-url`
- Offline cache missing: run without `--offline` once to populate cache
- Schema validation failures: run `doctor` and ensure schema exists
- Theme file not found: run `init` first

## Snapshot Reset

```bash
rm -f ~/.pub-cache/hosted/*/bin/cache/flutter_shadcn_cli/* || true
rm -f .dart_tool/pub/bin/flutter_shadcn_cli/*.snapshot || true
```
