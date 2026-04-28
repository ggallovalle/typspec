#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "domain-language-bibliography", modifies: ("module-api", "cli", "config"))

= Proposal

== Motivation

The codebase references "Levenshtein distance with ~67% threshold" in
multiple places — specs, change documents, CLI code, and skill templates.
Each reference describes the algorithm inline without a single source of
truth. If we change the algorithm (e.g., to Damerau-Levenshtein), we'd
need to update every reference.

A `domain-language.yaml` Hayagriva bibliography file solves this:
- One canonical entry for the string similarity algorithm
- Referenced via `@damlev` in specs, changes, and skill templates
- The Hayagriva YAML format supports `doi`, `url`, and structured metadata
- `typst query` can extract references from compiled documents

Additionally, the current hand-rolled Levenshtein implementation in
`fuzzy.rs` should be replaced with the `strsim` crate's Damerau-
Levenshtein implementation, which is better tested and handles
transpositions (a common typo pattern).

== Scope

In scope:
- Create `typspec/domain-language.yaml` with `damlev` entry
- Add bibliography to `spec` template and to all spec documents
- Add bibliography to all archived and future change documents
- Replace `levenshtein()` function in `fuzzy.rs` with `strsim::damerau_levenshtein()`
- Update all doc comments and scenarios that reference the algorithm
- Update skill templates to reference the bibliography entry

Out of scope:
- Adding bibliography entries for non-domain-language content
- Migrating existing `lua-ref.yaml` style (separate concern)

= Design

#decision(
  "Single domain-language.yaml in typspec/ dir, referenced by all docs",
  rationale: [
    One file is easier to maintain than a bibliography per document.
    The `bibliographies` config field in `typspec.jsonc` already supports
    multiple files. The Hayagriva format is the standard Typst bibliography
    format. The file goes in the `typspec/` directory alongside the module.
  ],
  alternatives: [
    - Inline references in each document: duplicates text, drifts over time.
    - Entry per spec file: harder to find and update the canonical reference.
  ],
)

#decision(
  "Replace hand-rolled Levenshtein with strsim::damerau_levenshtein",
  rationale: [
    `strsim` is a well-maintained Rust crate for string similarity. Its
    Damerau-Levenshtein implementation handles transpositions (e.g.,
    "levenshtein" ↔ "levensthein") which the current implementation
    does not. This is a drop-in replacement with identical API but
    better accuracy. The threshold stays at ~67%.
  ],
  alternatives: [
    - Keep hand-rolled: works but misses transpositions.
    - Use Jaro-Winkler: different distance metric, changes behavior.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("domain-language-file", priority: "shall", action: "added", modifies: "config")[
  A `domain-language.yaml` file SHALL exist in the `typspec/` directory
  containing Hayagriva-formatted bibliography entries for domain concepts.

  The first entry SHALL be `damlev` referencing the Damerau-Levenshtein
  distance algorithm:

  ```yaml
  damlev:
    type: misc
    title: Damerau-Levenshtein Distance
    description: >
      String metric for measuring edit distance between two sequences.
      An extension of Levenshtein distance that also considers
      transpositions of two adjacent characters as a single edit.
      Similarity threshold of ~67% used for fuzzy matching.
    url: https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance
    serial-number:
      doi: "10.1145/363347.363387"
  ```

  #scenario("damlev entry exists",
    when: [the file is loaded],
    then: [the `damlev` key is present with title, description, and url],
  )
]

#requirement("bibliography-in-spec-template", priority: "shall", action: "added", modifies: "module-api")[
  The `spec` document template SHALL support a `bibliography` parameter
  that accepts an array of bibliography file paths. When provided, these
  are passed to Typst's `#bibliography()` function with `style: "iso-690-numeric"`.

  The `change` template SHALL also support `bibliography` so that change
  documents can cite domain-language entries.

  #scenario("spec with bibliography",
    when: [`#show: spec.with(bibliography: "domain-language.yaml")`],
    then: [citations like `@damlev` resolve to the bibliography entry],
  )
]

== MODIFIED Requirements

#requirement("levenshtein-fn", action: "modified", modifies: "core")[
  The `levenshtein()` function in `fuzzy.rs` SHALL be replaced with
  `strsim::damerau_levenshtein()` from the `strsim` crate. The public
  API and existing tests SHALL remain compatible.

  All doc comments and scenarios referencing the algorithm SHALL use
  `@damlev` instead of inline descriptions. The ~67% threshold is
  documented in the domain-language.yaml entry, not in code.
]

#requirement("global-flags", action: "modified", modifies: "cli")[
  The `typspec status` and `typspec archive` commands SHALL reference
  `@damlev` in their "did you mean" suggestion messages, linking to
  the domain-language.yaml entry.
]

= Tasks

#task_group("1. Domain Language File", (
  task([Create `domain-language.yaml` with `damlev` entry], done: false, labels: ("docs",)),
  task([Add `domain-language.yaml` to all spec document bibliographies], done: false, labels: ("docs",)),
  task([Add `domain-language.yaml` to `change` template bibliography], done: false, labels: ("module",)),
  task([Add bibliography rendering to `change` document template], done: false, labels: ("module",)),
  task([Update all archived changes to include bibliography + \@damlev references], done: false, labels: ("docs",)),
))

#task_group("2. Core Library", (
  task([Add `strsim` dependency to core crate], done: false, labels: ("core",)),
  task([Replace `levenshtein()` with `strsim::damerau_levenshtein()`], done: false, labels: ("core",)),
  task([Update doc comments and tests to reference \@damlev], done: false, labels: ("core",)),
))

#task_group("3. Skill Templates", (
  task([Update skill templates to reference \@damlev instead of inline description], done: false, labels: ("cli",)),
))
