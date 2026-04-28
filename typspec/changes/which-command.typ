#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "which-command", modifies: ("cli",))

= Proposal

== Motivation

AI agents and users need to find the file path for a spec, change, or
archive by name. Currently there's no single command for this — `status`
tries specs/changes and errors if not found, but doesn't show the path
in its output.

A `typspec which <name>` command fills this gap: search specs, changes,
and archive in order, return the first match. If no match, use the same
"did you mean" fuzzy matching (@damlev, ~67% threshold) that `status`
and `archive` already use.

== Scope

In scope:
- `typspec which <name>` searches specs → changes → archive
- Returns the relative file path of the first match
- Fuzzy matching with "did you mean" on no exact match
- Works with configured paths (respects typspec.jsonc paths)

Out of scope:
- Searching inside archive by default (done as last resort)
- Showing all matches across all directories
- `--json` flag for machine-readable output

= Design

#decision(
  "Search order: specs → changes → archive",
  rationale: [
    Specs are the primary lookup target. Changes are next (active work).
    Archive is searched last since archived changes are historical. The
    first match wins — a spec name shadows an archived change with the
    same name. This is intentional: active specs take priority.
  ],
  alternatives: [
    - Only search one directory: requires user to know the type.
    - Search all and show all: too noisy for a "which" command.
    - Let user specify type: extra arguments for a simple command.
  ],
)

#decision(
  "Reuse @fuzzy-matching from core library",
  rationale: [
    `typspec_core::fuzzy::best_fuzzy_match` already implements the
    @damlev distance with the ~67% threshold. The same `suggest_name` helper used
    by `status` and `archive` can be reused directly.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("which-command", priority: "should", action: "added", modifies: "cli")[
  The CLI SHALL provide a `typspec which <name>` command that locates a
  file by name across specs, changes, and archive directories.

  Search order SHALL be: specs → changes → archive. The first match is
  returned. If no exact match is found, the CLI SHALL apply the same
  "did you mean" fuzzy matching used by `status` and `archive`
  (@damlev, ~67% threshold).

  #scenario("which finds a spec",
    when: [`typspec which module-api`],
    then: [outputs the full path like `typspec/specs/module-api.typ`],
  )

  #scenario("which finds an archived change",
    when: [`typspec which customizable-paths`],
    then: [outputs the path in archive directory],
  )

  #scenario("which with typo shows suggestion",
    when: [`typspec which modle-api`],
    then: [shows error + "tip: a similar name exists: 'module-api'"],
  )

  #scenario("which with no match and no close name errors",
    when: [`typspec which completely-unrelated`],
    then: [error without suggestion],
  )
]

= Tasks

#task_group("1. CLI", (
  task([Add `Which` subcommand to Commands enum with `name` argument], done: false, labels: ("cli",)),
  task([Implement `cmd_which`: iterate specs → changes → archive dirs, return first match], done: false, labels: ("cli",)),
  task([Use `suggest_name` for fuzzy fallback on no match], done: false, labels: ("cli",)),
  task([Use configured paths from typspec.jsonc, respect customizable paths], done: false, labels: ("cli",)),
))
#bibliography("../bibliographies/domain-language.yaml", style: "iso-690-numeric")
