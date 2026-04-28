#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "canonical-typspec-directory", modifies: ("module-api", "cli", "config"))

= Proposal

== Motivation

The current design allows users to configure custom paths for specs,
changes, archive, and bibliographies via `typspec.jsonc`. This adds
complexity with little benefit — every project needs to decide where
things go, and tools/AI agents can't rely on a canonical location.

A canonical structure simplifies everything:

```
/typspec/
  typspec.json{c}     ← config (always here)
  bibliographies/     ← .yaml bibliography files
  specs/              ← .typ spec files
  changes/            ← active .typ change files
  archive/            ← archived .typ changes
```

Benefits:
- No `paths` config section needed — removed entirely
- No `bibliographies` config field needed — always under `typspec/bibliographies/`
- Config discovery always looks for `typspec/typspec.json{c}` — simpler walk-up logic
- CLI commands resolve paths relative to config directory after walk-up
- AI agent skills can reference canonical paths
- The `bibliography` parameter on `#show: spec.with(...)` goes away — the template
  calls `#bibliography()` for every `.yaml` file in `typspec/bibliographies/`

== Scope

In scope:
- Remove `paths` section from `TypspecConfig` and `PathsConfig` struct
- Remove `bibliographies` field from `TypspecConfig`
- Remove `bibliography` parameter from `spec` and `change` templates in `lib.typ`
- Config discovery looks for `typspec/typspec.json{c}` only (simplify filenames list)
- CLI resolves canonical paths relative to the config file's directory:
  `<config-dir>/specs/`, `<config-dir>/changes/`, `<config-dir>/archive/`
- Template calls `#bibliography()` for each `.yaml` file in `typspec/bibliographies/`
- Update all archived change documents to remove bibliography parameters
- Update all spec documents to remove bibliography parameters

Out of scope:
- Moving existing files on disk (manual step after change)
- The `exports` config section (stays as-is)

= Design

#decision(
  "Canonical directory — no configurable paths",
  rationale: [
    Every tool, agent, and user knows where things live without reading
    config. The `paths` option added complexity for marginal benefit.
    If a project truly needs a different layout, they can symlink.
  ],
  alternatives: [
    - Keep paths configurable: complex, no canonical location.
    - Environment variables: harder to discover than filesystem convention.
  ],
)

#decision(
  "Template calls #bibliography for each file in typspec/bibliographies/",
  rationale: [
    Instead of listing bibliography files in config, the `spec` template
    scans `typspec/bibliographies/` for all `.yaml` files and calls
    `#bibliography(f, style: "iso-690-numeric")` for each. No config,
    no parameter — just drop a `.yaml` file in the right directory.

    However, Typst's security model restricts file access to within the
    project root directory (`--root`). By default, the root is the parent
    of the main `.typ` file. A spec at `typspec/specs/foo.typ` cannot
    use `../bibliographies/` because that path escapes the root.

    The CLI SHALL always pass `--root` pointing to the config file's
    parent directory (the project root). The template SHALL use paths
    relative to that root, e.g., `"typspec/bibliographies/file.yaml"`.
  ],
  alternatives: [
    - Keep `bibliographies` config field: redundancy with filesystem.
    - Keep `bibliography` parameter on spec template: every document repeats it.
    - Symlink bibliographies into specs/: works but fragile, easy to forget.
  ],
)

= Spec Deltas

== MODIFIED Requirements

#requirement("config-discovery", action: "modified")[
  The config discovery SHALL look for `typspec/typspec.json{c}` by walking up
  from the current directory, stopping at the first directory containing a
  `.git` folder or at the user's home directory — whichever comes first.
  This replaces the previous multi-path discovery that walked to the
  filesystem root.

  All other filename variants from the previous config discovery SHALL be
  removed — only `typspec/typspec.json{c}` (plus `.local.` and env-specific
  overrides) are supported.

  #scenario("discovery finds typspec/typspec.jsonc",
    given: [project has `typspec/typspec.jsonc`],
    when: [CLI runs],
    then: [config loaded from that path],
  )

  #scenario("discovery stops at git root",
    given: [parent git repo has no `typspec/` directory],
    when: [CLI runs from a subdirectory],
    then: [walk-up stops at `.git`, no config found, error suggesting `typspec init`],
  )

  #scenario("discovery stops at home",
    given: [no `.git` found but home directory reached],
    when: [CLI runs],
    then: [walk-up stops at `~`, no config found],
  )
]

