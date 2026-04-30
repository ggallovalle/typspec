#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group
#import "../links.typ"

#show: change.with(id: "spec-architecture", modifies: ("cli", "config", "module-api", "ai-skills", "docs"))

= Proposal

== Motivation

The #links.spec-cli spec has grown to 726 lines across four distinct concerns: CLI interface, archive business logic, init/scaffold behavior, and skill template content. This makes it hard to reason about any single concern — especially archive, whose requirements are duplicated 3× due to accretion.

Meanwhile, the domain language lives in a Hayagriva YAML file (`bibliographies/domain-language.yaml`) that can't leverage Typst-native glossary features like first-use expansion and back-references provided by the #links.pkg-glossarium package.

Three issues to solve:

1. *Spec bloat* — Archive, init, and install logic don't belong in the CLI spec. They describe behavior that happens to be CLI-accessible, not the CLI interface itself.
2. *Glossary format* — Hayagriva #links.typst-bibliography works for citations but lacks glossary-specific features. The #links.pkg-glossarium Typst package provides first-use expansion, glossary printing, and back-references.
3. *Duplication* — `added-body-from-source` appears 3×, `archive-routes-by-modifies` 2×, `validation-requirement-in-change-modifies` 2×, `validation-target-spec-exists` 2× in `cli.typ`. `requirement-modifies-param` appears 2× in `module-api.typ`. `docs.typ` has its entire content duplicated.

== Scope

In scope:
- Split `cli.typ` into: `cli.typ` (lean interface), `archive.typ` (archive logic), `scaffold.typ` (init + new), `install.typ` (workspace deps)
- Migrate domain language from `bibliographies/domain-language.yaml` to #links.glossary using #links.pkg-glossarium
- Update spec imports to use glossarium instead of Hayagriva bibliography
- Remove all duplicate requirements across spec files
- Remove `cli-uses-configured-paths` (feature no longer supported)
- Move skill template content from `cli.typ` to `ai-skills.typ`
- Move `init-tools-flag` and tool-directory-mapping to `scaffold.typ`
- Remove `config-paths-section` from `config.typ`
- Move `init-creates-example-bibliography` to `scaffold.typ`

Out of scope:
- Redesigning archive as a coherent operation (separate change)
- Any functional changes to the CLI binary
- Changes to `typspec/src/lib.typ` (template stays untouched)

= Design

#decision(
  "Domain specs describe behavior in terms of inputs, not flags",
  rationale: [
    Archive, init, and install logic shouldn't know they're called from a CLI.
    Each domain spec defines its operation in terms of typed inputs
    (e.g., `dry_run: bool`, `change_id: string`, `config: Config`).
    The CLI layer in `cli.typ` translates flags into these input objects.
    This keeps the domain logic testable and CLI-agnostic.
  ],
  alternatives: [
    "Keep everything in cli.typ: works but violates separation of concerns",
    "Thin CLI layer with inline domain logic: no clear boundary",
  ],
)

#decision(
  "Glossarium replaces Hayagriva for domain language",
  rationale: [
    The #links.pkg-glossarium package provides first-use expansion
    (shows long form on first `@key` reference, short form thereafter),
    automatic glossary printing with back-references, and Typst-native
    content blocks for descriptions (enabling cross-refs between entries).
    The `glossary.typ` module exports entries that specs import and register.
    This coexists with #links.typst-bibliography for non-glossary citations.
  ],
  alternatives: [
    "Stay on Hayagriva: no glossary features, YAML can't cross-reference",
    "Inline glossary in each spec: duplication, no single source of truth",
  ],
)

#decision(
  "Glossary entries use concept+keyword hybrid",
  rationale: [
    Each entry's `long` form is the conceptual name (lowercase, reads in a
    sentence), `short` is the code keyword or shorthand. First use shows
    "concept (keyword)", subsequent uses show just "keyword".
    Example: `@modifies` → first: "spec targeting (modifies)", after: "modifies".
  ],
  alternatives: [],
)

#decision(
  "Template stays untouched — specs import glossarium directly",
  rationale: [
    Each spec imports glossarium and the glossary entries, runs
    `#show: make-glossary`, registers entries, and prints the glossary.
    This is 3 extra lines per spec but avoids coupling `lib.typ` to a specific
    glossary package version or entry list.
  ],
  alternatives: [
    "Auto-register in lib.typ: couples template to glossarium, harder to version",
  ],
)

= Spec Deltas

== ADDED Requirements

=== archive.typ

