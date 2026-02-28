> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

# install-skill Deep Dive

## Workflow

1. Discover model folders in project root
2. Resolve skill source path
3. Read skill.json or skill.yaml
4. Copy allowed files
5. Optional symlink to other models

## Flow Diagram

```mermaid
flowchart TD
  A[Start] --> B[Discover model folders]
  B --> C[Resolve skill path]
  C --> D[Read manifest]
  D --> E[Copy files]
  E --> F{Symlink?}
  F -->|yes| G[Create symlinks]
  F -->|no| H[Done]
```

## Example

```bash
flutter_shadcn install-skill --skill flutter-shadcn-ui --model .claude
```
