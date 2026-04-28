#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "archive-preserve-body", modifies: ("core", "cli"))

= Proposal

== Motivation

When the archive command processes `action: "added"` requirements, it currently
generates a TODO stub:

```
#requirement("fuzzy-name-matching", priority: "shall")[
  TODO: add description
]
```

This happens because `metadata_to_delta_ops` generates requirement source from
metadata fields only (id, priority), discarding the actual body and scenarios
from the change document. The archive should extract the full requirement text
from the change file's source and use that as the content to insert.

== Scope

In scope:
- When building `DeltaOp` for "added", extract requirement body from change file AST
- Fall back to TODO stub only if extraction fails
- Remove the TODO-template approach entirely from `metadata_to_delta_ops`

Out of scope:
- Handling nested content blocks — the body content block `[...]` is sufficient
- Modified requirements with new body text (future enhancement)

= Design

#decision(
  "Extract requirement body from change file AST",
  rationale: [
    The change file contains the full requirement with scenarios. Instead
    of discarding this and regenerating from metadata, parse the change
    file's SyntaxNode tree, find the matching FuncCall by ID, and extract
    its body content block. This preserves all formatting and scenarios.
  ],
  alternatives: [
    - Regenerate from metadata: loses all body text and scenarios as seen.
    - Store body in metadata: embeds content in metadata strings, messy.
  ],
)

#decision(
  "Extraction done in the CLI, not core library",
  rationale: [
    Core library's `metadata_to_delta_ops` doesn't have access to the
    source file. The CLI reads the change file, finds requirement nodes,
    extracts bodies, and passes full DeltaOps to the core.
    This keeps the core focused on tree manipulation.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("added-body-from-source", priority: "shall", action: "added")[
  When building `DeltaOp` for an "added" requirement, the CLI SHALL extract
  the requirement's body from the change file's source text.

  Extraction SHALL find the `#requirement("id", ...)` call in the change file
  and capture everything inside its body content block `[...]`.

  Fallback to a TODO stub only when extraction fails (e.g., the source file
  was modified after compilation).

  #scenario("body extracted from change file",
    given: [change file has `#requirement("my-id", action: "added")[actual body #scenario(...)]`],
    when: [archive processes this requirement],
    then: [target spec receives `#requirement("my-id")[actual body #scenario(...)]`],
  )

  #scenario("fallback to TODO on extraction failure",
    given: [change file source cannot be read or parsed],
    when: [archive processes added requirement],
    then: [TODO stub inserted as before],
  )
]

== MODIFIED Requirements

#requirement("added-body-from-source", action: "modified")[
  `metadata_to_delta_ops` SHALL accept an optional `content` parameter for
  "added" requirements. When provided, that content is used instead of
  generating a TODO stub. The function no longer generates TODO stubs itself.
]

= Tasks

#task_group("1. Core Library", (
  task([Remove TODO generation from `metadata_to_delta_ops` for Added — accept content from caller], done: false, labels: ("core",)),
))

#task_group("2. CLI Archive Command", (
  task([Read change file source text], done: false, labels: ("cli",)),
  task([Find `#requirement("id", ...)` FuncCall nodes in change file AST by ID], done: false, labels: ("cli",)),
  task([Extract body content block `[...]` from matched node], done: false, labels: ("cli",)),
  task([Pass extracted body as DeltaOp content instead of TODO stub], done: false, labels: ("cli",)),
  task([Fall back to TODO if extraction fails], done: false, labels: ("cli",)),
))