#requirement("archive-spec", priority: "shall", action: "added", modifies: "cli")[
  The archive command behavior SHALL be specified in `archive.typ`.
  The `cli.typ` `cmd-archive` requirement SHALL reference `archive.typ`
  for all behavior beyond the command's interface (name, args, flags, exit codes).
]

=== scaffold.typ

#requirement("scaffold-spec", priority: "shall", action: "added", modifies: "cli")[
  The init and new command behavior SHALL be specified in `scaffold.typ`.
  The `cli.typ` `cmd-init` and `cmd-new` requirements SHALL reference
  `scaffold.typ` for all behavior beyond the command's interface.
]

=== install.typ

#requirement("install-spec", priority: "shall", action: "added", modifies: "cli")[
  The install command behavior (workspace resolution, git cloning) SHALL be
  specified in `install.typ`. The `cli.typ` `cmd-install` requirement SHALL
  reference `install.typ` for all behavior beyond the command's interface.
]

=== glossary.typ

#requirement("glossary-module", priority: "shall", action: "added", modifies: "cli")[
  Shared domain language terms SHALL live in `typspec/glossary.typ` as a
  Typst module exporting an `entries` array compatible with
  #links.pkg-glossarium. Each spec SHALL import and register these entries.
]

=== ai-skills.typ (absorbed from cli.typ)

#requirement("skill-templates", priority: "shall", action: "added", modifies: "ai-skills")[
  The skill templates SHALL follow the content requirements specified in
  this section, migrated from `cli.typ`.

  All four skill templates SHALL reference `typspec list` showing file paths,
  `typspec which <name>` for file location, and the canonical directory layout.

  Templates SHALL use Mermaid diagram syntax over ASCII art for structured
  diagrams. ASCII is acceptable when no Mermaid equivalent exists.

  #scenario("propose references list with paths",
    when: [propose skill is rendered],
    then: [it tells AI to use `typspec list --specs` with paths],
  )

  #scenario("archive skill references which",
    when: [archive skill is rendered],
    then: [it tells AI to use `typspec which` to find archived changes],
  )
]

#requirement("attribution-comment", priority: "shall", action: "added", modifies: "ai-skills")[
  Each generated `SKILL.md` SHALL contain an HTML comment at the top:
  `<!-- Generated by typspec (https://github.com/ggallovalle/typspec) -->`
  This comment SHALL NOT appear in rendered skill content.
]

#requirement("single-source-skills", priority: "shall", action: "added", modifies: "ai-skills")[
  Skill templates SHALL be sourced from the canonical `skills/typspec/`
  directory. At compile time, each `SKILL.md` is embedded via `include_str!()`.
  The `YAML metadata.generatedBy` field SHALL contain a version marker
  replaced with the crate version at generation time.

  #scenario("skills embedded",
    when: [CLI runs `init --tools`],
    then: [skills written from embedded source, match `skills/` canonical forms],
  )

  #scenario("version injected",
    when: [skill is generated],
    then: [`metadata.generatedBy` matches the CLI version],
  )
]

=== scaffold.typ (init behavior absorbed from cli.typ + config.typ)

#requirement("init-tools-flag", priority: "shall", action: "added", modifies: "scaffold")[
  The `typspec init` command SHALL accept a `--tools` flag that accepts
  a comma-separated list of AI tool IDs. Supported tool IDs: `claude`,
  `codex`, `opencode`.

  `--tools all` SHALL select all supported tools.
  `--tools none` SHALL skip skill generation entirely.
  Invalid tool IDs SHALL error with available options.

  #scenario("tools with valid IDs",
    when: [`typspec init --tools claude,codex`],
    then: [skills generated for Claude and CodEX],
  )

  #scenario("tools all",
    when: [`typspec init --tools all`],
    then: [skills generated for all supported tools],
  )
]

#requirement("skill-directory-mapping", priority: "shall", action: "added", modifies: "scaffold")[
  Each supported tool SHALL have a known skills directory path:

  | Tool      | Skills dir          |
  |-----------|---------------------|
  | `claude`  | `.claude/skills/`   |
  | `codex`   | `.agents/skills/`   |
  | `opencode`| `.agents/skills/`   |

  The directory SHALL be created if it does not exist. Existing skill
  files SHALL be overwritten.

  #scenario("claude skills dir",
    when: [`--tools claude`],
    then: [`.claude/skills/typspec-*/SKILL.md` created],
  )
]

#requirement("init-example-bibliography", priority: "should", action: "added", modifies: "scaffold")[
  The `typspec init` command SHOULD write a minimal `example.yaml` to
  the `bibliographies/` directory. It SHALL contain generic entries (not
  typspec-specific terms like `damlev`) and a comment linking to the
  Hayagriva file format docs.
]

