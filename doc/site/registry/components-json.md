# components.json

`components.json` is the canonical index of components and shared helpers.

## Root Structure

- `schemaVersion`
- `name`
- `flutter.minSdk`
- `defaults.installPath`
- `defaults.sharedPath`
- `shared` list
- `components` list

## Shared Entry

Each shared entry contains:

- `id`
- `description` (optional)
- `files` list (source + destination)

## Component Entry

Each component entry contains:

- `id`, `name`, `description`, `category`
- `files`
- `shared`
- `dependsOn`
- `pubspec.dependencies`
- `assets`, `fonts`, `platform`, `postInstall`
- `version`, `tags` (metadata)

## Example

```json
{
  "id": "button",
  "name": "Button",
  "description": "Primary button",
  "category": "control",
  "files": [{"source": "registry/components/button/button.dart", "destination": "{installPath}/components/button/button.dart"}],
  "shared": ["theme"],
  "dependsOn": [],
  "pubspec": {"dependencies": {"gap": "^3.0.1"}},
  "assets": [],
  "postInstall": [],
  "version": "1.0.0",
  "tags": ["core"]
}
```
