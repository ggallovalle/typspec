#set document(title: "Typspec Module API", author: "Gerson Gallo")

= Typspec Module API Specification

This document specifies the public API of the `@preview/typspec` Typst module.

== Document Templates

=== spec Document Template

The `spec` function SHALL serve as a document-level show rule for specification documents.

When applied via `#show: spec.with(title: ..., bibliography: ...)`, it SHALL:
- Set up page layout and typography appropriate for a specification document.
- Configure bibliography rendering from Hayagriva `.yaml` files (see [Hayagriva File Format](https://github.com/typst/hayagriva/blob/main/docs/file-format.md)).
- Collect all `#requirement` and `#scenario` metadata into a structured index.

The `bibliography` parameter passes through directly to Typst's native
`#bibliography()` function, which uses the Hayagriva YAML format. The
citation style is set internally by the template — users just provide
the bibliography source:

```
#show: spec.with(
  title: [My Spec],
  bibliography: "refs.yaml",
)
```

==== Scenario: spec with title only

- WHEN user writes `#show: spec.with(title: [My Spec])`
- THEN the document title is set to "My Spec"
- AND requirements render with proper heading hierarchy

==== Scenario: spec with title and bibliography

- WHEN user writes `#show: spec.with(title: [My Spec], bibliography: "refs.yaml")`
- THEN the bibliography is sourced from Hayagriva YAML in `refs.yaml`
- AND `@key` citations resolve correctly

==== Scenario: multiple bibliographies

- WHEN user provides `bibliography: ("refs.yaml", "extra.yaml")`
- THEN all provided Hayagriva files are loaded and available for citation

=== change Document Template

The `change` function SHALL serve as a document-level show rule for change documents.

When applied via `#show: change.with(id: ..., modifies: ...)`, it SHALL:
- Render a document with sections for proposal, design, spec-delta, and tasks.
- Emit metadata for all contained requirements, decisions, and tasks.

==== Scenario: change with id and modifies

- WHEN user writes `#show: change.with(id: "my-change", modifies: ("module-api"))`
- THEN the document is identified as "my-change"
- AND the spec-deltas target the "module-api" spec

== Requirement

The `requirement` function SHALL define a single requirement with a unique ID.

```
#requirement("ctx-expect", priority: "shall")[
  The system SHALL provide `expect(value, msg?)`.

  #scenario("with value only",
    when: [`ctx.expect(someValue)`],
    then: [expect object returned],
  )
]
```

=== Parameters

- `id` (positional, string) — unique identifier for the requirement.
- `priority` (named, string) — one of the RFC 2119 keywords: `"shall"`, `"shall not"`, `"should"`, `"should not"`, `"may"`, `"optional"`. Maps to the uppercase RFC equivalents (SHALL, MUST, SHOULD, etc.). Default `"shall"`.

  See [RFC 2119 — Key words for use in RFCs to Indicate Requirement Levels](https://datatracker.ietf.org/doc/html/rfc2119).
- `action` (named, string, optional) — one of `"added"`, `"modified"`, `"removed"`. Used in spec-deltas within changes. Default: none (active requirement).
- Body (positional, content) — the requirement text containing nested `#scenario` calls.

=== Metadata Emission

Each `#requirement` call SHALL emit a metadata element with kind `"typspec:requirement"` containing:
- `id`: the requirement ID
- `priority`: the priority value
- `action`: the action value (if present)
- `scenario_count`: number of nested scenarios

==== Scenario: requirement with all parameters

- WHEN user writes `#requirement("my-id", priority: "shall", action: "added")[text #scenario(...)]`
- THEN a metadata element is emitted with `id: "my-id"`, `priority: "shall"`, `action: "added"`
- AND the scenario count is 1

==== Scenario: requirement without action

- WHEN user writes `#requirement("my-id", priority: "must")[text]`
- THEN a metadata element is emitted
- AND the `action` field is `none`

==== Scenario: requirement with no scenarios

- WHEN user writes `#requirement("my-id")[text]`
- THEN the metadata has `scenario_count: 0`

== Scenario

The `scenario` function SHALL define a single testable scenario within a requirement.

```
#scenario("with value only",
  when: [`ctx.expect(someValue)`],
  then: [expect object returned],
)
```

=== Parameters

- `name` (positional, string) — a short description of the scenario.
- `when` (named, content) — describes the action or condition.
- `then` (named, content) — describes the expected outcome.
- `given` (named, content, optional) — describes preconditions.

==== Scenario: scenario with given, when, then

- WHEN user writes `#scenario("my-scenario", given: [precondition], when: [action], then: [result])`
- THEN the scenario renders with all three fields displayed

==== Scenario: scenario without given

- WHEN user writes `#scenario("my-scenario", when: [action], then: [result])`
- THEN the scenario renders with when and then only

== Decision

The `decision` function SHALL capture a design decision with rationale and alternatives.

```
#decision(
  "Use Typst metadata for data extraction",
  rationale: [Leverages Typst's built-in query system.],
  alternatives: [
    - YAML sidecar files: dual file maintenance, can drift.
    - AST parsing: fragile, reimplements Typst logic.
  ],
)
```

=== Parameters

- `title` (positional, string) — the decision being made.
- `rationale` (named, content) — why this decision was made.
- `alternatives` (named, content, optional) — other options considered and why they were rejected.

==== Scenario: decision with alternatives

- WHEN user writes `#decision("Title", rationale: [...], alternatives: [...])`
- THEN the decision renders with title, rationale, and alternatives

==== Scenario: decision without alternatives

- WHEN user writes `#decision("Title", rationale: [...])`
- THEN the decision renders without an alternatives section

== Task and Task Group

The `task` function SHALL define a single actionable item. The `task-group` function SHALL group related tasks.

```
#task-group("CLI Core", (
  #task[Implement `typspec new`](done: false),
  #task[Implement `typspec list`](done: false, assignee: "human"),
  #task[Implement `typspec status`](
    done: false,
    assignee: "ai",
    labels: ("cli",),
  ),
))
```

=== Parameters

- Body (positional, content) — what needs to be done. Free-form content allowing inline code, emphasis, and links.
- `done` (named, bool, optional) — whether the task is complete. Default: `false`.
- `assignee` (named, string, optional) — who is responsible. Any identifier: GitHub username, person's name, `"ai"`, `"human"`, etc. No default.
- `labels` (named, array of strings, optional) — free-form tags for filtering. Example: `("cli", "tests")`.
- `refs` (named, array of strings, optional) — external reference URLs or IDs. Example: `("https://github.com/org/repo/issues/42", "JIRA-123")`.

==== Scenario: incomplete task

- WHEN user writes `#task[Implement X](done: false)`
- THEN the task renders as unchecked
- AND metadata has `done: false`

==== Scenario: completed task

- WHEN user writes `#task[Implement X](done: true)`
- THEN the task renders as checked
- AND metadata has `done: true`

