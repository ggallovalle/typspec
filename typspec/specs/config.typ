#import "../src/lib.typ": spec, requirement, scenario, decision

#show: spec.with(title: "Typspec Config Schema")

= Typspec Config Schema Specification

This document specifies the schema and semantics of typspec config files.

== Config File Formats

#requirement("config-formats", priority: "shall")[
  Config files SHALL be valid JSON or JSONC (JSON with Comments).

  Both `.json` and `.jsonc` extensions SHALL be accepted. `.jsonc` files support `//` and `/* */` comments and trailing commas. `.json` files are parsed strictly. Both formats use the same schema.

  #scenario("jsonc with comments",
    when: [file contains `//` line comments],
    then: [comments stripped, remaining JSON validated against schema],
  )

  #scenario("json without comments",
    when: [file has `.json` extension],
    then: [parsed as strict JSON],
  )
]

== Discovery

#requirement("config-discovery", priority: "shall")[
  The CLI SHALL discover config files by walking up from the current working directory to the filesystem root. At each directory, paths are checked in order.

  ```
  # Project-local configs
  <dir>/typspec.json(c)
  <dir>/typspec/config.json(c)
  <dir>/.config/typspec.json(c)
  <dir>/.config/typspec/typspec.json(c)

  # Local overrides (git-ignored)
  <dir>/typspec.local.json(c)
  <dir>/typspec/config.local.json(c)
  <dir>/.config/typspec.local.json(c)
  <dir>/.config/typspec/typspec.local.json(c)

  # Environment-specific (when TYPSPEC_ENV is set)
  <dir>/typspec.<env>.json(c)

  # User global (lowest precedence)
  ~/.config/typspec/config.json(c)
  ```

  Configs found in child directories override those in parent directories. The global user config serves as the lowest-precedence base.

  #scenario("discovery walks up",
    given: [current dir is `~/repo/packages/logger/src`, `~/repo/typspec.jsonc` exists],
    when: [CLI runs],
    then: [`~/repo/typspec.jsonc` used as project config],
  )

  #scenario("child overrides parent",
    given: [`~/repo/typspec.jsonc` has `name: "repo"`, `~/repo/packages/logger/typspec/config.jsonc` has `name: "logger"`],
    when: [CLI runs in `~/repo/packages/logger`],
    then: [`project.name` is `"logger"`],
  )

  #scenario("no config found",
    given: [no typspec config exists in any parent],
    when: [project command runs],
    then: [CLI errors suggesting `typspec init`],
  )

  #scenario("TYPSPEC_CONFIG override",
    given: [`$TYPSPEC_CONFIG` set to `/custom/path/typspec.json`],
    when: [CLI runs],
    then: [only that path loaded, no directory walk],
  )
]

== Schema: project

#requirement("schema-project", priority: "shall")[
  The `project` section SHALL define the identity of the current package.

  ```
  { "project": { "name": "std/http", "version": "0.1.0" } }
  ```

  - `name` (string, required) — dotted identifier for this package.
  - `version` (string, optional) — package version.

  #scenario("project name is required",
    when: [`project.name` is missing],
    then: [validation fails with clear error],
  )
]

== Schema: workspaces

#requirement("schema-workspaces", priority: "shall")[
  The `workspaces` section SHALL declare the specs that this package references. Each key is a stable workspace ID.

  Each entry SHALL have exactly one location type:
  - `path` — relative filesystem path.
  - `git` — requires `tag` or `commit` field, optional `subpath`.
  - `registry` — requires `package` and `version` (semver range, future).

  #scenario("path workspace",
    given: [`"std/logger": { "path": "../logger/typspec" }`],
    when: [CLI resolves `modifies: "std/logger"`],
    then: [specs read from `../logger/typspec/specs/`],
  )

  #scenario("git workspace with tag",
    given: [`"git": "..."`, `"tag": "v1.2.0"`],
    when: [`typspec install`],
    then: [repo cloned at tag `v1.2.0`],
  )

  #scenario("git workspace with commit",
    given: [`"commit": "abc123"`],
    when: [`typspec install`],
    then: [repo cloned at specific commit],
  )
]

== Schema: exports

#requirement("schema-exports", priority: "should")[
  The `exports` section SHALL declare which spec files are publicly available.

  Unlisted spec files are considered internal and not referenceable by external packages.

  #scenario("exported spec is referenceable",
    given: [`exports["."]` points to `"specs/api.typ"`],
    when: [another package lists `modifies: "my-package"`],
    then: [CLI allows referencing the exported spec],
  )

  #scenario("unlisted spec is internal",
    given: [`specs/internal.typ` exists but not in `exports`],
    when: [another package tries to reference it],
    then: [CLI rejects the reference],
  )
]

== Schema: bibliographies

#requirement("schema-bibliographies", priority: "may")[
  The `bibliographies` section SHALL list default Hayagriva bibliography files.

  All listed files are available for citation in spec and change documents.
]

== Schema: context

#requirement("schema-context", priority: "should")[
  The `context` section SHALL provide structured project context for AI agents.

  ```
  { "context": { "tech_stack": "Go 1.24", "conventions": "Conventional commits" } }
  ```

  Replaces freeform context strings with structured fields. Skills and the CLI make this context available.

  #scenario("context read by skills",
    given: [config has `context.tech_stack`],
    when: [AI skill proposes a change],
    then: [context included in skill instructions],
  )
]

== Schema: typspec version

#requirement("schema-typspec-version", priority: "shall")[
  The top-level `typspec` field SHALL declare the minimum supported CLI version.

  If the CLI version is less than the declared version, the CLI SHALL error with an upgrade suggestion.
]
#requirement("test-body-extract", priority: "shall")[
something else
]
