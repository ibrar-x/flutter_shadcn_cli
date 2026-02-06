# Manifests and State

## Install Manifest

`<installPath>/components.json` tracks:

- installed component ids
- component metadata (version, tags)
- managed dependencies
- install and shared paths

## Per-Component Manifests

`.shadcn/components/<id>.json` tracks:

- component id and name
- version and tags
- install time
- files, shared, dependsOn
- registry root

## State File

`.shadcn/state.json` tracks:

- install path
- shared path
- theme id
- managed dependency set
