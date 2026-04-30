#import "../src/lib.typ": spec, requirement, scenario
#import "../links.typ"
#import "../glossary.typ"

#show: glossary.glossary
#show: spec.with(title: "Typspec Config Schema")

= Typspec Config Schema Specification

This document specifies the schema and semantics of typspec config files.

== Config File Formats

#requirement("config-formats", priority: "shall")[
  Config files SHALL be valid JSON or JSONC (JSON with Comments).

  Both `.json` and `.jsonc` extensions SHALL be accepted. `.jsonc` files
  support `//` and `/* */` comments and trailing commas. `.json` files
  are parsed strictly. Both formats use the same schema.

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
  The CLI SHALL discover config files by walking up from the current
  working directory.

  The `$schema` field in the generated config SHALL point to the raw
  GitHub URL of the schema file, not a typspec.dev domain.

  #scenario("init writes correct schema URL",
    when: [`typspec init` runs],
    then: [`$schema` in typspec.jsonc is the raw GitHub URL],
  )
]

== Schema: project

#requirement("schema-project", priority: "shall")[
  The `project` section SHALL define the identity of the current
  package. The JSON Schema description for each field SHALL come
  from doc comments on the Rust struct.
]

== Schema: workspaces

#requirement("schema-workspaces", priority: "shall")[
  The `workspaces` section SHALL declare the specs that this package
  references. Each key is a stable workspace ID.

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

  Unlisted spec files are considered internal and not referenceable by
  external packages.

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

  Replaces freeform context strings with structured fields. Skills and the
  CLI make this context available.

  #scenario("context read by skills",
    given: [config has `context.tech_stack`],
    when: [AI skill proposes a change],
    then: [context included in skill instructions],
  )
]

== Schema: typspec version

#requirement("schema-typspec-version", priority: "shall")[
  The top-level `typspec` field SHALL declare the minimum supported CLI version.
  If the CLI version is less than the declared version, the CLI SHALL error
  with an upgrade suggestion.
]

