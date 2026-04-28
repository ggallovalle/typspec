#import "../src/lib.typ": spec, requirement, scenario, decision

#show: spec.with(title: "Typspec Module API")

= Typspec Module API Specification

This document specifies the public API of the `@preview/typspec` Typst module.

== Document Templates

=== spec Document Template

#requirement("spec-template", priority: "shall")[
  The `spec` function SHALL serve as a document-level show rule for specification documents.

  When applied via `#show: spec.with(title: ...)`, it SHALL:
  - Set up page layout and typography appropriate for a specification document.
  - Collect all `#requirement` and `#scenario` metadata into a structured index.

  Bibliography files SHALL be placed in `typspec/bibliographies/` and included
  via Typst's native `#bibliography()` function at the end of the document.

  #scenario("spec with title only",
    when: [`#show: spec.with(title: [My Spec])`],
    then: [document title set, requirements render with proper hierarchy],
  )

  #scenario("bibliography included directly",
    given: [`typspec/bibliographies/refs.yaml` exists],
    when: [user adds `#bibliography("typspec/bibliographies/refs.yaml")` at end of document],
    then: [citations resolve, CLI passes `--root` to project root so path resolves],
  )
]

=== change Document Template

#requirement("change-template", priority: "shall")[
  The `change` function SHALL serve as a document-level show rule for change documents.

  When applied via `#show: change.with(id: ..., modifies: ...)`, it SHALL:
  - Render a document with sections for proposal, design, spec-delta, and tasks.
  - Emit metadata for all contained requirements, decisions, and tasks.

  #scenario("change with id and modifies",
    when: [`#show: change.with(id: "my-change", modifies: ("module-api",))`],
    then: [document identified as "my-change", spec-deltas target "module-api"],
  )
]

== Requirement

#requirement("requirement-fn", priority: "shall")[
  The `requirement` function SHALL define a single requirement with a unique ID.

  It SHALL accept:
  - `id` (positional, string) — unique identifier.
  - `priority` (named, string) — RFC 2119 keyword: `"shall"`, `"shall not"`, `"should"`, `"should not"`, `"may"`, `"optional"`. Default `"shall"`.
  - `action` (named, string, optional) — one of `"added"`, `"modified"`, `"removed"`. Used in spec-deltas within changes.
  - Body (positional, content) — the requirement text containing nested `#scenario` calls.

  It SHALL emit a metadata element with kind `"typspec:requirement"` containing `id`, `priority`, and `action`.

  #scenario("requirement with all parameters",
    when: [`#requirement("my-id", priority: "shall", action: "added")[text #scenario(...)]`],
    then: [metadata emitted with id, priority, action, and scenario count],
  )

  #scenario("requirement without action",
    when: [`#requirement("my-id", priority: "must")[text]`],
    then: [metadata emitted with action field as `none`],
  )
]

== Scenario

#requirement("scenario-fn", priority: "shall")[
  The `scenario` function SHALL define a single testable scenario within a requirement.

  It SHALL accept:
  - `name` (positional, string) — short description.
  - `when` (named, content) — action or condition.
  - `then` (named, content) — expected outcome.
  - `given` (named, content, optional) — preconditions.

  #scenario("scenario with given, when, then",
    when: [`#scenario("my-s", given: [precondition], when: [action], then: [result])`],
    then: [scenario renders with all three fields],
  )

  #scenario("scenario without given",
    when: [`#scenario("my-s", when: [action], then: [result])`],
    then: [scenario renders with when and then only],
  )
]

== Decision

#requirement("decision-fn", priority: "shall")[
  The `decision` function SHALL capture a design decision with rationale and alternatives.

  It SHALL accept:
  - `title` (positional, string) — the decision being made.
  - `rationale` (named, content) — why.
  - `alternatives` (named, content, optional) — other options considered.

  #scenario("decision with alternatives",
    when: [`#decision("Title", rationale: [...], alternatives: [...])`],
    then: [renders with title, rationale, and alternatives],
  )
]

== Task and Task Group

#requirement("task-fn", priority: "shall")[
  The `task` function SHALL define a single actionable item with:
  - Body (positional, content) — free-form description with inline code and links.
  - `done` (named, bool, optional) — completion status. Default: `false`.
  - `assignee` (named, string, optional) — responsible party. Any identifier.
  - `labels` (named, array of strings, optional) — free-form tags for filtering.
  - `refs` (named, array of strings, optional) — external reference URLs or IDs.

  The `task_group` function SHALL group related tasks.

  It SHALL emit metadata with kind `"typspec:task"` containing `done`, `assignee`, `labels`, `refs`.

  #scenario("incomplete task",
    when: [`#task[Implement X](done: false)`],
    then: [renders unchecked, metadata has `done: false`],
  )

  #scenario("completed task",
    when: [`#task[Implement X](done: true)`],
    then: [renders checked, metadata has `done: true`],
  )
]
#requirement("requirement-modifies-param", priority: "shall")[
The `#requirement` function SHALL accept an optional `modifies` named
  parameter that accepts a string (the spec name this requirement targets).

  When `modifies` is set, the requirement only applies to that spec during
  archive. When omitted, the requirement applies to the change's target spec
  ONLY if the change modifies a single spec. If the change modifies multiple
  specs, `modifies` is required on each requirement.

  The metadata emitted SHALL include a `modifies` field with the target
  spec name, or `none` when omitted.

  #scenario("requirement targets a spec",
    when: [`#requirement("id", modifies: "cli", action: "added")[...]`],
    then: [metadata includes `modifies: "cli"`, archive routes to cli.typ only],
  )

  #scenario("omitted is valid when change modifies one spec",
    given: [change modifies ("cli",)],
    when: [`#requirement("id", action: "added")[...]`],
    then: [applies to cli.typ],
  )

  #scenario("omitted errors when change modifies multiple specs",
    given: [change modifies ("cli", "config")],
    when: [`#requirement("id", action: "added")[...]`],
    then: [error: "modifies required — change targets multiple specs"],
  )
]
#requirement("requirement-modifies-param", priority: "shall")[
The `#requirement` function SHALL accept an optional `modifies` named
  parameter that accepts a string (the spec name this requirement targets).

  When `modifies` is set, the requirement only applies to that spec during
  archive. When omitted, the requirement applies to the change's target spec
  ONLY if the change modifies a single spec. If the change modifies multiple
  specs, `modifies` is required on each requirement.

  The metadata emitted SHALL include a `modifies` field with the target
  spec name, or `none` when omitted.

  #scenario("requirement targets a spec",
    when: [`#requirement("id", modifies: "cli", action: "added")[...]`],
    then: [metadata includes `modifies: "cli"`, archive routes to cli.typ only],
  )

  #scenario("omitted is valid when change modifies one spec",
    given: [change modifies ("cli",)],
    when: [`#requirement("id", action: "added")[...]`],
    then: [applies to cli.typ],
  )

  #scenario("omitted errors when change modifies multiple specs",
    given: [change modifies ("cli", "config")],
    when: [`#requirement("id", action: "added")[...]`],
    then: [error: "modifies required — change targets multiple specs"],
  )
]
