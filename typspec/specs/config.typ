#set document(title: "Typspec Config Schema", author: "Gerson Gallo")

= Typspec Config Schema Specification

This document specifies the schema and semantics of typspec config files.

== Config File Formats

Config files SHALL be valid JSON or JSONC (JSON with Comments). The CLI SHALL:

- Accept both `.json` and `.jsonc` extensions interchangeably.
- Parse `.jsonc` files with comment support (both `//` and `/* */`).
- Parse `.json` files strictly according to the JSON specification.
- Strip comments and trailing commas from `.jsonc` files before validation.

Both formats SHALL use the same schema and validation rules. The filename pattern
`typspec.jsonc` in this document refers equally to `typspec.json`, `typspec.jsonc`,
and any other valid config filename variant.

==== Scenario: jsonc with comments

- GIVEN a `typspec.jsonc` file containing `//` line comments
- WHEN the CLI parses the file
- THEN the comments are stripped
- AND the remaining JSON is validated against the schema

==== Scenario: json without comments

- GIVEN a `typspec.json` file with no comments
- WHEN the CLI parses the file
- THEN it is parsed as strict JSON

==== Scenario: jsonc with trailing comma

- GIVEN a `typspec.jsonc` file with a trailing comma in an array
- WHEN the CLI parses the file
- THEN the trailing comma is stripped without error

== Discovery

=== File Paths

The CLI SHALL discover config files by walking up from the current working
directory to the filesystem root. At each directory, the following paths are
checked in order (first found in a directory wins):

```
# Project-local configs (walk up from cwd)
<dir>/typspec.jsonc
<dir>/typspec.json
<dir>/typspec/config.jsonc
<dir>/typspec/config.json
<dir>/.config/typspec.jsonc
<dir>/.config/typspec.json
<dir>/.config/typspec/typspec.jsonc
<dir>/.config/typspec/typspec.json

# Local overrides (git-ignored)
<dir>/typspec.local.jsonc
<dir>/typspec.local.json
<dir>/typspec/config.local.jsonc
<dir>/typspec/config.local.json
<dir>/.config/typspec.local.jsonc
<dir>/.config/typspec.local.json
<dir>/.config/typspec/typspec.local.jsonc
<dir>/.config/typspec/typspec.local.json

# Environment-specific (when TYPSPEC_ENV is set)
<dir>/typspec.<env>.jsonc
<dir>/typspec.<env>.json
```

=== Global and System Config

Beyond project-local configs, the CLI SHALL also load a user global config:

```
# User global (lowest precedence)
~/.config/typspec/config.jsonc
~/.config/typspec/config.json
```

The `$TYPSPEC_CONFIG` environment variable SHALL override the config discovery
path entirely. When set, only the specified path is loaded.

=== Merge Semantics

Configs found in child directories override those in parent directories.
The global user config serves as the lowest-precedence base.
Local override files (`*.local.*`) override their non-local counterparts.
Environment-specific configs (`typspec.<env>.*`) override base configs
when `TYPSPEC_ENV` is set.

==== Scenario: discovery walks up

- GIVEN current directory is `~/repo/packages/logger/src`
- AND `~/repo/typspec.jsonc` exists
- WHEN the CLI runs
- THEN `~/repo/typspec.jsonc` is used as the project config

==== Scenario: child overrides parent

- GIVEN `~/repo/typspec.jsonc` has `"project": { "name": "repo" }`
- AND `~/repo/packages/logger/typspec/config.jsonc` has `"project": { "name": "logger" }`
- WHEN the CLI runs in `~/repo/packages/logger`
- THEN `project.name` is `"logger"`

==== Scenario: local override

- GIVEN `typspec.jsonc` has `"workspaces": { "std/core": { "path": "../core/typspec" } }`
- AND `typspec.local.jsonc` has `"workspaces": { "std/core": { "path": "/home/me/dev/core/typspec" } }`
- WHEN both are in the same directory
- THEN the local override takes precedence for `std/core`

==== Scenario: environment-specific config

- GIVEN `TYPSPEC_ENV=ci` is set
- AND `typspec.ci.jsonc` exists in the project root
- WHEN the CLI loads configs
- THEN `typspec.ci.jsonc` is loaded and merged after `typspec.jsonc`

==== Scenario: no config found

- GIVEN no typspec config exists in any parent of the current directory
- AND `~/.config/typspec/config.jsonc` does not exist
- WHEN a project command runs
- THEN the CLI errors suggesting `typspec init`

==== Scenario: TYPSPEC_CONFIG override

- GIVEN `$TYPSPEC_CONFIG` is set to `/custom/path/typspec.json`
- WHEN the CLI runs
- THEN only `/custom/path/typspec.json` is loaded
- AND no directory walk occurs

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

- `path`: A relative filesystem path from the config file's directory.
- `git`: Requires a `tag` or `commit` field, and an optional `subpath`. The repository is cloned at the specified ref, and the `subpath` points to the typspec root within it.
- `registry`: Requires `package` and `version` (semver range). Future — fetches from a registry.

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
