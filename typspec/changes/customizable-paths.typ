#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "customizable-paths", modifies: ("cli", "config"))

= Proposal

== Motivation

Currently all typspec directory paths are hardcoded:
- `typspec/specs/` for spec files
- `typspec/changes/` for active changes
- `typspec/archive/` for archived changes

Users who want to organize their project differently (e.g., keep specs in a
`docs/` directory, or use a flat `specs/` at the repo root) have no way to
configure this. The paths should be customizable via `typspec.jsonc` while
defaulting to the current convention.

== Scope

In scope:
- Add `paths` section to `typspec.jsonc` with `specs`, `changes`, `archive` keys
- CLI reads paths from config instead of hardcoded defaults
- All commands respect custom paths (init, new, list, status, render, archive)
- Backward compatible — omitted paths default to current values

Out of scope:
- Per-package path overrides (workspaces handle this)
- Template directory customization
- Output path customization for rendered PDFs

= Design

#decision(
  "Config section under `paths` key",
  rationale: [
    Clear section dedicated to filesystem layout. Matches common patterns
    (e.g., VS Code's `files.*` settings, Rust's `out-dir`). Separate from
    `workspaces` which handles cross-package references, not local layout.
  ],
  alternatives: [
    - Flat keys `specs_dir`, `changes_dir` at config root: pollutes top-level namespace.
    - Environment variables: harder to commit to repo, less discoverable.
  ],
)

#decision(
  "Paths relative to typspec.jsonc directory",
  rationale: [
    Config file location is the project anchor. All paths resolve relative to
    the config file's directory, not CWD. This keeps configs portable across
    machines and CI environments.
  ],
  alternatives: [
    - Relative to CWD: breaks when running from subdirectories.
    - Absolute paths: not portable.
  ],
)

#decision(
  "Default values match current hardcoded paths",
  rationale: [
    Zero-config projects keep working. Users only need to touch `paths` when
    they want a different layout. The defaults are the known-good values.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("config-paths-section", priority: "shall", action: "added")[
  The `typspec.jsonc` schema SHALL support a `paths` section with optional
  `specs`, `changes`, and `archive` string fields.

  ```jsonc
  {
    "paths": {
      "specs": "docs/specs",
      "changes": "docs/changes",
      "archive": "docs/archive"
    }
  }
  ```

  All paths SHALL be relative to the config file's directory. Each field
  defaults to its current hardcoded value when omitted.

  #scenario("all paths customized",
    given: [config with `paths.specs = "docs/specs"`, `paths.changes = "docs/changes"`, `paths.archive = "docs/archive"`],
    when: [CLI creates or reads files],
    then: [uses the configured paths instead of defaults],
  )

  #scenario("partial override",
    given: [config with only `paths.specs = "my-specs"`],
    when: [CLI runs],
    then: [specs read from `my-specs/`, changes and archive use defaults],
  )

  #scenario("no paths config",
    given: [config without a `paths` section],
    when: [CLI runs],
    then: [defaults used: `typspec/specs/`, `typspec/changes/`, `typspec/archive/`],
  )
]

#requirement("cli-uses-configured-paths", priority: "shall", action: "added")[
  All CLI commands SHALL resolve spec, change, and archive directories from
  config rather than using hardcoded paths.

  The `init` command SHALL create directories at the configured paths.

  #scenario("init respects configured paths",
    given: [config with `paths.specs = "docs/specs"`],
    when: [`typspec init`],
    then: [creates `docs/specs/` instead of `typspec/specs/`],
  )

  #scenario("list reads from configured paths",
    given: [config with `paths.changes = "proposals"`],
    when: [`typspec list`],
    then: [reads from `proposals/` directory],
  )

  #scenario("archive uses configured archive dir",
    given: [config with `paths.archive = "completed"`],
    when: [`typspec archive my-change`],
    then: [change moved to `completed/`],
  )

  #scenario("status resolves from configured paths",
    given: [config with `paths.specs = "specs"`, same file exists],
    when: [`typspec status module-api`],
    then: [reads `specs/module-api.typ`],
  )
]

== MODIFIED Requirements

#requirement("config-discovery", action: "modified")[
  Path resolution SHALL be relative to the config file's directory, not CWD.
  This ensures consistent behavior regardless of which subdirectory the user
  runs commands from.
]

= Tasks

#task_group("1. Config Schema", (
  task([Add `paths` struct to `TypspecConfig` with `specs`, `changes`, `archive` fields and defaults], done: false, labels: ("core",)),
  task([Parse `paths` from typspec.jsonc, validate relative paths], done: false, labels: ("core",)),
  task([Add path resolution helper: resolve relative to config dir with fallback to defaults], done: false, labels: ("core",)),
))

#task_group("2. CLI Commands", (
  task([Update `init` to create directories at configured paths], done: false, labels: ("cli",)),
  task([Update `list` to read from configured specs/changes dirs], done: false, labels: ("cli",)),
  task([Update `status` to resolve files from configured dirs], done: false, labels: ("cli",)),
  task([Update `render` to scan configured dirs], done: false, labels: ("cli",)),
  task([Update `archive` to move to configured archive dir], done: false, labels: ("cli",)),
  task([Update `new` (spec/change) to write to configured dirs], done: false, labels: ("cli",)),
))

#task_group("3. Config Spec Update", (
  task([Add `paths` section documentation to config spec], done: false, labels: ("docs",)),
  task([Update CLI spec with path resolution scenarios], done: false, labels: ("docs",)),
))
