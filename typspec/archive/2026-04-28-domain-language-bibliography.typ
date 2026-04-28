#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "domain-language-bibliography", modifies: ("module-api", "core", "cli"))

= Proposal

== Motivation

The codebase references "Levenshtein distance with ~67% threshold" in
multiple places — specs, change documents, CLI code, and skill templates.
Each reference describes the algorithm inline. A canonical bibliography
entry at `typspec/bibliographies/domain-language.yaml` provides a single
source of truth, referenced as `@damlev`.

Additionally, the hand-rolled Levenshtein in `fuzzy.rs` should be replaced
with `strsim::damerau_levenshtein`, which handles transpositions (a common
typo pattern) and is better tested.

== Scope

In scope:
- Create `typspec/bibliographies/domain-language.yaml` with `damlev` entry
- Add `strsim` dependency, replace `levenshtein()` with `damerau_levenshtein()`
- Update all doc comments and scenarios to use `@damlev`
- Update all archived change documents and spec documents to reference `@damlev`

Out of scope:
- Other bibliography entries (future)
- Auto-loading bibliographies (template uses `#bibliography()` directly)

= Design

#decision(
  "domain-language.yaml in typspec/bibliographies/, included via #bibliography",
  rationale: [
    The canonical structure puts bibliography files in `typspec/bibliographies/`.
    Documents include them via Typst's native `#bibliography()` function at the
    end of the file. The CLI passes `--root` to the project root so the path
    `typspec/bibliographies/domain-language.yaml` resolves correctly.
  ],
  alternatives: [
    - Config field: removed in canonical-typspec-directory change.
    - Template parameter: removed in canonical-typspec-directory change.
  ],
)

#decision(
  "Replace hand-rolled Levenshtein with strsim::damerau_levenshtein",
  rationale: [
    `strsim` handles transpositions (e.g., "levenshtein" ↔ "levensthein")
    which the current implementation misses. Drop-in replacement with
    identical API, better accuracy. Threshold stays at ~67%.
  ],
  alternatives: [
    - Keep hand-rolled: works but misses transpositions.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("domain-language-file", priority: "shall", action: "added", modifies: "config")[
  A `typspec/bibliographies/domain-language.yaml` file SHALL exist containing
  the canonical `damlev` entry referencing Damerau-Levenshtein distance.

  ```yaml
  damlev:
    type: misc
    title: Damerau-Levenshtein Distance
    description: >
      String metric for measuring edit distance between two sequences...
    url: https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance
    serial-number:
      doi: "10.1145/363347.363387"
  ```

  #scenario("damlev entry exists",
    when: [file is loaded],
    then: [`damlev` key present with title, description, url, doi],
  )
]

== MODIFIED Requirements

#requirement("levenshtein-fn", action: "modified", modifies: "core")[
  The `levenshtein()` function in `fuzzy.rs` SHALL be replaced with
  `strsim::damerau_levenshtein()`. All doc comments and scenarios
  referencing the algorithm SHALL use `@damlev`.
]

= Tasks

#task_group("1. Bibliography File", (
  task([Create `typspec/bibliographies/domain-language.yaml` with damlev entry], done: false, labels: ("docs",)),
))

#task_group("2. Core Library", (
  task([Add `strsim` dependency, replace levenshtein() with damerau_levenshtein()], done: false, labels: ("core",)),
  task([Add `@damlev` reference in doc comments], done: false, labels: ("core",)),
))

#task_group("3. Documentation References", (
  task([Update module-api spec scenarios to reference \@damlev], done: true, labels: ("docs",)),
  task([Update CLI spec scenarios to reference \@damlev], done: true, labels: ("docs",)),
  task([Update config spec scenarios to reference \@damlev], done: true, labels: ("docs",)),
  task([Update skill templates to reference \@damlev], done: false, labels: ("docs",)),
  task([Update all archived changes that mention Levenshtein to use \@damlev], done: false, labels: ("docs",)),
))
