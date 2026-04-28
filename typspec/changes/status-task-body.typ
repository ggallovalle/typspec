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
  "Include description in metadata, truncate at display time",
  rationale: [
    The task function already has the body content block. By serializing it
    to text and including the first N characters in metadata, the status
    command gets what it needs without re-parsing the source file. Truncation
    at ~80 chars keeps the metadata size reasonable and the display compact.
  ],
  alternatives: [
    - Don't include in metadata, parse source in CLI: more complex, duplicates work.
    - Full body in metadata: unnecessarily large for long tasks.
    - Read from source on status: slower, requires recompilation.
  ],
)

#decision(
  "Default to empty string when body is empty or unparseable",
  rationale: [
    Edge cases (empty body, content with only markup) should not crash the
    status command. An empty description is displayed as `(no description)`.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("task-metadata-includes-description", priority: "shall", action: "added", modifies: "module-api")[
  The `#task` function SHALL emit a `description` field in its metadata
  containing the first 80 characters of the task body text, serialized
  via `into_text()` (markup is preserved as raw text, not rendered).

  When the body is empty, the description SHALL be an empty string.

  #scenario("task with short description",
    when: [`#task[Implement X](done: false)`],
    then: [metadata includes `description: "Implement X"`],
  )

  #scenario("task with inline code",
    when: [`#task[Implement `typspec new`](done: false)`],
    then: [metadata includes `` description: "Implement `typspec new`" ``],
  )

  #scenario("task with long description",
    given: [task body is 200 characters long],
    when: [task is compiled],
    then: [metadata description is truncated to ~80 characters],
  )

  #scenario("task with empty body",
    when: [`#task[](done: true)`],
    then: [metadata description is `""`],
  )
]

#requirement("status-prints-task-description", priority: "shall", action: "added", modifies: "cli")[
  The `typspec status` command SHALL print the task description alongside
  the completion status.

  #scenario("status shows descriptions",
    given: [change has tasks with descriptions],
    when: [`typspec status my-change`],
    then: [output shows `[ ] Implement X` instead of `[ ] [task]`],
  )
]

= Tasks

#task_group("1. Module", (
  task([In `#task()`, serialize body to text, truncate to 80 chars, emit as `description` in metadata], done: false, labels: ("module",)),
))

#task_group("2. CLI", (
  task([Read `description` from task metadata in `cmd_status`], done: false, labels: ("cli",)),
  task([Print description alongside done status], done: false, labels: ("cli",)),
  task([Fall back to `(no description)` when empty], done: false, labels: ("cli",)),
))
