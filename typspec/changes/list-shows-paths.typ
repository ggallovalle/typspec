#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "list-shows-paths", modifies: ("cli",))

= Proposal

== Motivation

`typspec list` and `typspec list --specs` show names but not paths:

```
$ typspec list --specs
  config
  cli
  module-api
```

This is misleading because users can configure custom spec/change directories
via `typspec.jsonc` paths. The names alone don't tell the user where the
files actually live on disk. The list output should include the full relative
path so users can open the files directly.

Additionally, the generated AI skill templates reference hardcoded paths like
`typspec/changes/<name>.typ` which is incorrect when paths are customized.

== Scope

In scope:
- `typspec list` shows paths alongside names: `  module-api (typspec/specs/module-api.typ)`
- `typspec list --json` includes a `path` field in each entry
- Update skill templates to use `typspec list` for path discovery instead of hardcoded paths
- Skill instructions: "read the change file at the path shown by `typspec status <name>`"

Out of scope:
- Adding `typspec which <name>` command (separate change)
- Showing paths in `typspec status` output (the `--json` already includes it implicitly)

= Design

#decision(
  "Show path in parentheses after name in list output",
  rationale: [
    Minimal change to output format. The name is what AI agents use for
    commands; the path is supplementary info for humans. JSON output
    adds a `path` field for programmatic use.
  ],
  alternatives: [
    - Show path only: breaks existing workflows that parse the name.
    - Show full path instead of name: the name (file stem) is what CLI commands use.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("list-shows-paths", priority: "shall", action: "added", modifies: "cli")[
  The `typspec list` and `typspec list --specs` commands SHALL show the
  relative file path alongside each entry name.

  In human-readable mode:
  ```
    module-api (typspec/specs/module-api.typ)
  ```

  In JSON mode, each entry SHALL include a `path` field:
  ```json
  [{"name": "module-api", "path": "typspec/specs/module-api.typ"}]
  ```

  #scenario("list specs shows paths",
    when: [`typspec list --specs`],
    then: [output shows `name (relative/path.typ)` for each spec],
  )

  #scenario("list changes shows paths",
    when: [`typspec list`],
    then: [output includes paths for each change file],
  )

  #scenario("list with JSON includes path field",
    when: [`typspec list --json`],
    then: [JSON array with `name` and `path` fields per entry],
  )
]

== MODIFIED Requirements

#requirement("skill-templates", action: "modified", modifies: "cli")[
  The generated skill templates SHALL NOT hardcode directory paths.
  Instead, they SHALL instruct the AI to use `typspec list --specs`
  and `typspec list` to discover file locations, and `typspec status`
  to find the exact file path.
]

= Tasks

#task_group("1. CLI", (
  task([Update `cmd_list` to show file paths in human-readable output], done: false, labels: ("cli",)),
  task([Update `cmd_list` JSON output to include `name` + `path` fields], done: false, labels: ("cli",)),
))

#task_group("2. Skill Templates", (
  task([Update explore template: don't hardcode typspec/changes/, use typspec list instead], done: false, labels: ("cli",)),
  task([Update propose template: don't hardcode paths, reference typspec list for discovery], done: false, labels: ("cli",)),
  task([Update apply template: reference typspec status for exact file path], done: false, labels: ("cli",)),
  task([Update archive template: same treatment], done: false, labels: ("cli",)),
))
