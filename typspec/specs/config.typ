#set document(title: "Typspec Config Schema", author: "Gerson Gallo")

= Typspec Config Schema Specification

This document specifies the schema and semantics of `typspec.jsonc`.

== Discovery

The CLI SHALL discover `typspec.jsonc` by checking these paths in order, walking up from the current directory:

1. `<dir>/typspec.jsonc`
2. `<dir>/.typspec.jsonc`
3. `<dir>/typspec/config.jsonc`
4. `<dir>/.config/typspec.jsonc`

Config files from parent directories SHALL be merged with child overrides. A global user config at `~/.config/typspec/config.jsonc` SHALL serve as the base (lowest priority).

==== Scenario: discovery walks up

- GIVEN current directory is `~/repo/packages/logger/src`
- AND `~/repo/typspec.jsonc` exists
- WHEN the CLI runs
- THEN `~/repo/typspec.jsonc` is used as the project config

==== Scenario: child overrides parent

- GIVEN `~/repo/typspec.jsonc` has `project.name: "repo"`
- AND `~/repo/packages/logger/typspec.jsonc` has `project.name: "logger"`
- WHEN the CLI runs in `~/repo/packages/logger`
- THEN `project.name` is `"logger"`

==== Scenario: no config found

- GIVEN no `typspec.jsonc` exists in any parent of the current directory
- WHEN a project command runs
- THEN the CLI errors suggesting `typspec init`

== Schema: project

The `project` section SHALL define the identity of the current package.

```
{
  "project": {
    "name": "std/http",
    "version": "0.1.0"
  }
}
```

=== Fields

- `name` (string, required) — a dotted identifier for this package. Used by consumers in their `workspaces` entries to reference this package's specs.
- `version` (string, optional) — the package version. Recommended for published packages.

==== Scenario: project name is required

- WHEN `typspec.jsonc` is parsed
- AND `project.name` is missing
- THEN validation fails with a clear error

== Schema: workspaces

The `workspaces` section SHALL declare the specs that this package references. Each key is a stable workspace ID.

```
{
  "workspaces": {
    "std/logger": {
      "path": "../logger/typspec"
    },
    "std/core": {
      "git": "https://github.com/org/std-core.git",
      "tag": "v1.2.0",
      "subpath": "typspec"
    },
    "std/core": {
      "git": "https://github.com/org/std-core.git",
      "commit": "abc123def456",
      "subpath": "typspec"
    },
    "std/auth": {
      "registry": "typspec-registry.example.com",
      "package": "@corp/auth-specs",
      "version": "^2.1.0"
    }
  }
}
```

=== Location Types

Each workspace entry SHALL have exactly one location type:

- **`path`**: A relative filesystem path from the config file's directory.
- **`git`**: Requires a `tag` or `commit` field, and an optional `subpath`. The repository is cloned at the specified ref, and the `subpath` points to the typspec root within it.
- **`registry`**: Requires `package` and `version` (semver range). Future — fetches from a registry.

==== Scenario: path workspace

- GIVEN a workspace entry with `"path": "../logger/typspec"`
- WHEN the CLI resolves `modifies: "std/logger"` in a change
- THEN it reads specs from `../logger/typspec/specs/`

==== Scenario: git workspace with tag

- GIVEN a workspace entry with `"git": "..."` and `"tag": "v1.2.0"`
- WHEN `typspec install` is run
- THEN the repo is cloned at tag `v1.2.0`

==== Scenario: git workspace with commit

- GIVEN a workspace entry with `"git": "..."` and `"commit": "abc123def456"`
- WHEN `typspec install` is run
- THEN the repo is cloned at that specific commit

==== Scenario: registry workspace

- GIVEN a workspace entry with `"registry": "..."`, `"package": "@corp/auth-specs"`, `"version": "^2.1.0"`
- WHEN `typspec install` is run
- THEN the package is resolved from the registry using semver

== Schema: exports

The `exports` section SHALL declare which spec files are publicly available for reference by other packages.

```
{
  "exports": {
    ".": "specs/api.typ",
    "./types": "specs/types.typ"
  }
}
```

Unlisted spec files in the `specs/` directory SHALL be considered internal and not referenceable by external packages.

==== Scenario: exported spec is referenceable

- GIVEN `exports["."]` points to `"specs/api.typ"`
- WHEN another package's change lists `modifies: "my-package"`
- THEN the CLI allows referencing the exported spec

==== Scenario: unlisted spec is internal

- GIVEN `specs/internal.typ` exists
- AND it is not listed in `exports`
- WHEN another package's change tries to reference it
- THEN the CLI rejects the reference

== Schema: bibliographies

The `bibliographies` section SHALL list default bibliography files.

```
{
  "bibliographies": [
    "refs.yaml",
    "vendor-refs.yaml"
  ]
}
```

All listed files SHALL be available for citation in spec and change documents.

== Schema: context

The `context` section SHALL provide structured project context for AI agents.

```
{
  "context": {
    "tech_stack": "Go 1.24, Lua 5.4",
    "conventions": "Conventional commits, test-first",
    "domain": "Lua standard library"
  }
}
```

This replaces OpenSpec's freeform `context` string with structured fields. Skills and the CLI SHALL make this context available to AI agents.

==== Scenario: context is read by skills

- GIVEN `typspec.jsonc` has `context.tech_stack`
- WHEN an AI skill proposes a change
- THEN the context is included in the skill's instructions

== Schema: typspec version

The top-level `typspec` field SHALL declare the minimum supported CLI version for this config.

```
{
  "typspec": "0.1.0"
}
```

If the CLI version is less than the declared version, the CLI SHALL error with an upgrade suggestion.
