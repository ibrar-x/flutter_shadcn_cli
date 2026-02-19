> Legacy v0.1.9 reference documentation.
> For active development, use the v0.2.0 documentation set in this site.

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
