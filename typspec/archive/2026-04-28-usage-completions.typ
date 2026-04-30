#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "usage-completions", modifies: ("cli",))

= Proposal

== Motivation

The `typspec` CLI currently has no shell completion support. Users must
remember command names, flag names, spec names, and change names without
any tab-completion assistance.

Following the same model as `mise` (which uses `usage` internally), we add:
- `typspec usage` — outputs a KDL usage spec describing the CLI
- `typspec completion <shell>` — generates a shell completion script
- `typspec list --complete` — hidden flag outputting bare names for
  dynamic completions (specs, changes, archive)

The `usage` CLI (https://usage.jdx.dev) is a runtime dependency for
completions, matching mise's model exactly.

== Scope

In scope:
- `typspec usage` hidden command outputting KDL spec with `complete` directives
- `typspec completion zsh` generating a zsh completion script (mise-style)
- `typspec list --complete` hidden flag for dynamic name completions
- Dynamic completions for `status`, `archive`, `which` commands
- Completion order: specs first, then changes, then archive

Out of scope:
- Shells beyond zsh (bash/fish/powershell can be added later)
- `typspec activate <shell>` (no env hooks needed; completion is sufficient)
- Changes to how commands resolve names (bare names stay as-is)

= Design

#decision(
  "Follow mise's usage integration pattern",
  rationale: [
    Mise already solves this problem using `usage` (same author). Its
    pattern is: hidden `usage` command → KDL spec with `complete`
    directives → hidden `--complete` flags on subcommands → generated
    completion script wrapping `usage complete-word`. We replicate this
    exactly so the integration is well-understood and compatible.

    Key advantage: `usage complete-word` handles all shell-specific
    completion logic. The KDL spec is the only thing we maintain —
    `usage` generates zsh/bash/fish/powershell scripts from it.
  ],
  alternatives: [
    - clap_complete crate: static completions only, no dynamic
      spec/change name suggestions.
    - Hand-written completion scripts: fragile, per-shell maintenance.
    - `usage` spec file in repo: drifts from Rust code. Self-describing
      CLI (typspec usage) stays in sync automatically.
  ],
)

#decision(
  "Completion sources per command",
  rationale: [
    `status` accepts specs + changes, `archive` accepts only changes,
    `which` accepts specs + changes + archive. Each command needs a
    different completion source. The KDL `complete` directive maps arg
    names to specific `--complete` calls.

    For `status`: `typspec list --specs --complete; typspec list --complete`
    For `archive`: `typspec list --complete`
    For `which`: `typspec list --all --complete`
  ],
  alternatives: [
    - One unified source: wrong for `archive` (would suggest specs).
    - Single `typspec _complete` hidden subcommand: more code, mise
      pattern uses `--complete` flags on existing commands.
  ],
)

#decision(
  "Completion output is bare names, not paths",
  rationale: [
    Commands accept bare names (`module-api`, not
    `typspec/specs/module-api.typ`). The `--complete` flag outputs
    one bare name per line, matching what the user would type.

    For archive names, the date prefix is stripped since `which`
    matches by suffix (stem ends with `-<name>` or equals `<name>`).
  ],
  alternatives: [],
)

= Spec Deltas

== ADDED Requirements

#requirement("cmd-usage", priority: "shall", action: "added", modifies: "cli")[
  The CLI SHALL provide a hidden `usage` subcommand that outputs a
  `.usage.kdl` format spec describing the full CLI.

  The spec SHALL include:
  - All commands, flags, and positional args
  - `complete` directives for dynamic value completion on `status`,
    `archive`, and `which` arguments
  - Hidden flags (`hide=#true`) for `--complete` on `list`

  #scenario("usage outputs valid KDL",
    when: [`typspec usage`],
    then: [output is valid usage KDL spec, parsable by `usage lint`],
  )

  #scenario("usage spec includes complete directives",
    when: [`typspec usage`],
    then: [spec contains `complete` for status/archive/which name args],
  )
]

#requirement("cmd-completion", priority: "shall", action: "added", modifies: "cli")[
  The CLI SHALL provide a `completion <shell>` subcommand that outputs a
  shell completion script for the given shell.

  The generated script SHALL:
  - Error with clear message if `usage` CLI is not installed
  - Cache the spec from `typspec usage` in `$TMPDIR`
  - Call `usage complete-word` to generate completions
  - Match mise's generated completion script structure exactly

  #scenario("completion zsh outputs valid script",
    when: [`typspec completion zsh > _typspec`],
    then: [script contains `#compdef typspec` and calls `usage complete-word`],
  )

  #scenario("completion errors without usage",
    when: [`usage` CLI is not installed, user sources completion script],
    then: [script prints error message instructing to install usage],
  )
]

#requirement("cmd-list-complete", priority: "shall", action: "added", modifies: "cli")[
  The `list` command SHALL support a hidden `--complete` flag that
  outputs bare names (one per line) for use by `usage`'s `complete`
  directive.

  Output SHALL follow this order:
  - `typspec list --complete` — change names only
  - `typspec list --specs --complete` — spec names only
  - `typspec list --all --complete` — specs first, then changes, then
    archive names (with date prefixes stripped)

  #scenario("list --complete outputs change names",
    when: [`typspec list --complete`],
    then: [one change name per line, no paths or descriptions],
  )

  #scenario("list --specs --complete outputs spec names",
    when: [`typspec list --specs --complete`],
    then: [one spec name per line],
  )

  #scenario("list --all --complete includes archive names",
    given: [archived change `2026-04-28-old-feature.typ` exists],
    when: [`typspec list --all --complete`],
    then: [output includes `old-feature` (date prefix stripped)],
  )
]

#requirement("usage-as-runtime-dep", priority: "should", action: "added", modifies: "cli")[
  The completion scripts SHALL depend on the `usage` CLI being installed.
  If `usage` is not found, the completion script SHALL print an error
  and exit cleanly.

  #scenario("missing usage shows helpful error",
    when: [completion script runs without `usage` installed],
    then: [message: "Error: usage CLI not found. See https://usage.jdx.dev"],
  )
]

= Tasks

#task_group("1. Add dependencies", (
  task([Add `clap_usage` crate to `crates/cli/Cargo.toml`], done: true, labels: ("cli",)),
))

#task_group("2. Implement typspec usage", (
  task([Add hidden `typspec usage` subcommand that generates KDL spec], done: true, labels: ("cli",)),
  task([Include `complete` directives for status/archive/which name args], done: true, labels: ("cli",)),
))

#task_group("3. Implement typspec completion", (
  task([Add `typspec completion <shell>` subcommand], done: true, labels: ("cli",)),
  task([Generate zsh completion script matching mise's pattern], done: true, labels: ("cli",)),
))

#task_group("4. Implement --complete flags", (
  task([Add hidden `--complete` flag to `list` for bare name output], done: true, labels: ("cli",)),
  task([Add `--all` flag to `list` to include archive names], done: true, labels: ("cli",)),
))

#task_group("5. Verify", (
  task([Run `typspec usage | usage lint`, verify clean], done: true, labels: ("tests",)),
  task([Run `typspec completion zsh > _typspec`, verify script structure], done: true, labels: ("tests",)),
  task([Run `cargo build` with no warnings], done: true, labels: ("tests",)),
  task([Manual: source generated script and verify tab-completion works], done: true, labels: ("tests",)),
))

