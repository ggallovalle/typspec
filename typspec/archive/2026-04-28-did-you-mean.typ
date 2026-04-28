#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "did-you-mean", modifies: ("cli",))

= Proposal

== Motivation

When users mistype a spec or change name, the CLI returns a bare "not found"
error with no hint about what they might have meant:

```
$ typspec status customizalbs-path
error: 'customizalbs-path' not found in typspec/specs/ or typspec/changes/
```

Clap already provides "did you mean" for subcommand typos. The same algorithm
should apply to spec and change names — compute edit distance against all
available names and suggest the closest match.

== Scope

In scope:
- Add fuzzy matching to `status` command when spec/change name not found
- Add fuzzy matching to `archive` command when change name not found
- Show closest match using Levenshtein distance with a similarity threshold
- Handle the case where multiple names have equal distance (show all)

Out of scope:
- Fuzzy matching for `render` and `validate` (file paths, not logical names)
- Interactive selection — just suggest, user retypes

= Design

#decision(
  "Levenshtein distance with 67% similarity threshold (@damlev / @fuzzy-matching)",
  rationale: [
    Matches clap's own suggestion algorithm. A threshold of roughly 67% means
    "at least 2/3 of characters match" — close enough to catch typos without
    suggesting unrelated names. For example, `customizalbs-path` vs
    `customizable-paths` is ~82% similar.
  ],
  alternatives: [
    - Always suggest the closest match: can suggest wildly unrelated names.
    - Jaro-Winkler distance: better for transpositions but less standard.
    - No threshold: shows suggestions even for completely different names.
  ],
)

#decision(
  "Suggestion format matches clap's output style",
  rationale: [Consistent UX. Users already see clap's `tip: a similar subcommand exists: 'status'` for command typos. Spec/change name suggestions should look the same.],
)

= Spec Deltas

== ADDED Requirements

#requirement("fuzzy-name-matching", priority: "shall", action: "added")[
  The `status` and `archive` commands SHALL perform fuzzy matching when a
  spec or change name is not found.

  The CLI SHALL collect all available names from the appropriate directory,
  compute Levenshtein edit distance against the user's input, and display
  the closest match when the similarity exceeds approximately 67%.

  #scenario("suggests closest match on typo",
    given: [a change named `customizable-paths` exists],
    when: [user runs `typspec status customizalbs-path`],
    then: [error shows `did you mean 'customizable-paths'?`],
  )

  #scenario("no suggestion when no close match",
    given: [available names are `module-api`, `cli`, `config`],
    when: [user runs `typspec status completely-unrelated`],
    then: [error shows without any suggestion],
  )

  #scenario("multiple suggestions for equal distance",
    given: [names `add-auth` and `add-cache` both exist],
    when: [user runs `typspec status add-`],
    then: [shows both: `did you mean 'add-auth' or 'add-cache'?`],
  )

  #scenario("output format matches clap",
    when: [suggestion is shown],
    then: [format is `tip: a similar name exists: '<name>'`],
  )
]

= Tasks

#task_group("1. Core Library", (
  task([Implement Levenshtein distance function], done: true, labels: ("core",)),
  task([Implement fuzzy matcher: collect names, score, filter by threshold, pick best], done: true, labels: ("core",)),
))

#task_group("2. CLI Commands", (
  task([Add fuzzy matching to `status` command on "not found"], done: true, labels: ("cli",)),
  task([Add fuzzy matching to `archive` command on "not found"], done: true, labels: ("cli",)),
  task([Format suggestion output to match clap's style], done: true, labels: ("cli",)),
))

#task_group("3. Tests", (
  task([Test exact match returns no suggestion], done: true, labels: ("tests",)),
  task([Test obvious typo returns correct suggestion], done: true, labels: ("tests",)),
  task([Test completely unrelated name returns no suggestion], done: true, labels: ("tests",)),
))
