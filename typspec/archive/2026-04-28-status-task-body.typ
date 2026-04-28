#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "status-task-body", modifies: ("module-api", "cli"))

= Proposal

== Motivation

`typspec status` shows task completion but not what the task is about:

```
  [ ] [task]
  [ ] [task]
  [ ] [task]
```

The task body (the description text) is missing. This makes the status output
nearly useless for understanding what work remains. The user has to open the
change file to see what each task is.

The fix has two parts:
1. Module: include the task body text in the emitted metadata
2. CLI: print the task body in the status output

== Scope

In scope:
- Add `description` field to `typspec:task` metadata containing the task body text
- Update `status` command to print task descriptions
- Truncate long descriptions for display (show first ~80 chars)

Out of scope:
- Rendering inline markup in descriptions (show as plain text)
- Making description searchable/filterable (future)

= Design

#decision(
  "Extract task descriptions from source in CLI, not from module metadata",
  rationale: [
    Typst's `metadata()` only accepts basic types (strings, numbers, booleans,
    arrays, dicts), not content blocks. There is no built-in way to convert a
    content block to its plain text representation without complex show-rule
    hacks. Instead, the CLI reads the change file source, parses it with
    `typst_syntax`, and extracts task body text directly — same pattern as
    `extract_requirement_body` for archive. This keeps the module clean and
    the CLI in control of display formatting.
  ],
  alternatives: [
    - Add a `description` string parameter to `#task`: burdens the user.
    - Use `repr()` on content blocks: produces internal AST repr, not readable.
    - Show-rule hack to capture rendered text: fragile, over-engineered.
  ],
)

#decision(
  "Default to `(no description)` when body is empty",
  rationale: [
    Edge cases (empty body, unparseable source) should not crash the status
    command. Display `(no description)` as fallback.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("status-prints-task-description", priority: "shall", action: "added", modifies: "cli")[
  The `typspec status` command SHALL display task descriptions alongside
  completion status by reading the change file source, parsing it with
  `typst_syntax`, and extracting the body text of each `#task()` call.

  Descriptions SHALL be truncated to 80 characters for display. When a
  task body cannot be extracted, display `(no description)`.

  #scenario("status shows descriptions",
    given: [change has tasks with descriptions],
    when: [`typspec status my-change`],
    then: [output shows `[ ] Implement X` instead of `[ ] [task]`],
  )

  #scenario("task with empty body",
    given: [task body is empty],
    when: [status runs],
    then: [displays `(no description)`],
  )
]

= Tasks

#task_group("1. Core Library", (
  task([Add `extract_task_body(source_text)` function using typst_syntax], done: true, labels: ("core",)),
))

#task_group("2. CLI", (
  task([In `cmd_status`, read change file and extract task descriptions], done: true, labels: ("cli",)),
  task([Print description alongside done status, truncate to 80 chars], done: true, labels: ("cli",)),
  task([Fall back to `(no description)` when extraction fails], done: true, labels: ("cli",)),
))