== MODIFIED Requirements

=== cli.typ — cmd-init, cmd-new, cmd-archive, cmd-install

#requirement("cmd-init", priority: "shall", action: "modified", modifies: "cli")[
  Scaffold a new typspec project. Interface only — behavior specified in
  `scaffold.typ`.

  Arguments: `[path]` — target directory (optional, defaults to CWD).
  Flags: `--tools <list>` — comma-separated tool IDs.
  Exit: 0 on success, 1 on error.
]

#requirement("cmd-new", priority: "shall", action: "modified", modifies: "cli")[
  Create a new spec or change file from a template. Interface only —
  behavior specified in `scaffold.typ`.

  Arguments: `spec <name>` or `change <name>`.
  Exit: 0 on success, 1 on error.
]

#requirement("cmd-archive", priority: "shall", action: "modified", modifies: "cli")[
  Archive a completed change. Interface only — behavior specified in
  `archive.typ`.

  Arguments: `<name>` — change to archive.
  Flags: `[-n, --dry-run]` — preview without side effects.
  Exit: 0 on success, 1 on error.
]

#requirement("cmd-install", priority: "should", action: "modified", modifies: "cli")[
  Fetch workspace dependencies. Interface only — behavior specified in
  `install.typ`.

  Flags: none.
  Exit: 0 on success, 1 on error.
]

=== cli.typ — cmd-list, cmd-status, cmd-render, cmd-validate

These commands stay in `cli.typ` (thin wrappers around typst). Their
requirements in the spec will be revised to describe the interface only,
but the behavioral content is largely correct as-is. Minor trimming to
remove implementation detail.

=== cli.typ — cross-cutting

#requirement("cli-sets-root-for-bibliographies", priority: "shall", action: "modified", modifies: "cli")[
  The CLI SHALL pass `--root` set to the config file's parent directory
  when invoking `typst compile` for rendering, validation, and queries.

  This applies to render, validate, status, and archive commands.
]

== REMOVED Requirements

=== cli.typ — moved to archive.typ

#requirement("added-body-from-source", priority: "shall", action: "removed", modifies: "cli")[
  2 of the 3 duplicates removed, the remaining copy moves to `archive.typ`.
]

#requirement("archive-routes-by-modifies", priority: "shall", action: "removed", modifies: "cli")[
  1 of the 2 duplicates removed, the remaining copy moves to `archive.typ`.
]

#requirement("validation-requirement-in-change-modifies", priority: "shall", action: "removed", modifies: "cli")[
  1 of the 2 duplicates removed, the remaining copy moves to `archive.typ`.
]

#requirement("validation-target-spec-exists", priority: "shall", action: "removed", modifies: "cli")[
  1 of the 2 duplicates removed, the remaining copy moves to `archive.typ`.
]

#requirement("git-mv-for-tracked-files", priority: "shall", action: "removed", modifies: "cli")[
  Moves to `archive.typ`.
]

=== cli.typ — moved to scaffold.typ

#requirement("init-tools-flag", priority: "shall", action: "removed", modifies: "cli")[
  Moves to `scaffold.typ`.
]

=== cli.typ — moved to ai-skills.typ

#requirement("skill-templates", priority: "shall", action: "removed", modifies: "cli")[
  Moves to `ai-skills.typ`.
]

#requirement("attribution-comment", priority: "shall", action: "removed", modifies: "cli")[
  Moves to `ai-skills.typ`.
]

#requirement("mermaid-diagrams", priority: "shall", action: "removed", modifies: "cli")[
  Moves to `ai-skills.typ`.
]

#requirement("single-source-skills", priority: "shall", action: "removed", modifies: "cli")[
  Moves to `ai-skills.typ`.
]

#requirement("skill-updates-for-list", priority: "shall", action: "removed", modifies: "cli")[
  Moves to `ai-skills.typ`.
]

#requirement("skill-references-which", priority: "shall", action: "removed", modifies: "cli")[
  Moves to `ai-skills.typ`.
]

=== cli.typ — removed entirely (dead feature)

#requirement("cli-uses-configured-paths", priority: "shall", action: "removed", modifies: "cli")[
  Configurable paths feature is no longer supported. All paths use defaults.
]

=== config.typ — removed

#requirement("config-paths-section", priority: "shall", action: "removed", modifies: "config")[
  The `paths` section in `typspec.jsonc` is no longer supported. CLI uses
  hardcoded defaults for spec, change, and archive directories.
]

