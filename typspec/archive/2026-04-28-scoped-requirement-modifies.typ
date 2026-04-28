#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "scoped-requirement-modifies", modifies: ("module-api", "cli"))

= Proposal

== Motivation

Currently, when a change modifies multiple specs, ALL spec-delta requirements
are applied to ALL modified specs. There's no way to say "this requirement
belongs to spec A, and this other one belongs to spec B."

```
#show: change.with(id: "my-change", modifies: ("module-api", "cli"))

#requirement("req-a", action: "added")[...]  ← belongs to which spec?
#requirement("req-b", action: "added")[...]  ← belongs to which spec?
```

The archive command has no way to route each requirement to the correct spec
file. It currently dumps all deltas into every modified spec, which duplicates
requirements across spec files.

The fix: `#requirement` should accept an optional `modifies` parameter that
names which spec this requirement targets. The archive command should use this
to route each delta to the correct spec file.

If the spec doesn't exist, error and suggest existing spec names (with the
same "did you mean" heuristic). If a requirement specifies a spec not listed
in the change's top-level `modifies`, error with a message saying it must be
declared there.

== Scope

In scope:
- Add `modifies` named parameter to `#requirement` (single string, the spec name)
- Archive routes each delta to its specified spec file only
- Validation: requirement's `modifies` must be a subset of change's `modifies`
- Error + suggestion when target spec file doesn't exist
- Error + suggestion when requirement's `modifies` isn't in change's `modifies`
- Update `modifies` metadata on `typspec:requirement` to include the target spec

Out of scope:
- Multiple specs per requirement (future, if needed)
- Per-scenario targeting

= Design

#decision(
  "Optional modifies — required when change targets multiple specs",
  rationale: [
    When omitted, the requirement applies to the change's modified spec
    ONLY if the change modifies a single spec. When the change's `modifies`
    lists more than one spec, each requirement MUST declare its target.
    This prevents ambiguous routing and makes the change document explicit.
    Existing single-spec changes are unaffected. Multi-spec archived changes
    will need a migration pass.
  ],
  alternatives: [
    - Always optional (current proposal): allows ambiguity in multi-spec changes.
    - Required on all requirements: breaks single-spec changes unnecessarily.
  ],
)

#decision(
  "Validate requirement.modifies against change.modifies at archive time",
  rationale: [
    The change file is compiled and queried for metadata at archive time.
    Cross-referencing requirement.modifies against change.modifies ensures
    the user hasn't forgotten to declare a target spec. Error message
    includes the available specs from the change's top-level modifies.
  ],
  alternatives: [
    - Validate at compile time: requires module to read the change's modifies,
      which is complex since it's in a show rule.
    - Silently add missing specs to modifications: hides mistakes.
  ],
)

#decision(
  "Error + suggest when target spec file doesn't exist",
  rationale: [
    A spec file that doesn't exist means either a typo (use did-you-mean) or
    the spec hasn't been created yet (ask user to init it). Same heuristic
    as the existing `typspec status` @fuzzy-matching.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("requirement-modifies-param", priority: "shall", action: "added", modifies: "module-api")[
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

#requirement("archive-routes-by-modifies", priority: "shall", action: "added", modifies: "cli")[
  The archive command SHALL use each requirement's `modifies` field to
  decide which spec file to apply the delta to.

  Requires are grouped by target spec, and each group is applied only to
  its corresponding spec file.

  #scenario("requirements routed to different specs",
    given: [change modifies ("cli", "config"), req-a targets "cli", req-b targets "config"],
    when: [archive runs],
    then: [req-a inserted into cli.typ only, req-b into config.typ only],
  )
]

#requirement("validation-requirement-in-change-modifies", priority: "shall", action: "added", modifies: "cli")[
  If a requirement specifies a spec in its `modifies` that is NOT listed in
  the change's top-level `modifies`, the archive SHALL produce an error
  listing the available specs from the change declaration.

  #scenario("requirement targets undeclared spec",
    given: [change modifies ("cli",), requirement modifies ("config")],
    when: [archive runs],
    then: [error: "'config' not in change modifies. Available: cli"],
  )
]

#requirement("validation-target-spec-exists", priority: "shall", action: "added", modifies: "cli")[
  If the target spec file for a requirement does not exist on disk, the
  archive SHALL error and suggest existing spec names using the "did you
  mean" Levenshtein heuristic.

  #scenario("target spec file missing",
    given: [typspec/specs/config.typ does not exist],
    when: [archive tries to apply delta to "config"],
    then: [error: "spec 'config' not found", with suggestion of closest existing spec],
  )
]

== MODIFIED Requirements

#requirement("requirement-fn", action: "modified", modifies: "module-api")[
  The `#requirement` function signature SHALL be extended with an optional
  `modifies` (string or array of strings) parameter.

  The emitted metadata kind `"typspec:requirement"` SHALL include a new
  `modifies` field.
]

= Tasks

#task_group("1. Module", (
  task([Add `modifies` parameter to `#requirement` (single string, spec name)], done: true, labels: ("module",)),
  task([Emit `modifies` field in requirement metadata (null when omitted)], done: true, labels: ("module",)),
))

#task_group("2. Core Library", (
  task([Update `metadata_to_delta_ops` to extract modifies from metadata], done: true, labels: ("core",)),
  task([Add `group_delta_ops_by_spec`: validate modifies ⊆ change modifies, target exists], done: true, labels: ("core",)),
))

#task_group("3. CLI Archive Command", (
  task([Use group_delta_ops_by_spec instead of old all-to-all logic], done: true, labels: ("cli",)),
  task([Print validation errors (missing modifies, spec not found)], done: true, labels: ("cli",)),
  task([When modifies is null and change modifies > 1 spec, error], done: true, labels: ("cli",)),
))

#task_group("4. Fix Archived Changes", (
  task([Update `initial-implementation` archived change: add `modifies` to each requirement], done: false, labels: ("migration",)),
  task([Update `archive-preserve-body` archived change: add `modifies` to each requirement], done: false, labels: ("migration",)),
  task([Verify both archived changes still compile after migration], done: false, labels: ("migration",)),
))

#task_group("5. Self-fix: This Change", (
  task([Add `modifies: "module-api"` to `#requirement` calls that target module-api], done: true, labels: ("self",)),
  task([Add `modifies: "cli"` to `#requirement` calls that target cli], done: true, labels: ("self",)),
  task([Verify this change compiles and archives clean], done: true, labels: ("self",)),
))

#task_group("6. Module API Spec Update", (
  task([Document modifies parameter on requirement], done: false, labels: ("docs",)),
))