== ADDED Requirements

#requirement("template-includes-bibliographies", priority: "shall", action: "added", modifies: "module-api")[
  The `spec` and `change` document templates SHALL call `#bibliography()` for
  each `.yaml` file found in `typspec/bibliographies/`.

  The `bibliography` parameter on `#show: spec.with(...)` and
  `#show: change.with(...)` SHALL be removed.

  #scenario("bibliographies included",
    given: [`typspec/bibliographies/domain-language.yaml` exists],
    when: [document renders with `--root` set to config dir's parent],
    then: [template calls `#bibliography("typspec/bibliographies/domain-language.yaml")`, citation resolves],
  )
]

#requirement("cli-sets-root-for-bibliographies", priority: "shall", action: "added", modifies: "cli")[
  The CLI SHALL pass `--root` set to the config file's parent directory
  when invoking `typst compile` for rendering, validation, and queries.

  This ensures that bibliography paths like
  `typspec/bibliographies/file.yaml` resolve correctly from any spec,
  change, or archive document, regardless of their subdirectory.

  #scenario("render sets root",
    when: [`typspec render typspec/specs/module-api.typ`],
    then: [internally calls `typst compile --root <project-root> ...`],
  )

  #scenario("validate sets root",
    when: [`typspec validate typspec/specs/module-api.typ`],
    then: [internally calls `typst compile --root <project-root> ...`],
  )

  #scenario("status sets root",
    when: [`typspec status module-api`],
    then: [internally calls `typst query --root <project-root> ...`],
  )
]

== REMOVED Requirements

#requirement("config-paths-section", action: "removed")[
  The `paths` section in `typspec.jsonc` SHALL be removed. All directories
  are determined by the canonical structure.
]

#requirement("config-bibliographies", action: "removed")[
  The `bibliographies` field in `typspec.jsonc` SHALL be removed.
  Bibliography files are included via `#bibliography()` calls in the
  template from `typspec/bibliographies/`.
]

#requirement("spec-bibliography-param", action: "removed")[
  The `bibliography` parameter on `#show: spec.with(...)` and
  `#show: change.with(...)` SHALL be removed.
]

= Tasks

#task_group("1. Config & Core Library", (
  task([Remove `PathsConfig` struct from config.rs], done: false, labels: ("core",)),
  task([Remove `paths` and `bibliographies` fields from `TypspecConfig`], done: false, labels: ("core",)),
  task([Simplify config discovery filenames to only `typspec/typspec.json{c}`], done: false, labels: ("core",)),
  task([Add git root and home directory ceiling to walk-up logic], done: false, labels: ("core",)),
  task([Remove `bibliographies` from merge_configs and test helpers], done: false, labels: ("core",)),
))

#task_group("2. Module", (
  task([Remove `bibliography` parameter from `spec` document template], done: false, labels: ("module",)),
  task([Remove `bibliography` parameter from `change` document template], done: false, labels: ("module",)),
  task([Add `#bibliography()` calls for `typspec/bibliographies/*.yaml` to both templates], done: false, labels: ("module",)),
  task([Ensure template paths use `typspec/bibliographies/` (relative to --root), not relative to spec file], done: false, labels: ("module",)),
  task([Update CLI render/validate/status commands to pass `--root` pointing to config dir's parent], done: false, labels: ("cli",)),
  task([Remove `resolve_paths` and `ResolvedPaths` from lib.rs], done: false, labels: ("module",)),
))

#task_group("3. CLI", (
  task([Remove `load_paths()` helper from main.rs], done: false, labels: ("cli",)),
  task([Replace `load_paths()` with canonical path resolution from config dir], done: false, labels: ("cli",)),
  task([Update `cmd_init` to create canonical directory structure], done: false, labels: ("cli",)),
))

#task_group("4. Documentation", (
  task([Update config spec to remove paths/bibliographies sections], done: false, labels: ("docs",)),
  task([Update module-api spec to remove bibliography parameter], done: false, labels: ("docs",)),
  task([Update CLI spec to reflect canonical paths], done: false, labels: ("docs",)),
  task([Update all archived changes to remove bibliography parameter], done: false, labels: ("docs",)),
  task([Update all spec files to remove bibliography parameter from spec.with()], done: false, labels: ("docs",)),
  task([Move existing typspec.jsonc to typspec/typspec.jsonc], done: false, labels: ("docs",)),
  task([Create typspec/bibliographies/ directory], done: false, labels: ("docs",)),
))