#requirement("test-body-extract", priority: "shall", action: "removed", modifies: "config")[
  Removed — this was a dummy/test requirement.
]

#requirement("init-creates-example-bibliography", priority: "should", action: "removed", modifies: "config")[
  Moves to `scaffold.typ`.
]

=== module-api.typ — deduplication

#requirement("requirement-modifies-param", priority: "shall", action: "removed", modifies: "module-api")[
  One duplicate removed. The remaining copy stays in `module-api.typ`.
]

#requirement("template-includes-bibliographies", priority: "shall", action: "removed", modifies: "module-api")[
  Removed for clarity. Domain language references now use glossarium.
  Non-glossary bibliographies are included per-spec.
]

=== docs.typ — deduplication

All requirements from lines 123–155 of `docs.typ` are exact duplicates
of requirements listed earlier in the same file. These are removed.

= Tasks

#task_group("1. Create new spec files", (
  task([Create `typspec/specs/archive.typ` with archive business logic requirements migrated from cli.typ (added-body-from-source, archive-routes-by-modifies, validation-requirement-in-change-modifies, validation-target-spec-exists, git-mv-for-tracked-files)], done: true, labels: ("specs",)),
  task([Create `typspec/specs/scaffold.typ` with init + new behavior from cli.typ and config.typ (init-tools-flag, skill-directory-mapping, init-example-bibliography)], done: true, labels: ("specs",)),
  task([Create `typspec/specs/install.typ` with workspace dependency resolution behavior from cli.typ], done: true, labels: ("specs",)),
))

#task_group("2. Trim cli.typ", (
  task([Rewrite cmd-init, cmd-new, cmd-archive, cmd-install as lean interface descriptions referencing domain specs], done: true, labels: ("specs",)),
  task([Remove archive logic requirements from cli.typ], done: true, labels: ("specs",)),
  task([Remove skill template requirements from cli.typ], done: true, labels: ("specs",)),
  task([Remove init-tools-flag from cli.typ], done: true, labels: ("specs",)),
  task([Remove cli-uses-configured-paths, config-paths-section references], done: true, labels: ("specs",)),
  task([Revise cross-cutting requirements (cli-sets-root-for-bibliographies) to reference glossarium instead of Hayagriva], done: true, labels: ("specs",)),
))

#task_group("3. Update ai-skills.typ", (
  task([Add skill-templates, attribution-comment, mermaid-diagrams, single-source-skills, skill-updates-for-list, skill-references-which to ai-skills.typ], done: true, labels: ("specs",)),
  task([Update ai-skills.typ to reference glossarium instead of bibliography], done: true, labels: ("specs",)),
))

#task_group("4. Update config.typ", (
  task([Remove config-paths-section, test-body-extract, init-creates-example-bibliography from config.typ], done: true, labels: ("specs",)),
  task([Remove tool-directory-mapping from config.typ (moves to scaffold.typ)], done: true, labels: ("specs",)),
))

#task_group("5. Deduplicate specs", (
  task([Remove 2 duplicate copies of added-body-from-source from cli.typ], done: true, labels: ("specs",)),
  task([Remove 1 duplicate copy of archive-routes-by-modifies from cli.typ], done: true, labels: ("specs",)),
  task([Remove 1 duplicate copy of validation-requirement-in-change-modifies from cli.typ], done: true, labels: ("specs",)),
  task([Remove 1 duplicate copy of validation-target-spec-exists from cli.typ], done: true, labels: ("specs",)),
  task([Remove 1 duplicate copy of requirement-modifies-param from module-api.typ], done: true, labels: ("specs",)),
  task([Remove all duplicate requirements from docs.typ (lines 123-155)], done: true, labels: ("specs",)),
  task([Remove template-includes-bibliographies from module-api.typ], done: true, labels: ("specs",)),
))

#task_group("6. Migrate glossary to glossarium", (
  task([Remove `bibliographies/domain-language.yaml`], done: true, labels: ("glossary",)),
  task([Update all specs to import and use glossary.typ + glossarium instead of `bibliographies/domain-language.yaml`], done: true, labels: ("glossary",)),
  task([Update archived changes to use glossary.typ + glossarium instead of bibliography refs], done: true, labels: ("glossary",)),
  task([Verify all \@key references compile with glossarium], done: true, labels: ("glossary",)),
))

#task_group("7. Verify and cleanup", (
  task([Run typspec validate on all specs and changes], done: true, labels: ("tests",)),
  task([Render each spec to PDF and verify glossary output], done: false, labels: ("tests",)),
))
