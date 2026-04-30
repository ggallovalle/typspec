#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group
#import "../glossary.typ"

#show: glossary.glossary

#show: change.with(id: "user-facing-skills", modifies: ("ai-skills", "cli", "config"))

= Proposal

== Motivation

The skills at `skills/typspec/` are installed in user projects via
`typspec init --tools <tool>`. They instruct AI agents how to work with
typspec — they should be generic, not typspec-repo-specific.

Currently they contain two repo-specific things:

1. Hardcoded references to `typspec/bibliographies/domain-language.yaml`
   — this file only exists in the typspec repo, not in user projects.
   `typspec init` creates an empty `bibliographies/` directory, so any AI
   following the skill's instruction to add `#bibliography("...domain-language.yaml")`
   will produce a broken document.

2. `@fuzzy-matching` and `@damlev` citations — these are typspec-repo
   domain language describing implementation details (Damerau-Levenshtein
   distance at a 67% threshold). Users don't have this vocabulary in
   their projects.

== Scope

In scope:
- Strip `domain-language.yaml`, `@fuzzy-matching`, `@damlev` from
  propose.md, archive.md, and explore.md skill files
- Replace with generic bibliography guidance:
  `#bibliography("typspec/bibliographies/<your-file>.yaml")`
- `typspec init` writes a minimal `example.yaml` to `bibliographies/`
  so the directory isn't empty and users have a reference format
- Update `ai-skills.typ` spec: remove `@fuzzy-matching` mandate from
  skill-explore requirement, keep bibliography reference generic
- Update `cli.typ` spec: remove requirements that mandate domain
  language references in skills

Out of scope:
- Removing `domain-language.yaml` from the typspec repo — the repo's
  own specs (cli.typ, etc.) still use `@fuzzy-matching` and `@damlev`
- Adding other domain-language terms to the example scaffold
- Changing how the fuzzy-matching feature works in the CLI

= Design

#decision(
  "Skills reference bibliographies generically, not by file name",
  rationale: [
    The propose and archive skills currently tell AIs to add a
    `#bibliography("typspec/bibliographies/domain-language.yaml")`
    line. This path only resolves in the typspec repo.

    Replacing with `#bibliography("typspec/bibliographies/<your-file>.yaml")`
    (using `<your-file>` as a placeholder) gives users the right guidance
    without assuming a specific file. The propose skill's step 7 changes
    from a concrete instruction to a generic example.

    The archive skill's "Bibliography references" section is removed
    entirely — referencing a specific bibliography is a concern of the
    propose workflow, not archive.
  ],
  alternatives: [
    - Keep hardcoded path, ship domain-language.yaml with init: forces
      typspec's internal jargon (damlev) on all users.
    - Remove all bibliography references from skills: users lose
      guidance on citing sources in their specs.
  ],
)

#decision(
  "Remove @fuzzy-matching and @damlev from skills",
  rationale: [
    `@fuzzy-matching` and `@damlev` are typspec-repo domain language.
    They describe how the CLI implements "did you mean" suggestions
    (Damerau-Levenshtein at 67%). Users don't have this vocabulary.

    The explore skill currently tells AIs to use `@fuzzy-matching` for
    name resolution. Instead, the skill just says "use typspec which"
    (the command itself) which is the user-facing interface. The fuzzy
    matching happens transparently in the CLI.
  ],
  alternatives: [
    - Keep @fuzzy-matching, ship domain-language.yaml with init: forces
      repo jargon on users.
    - Inline the explanation: "typspec suggests close names when no
      exact match" — adds unnecessary detail to the skill.
  ],
)

#decision(
  "typspec init writes example.yaml to bibliographies/",
  rationale: [
    Currently `typspec init` creates an empty `bibliographies/` directory.
    The skills generically reference `bibliographies/<your-file>.yaml`,
    but without any file there, users have no starting point.

  A minimal `example.yaml` gives users a concrete format to follow
  when they want to add their own bibliography terms, without
  prescribing typspec's internal domain language.

  The file SHALL start with a comment linking to the Hayagriva file
  format docs (https://github.com/typst/hayagriva/blob/main/docs/file-format.md)
  and the JSON Schema tracking issue (#33). No `$schema` directive
  is included since Hayagriva has no published JSON Schema yet.
  ],
  alternatives: [
    - Leave directory empty: users have no reference format.
    - Copy domain-language.yaml: forces repo jargon on users.
  ],
)

= Spec Deltas

== MODIFIED Requirements

#requirement("skill-explore", priority: "shall", action: "modified", modifies: "ai-skills")[
  The `typspec-explore` skill SHALL guide an AI through exploratory
  thinking. It SHALL reference:
  - `typspec list` and `typspec list --specs` to check what exists
  - `typspec which <name>` to find file locations
  - The canonical directory structure

  It SHALL emphasize: *explore mode is for thinking, not implementing*.

  The skill SHALL NOT reference `@fuzzy-matching` or any repo-specific
  domain language. The CLI handles name resolution transparently — the
  AI only needs to know `typspec which <name>`.

  #scenario("no domain language in explore",
    when: [skill file is examined],
    then: [no `@fuzzy-matching`, `@damlev`, or `domain-language.yaml` references],
  )
]

#requirement("skill-propose", priority: "shall", action: "modified", modifies: "ai-skills")[
  The `typspec-propose` skill SHALL guide an AI through creating a change
  document. It SHALL reference:
  - `typspec list` and `typspec list --specs` for discovering existing files
  - `typspec new change <name>` for creating the change file
  - `typspec validate typspec/changes/<name>.typ` for verification
  - The canonical structure: `typspec/typspec.jsonc`, `typspec/specs/`

  For bibliographies, the skill SHALL use a generic placeholder:
  `#bibliography("typspec/bibliographies/<your-file>.yaml")` — not a
  hardcoded file name.

  #scenario("bibliography ref is generic",
    when: [propose skill references bibliography],
    then: [uses `<your-file>.yaml` placeholder, not a specific file],
  )
]

#requirement("skill-archive", priority: "shall", action: "modified", modifies: "ai-skills")[
  The `typspec-archive` skill SHALL guide an AI through archiving a
  completed change. It SHALL reference:
  - `typspec status <name>` to verify task completion
  - `typspec archive <name>` to merge deltas and move to archive
  - `typspec validate typspec/specs/<spec>.typ` to verify modified specs
  - `typspec which <name>` to find archived changes later

  It SHALL NOT include a "Bibliography references" section — archive
  is not the workflow for introducing bibliography dependencies.

  #scenario("no bibliography section in archive",
    when: [archive skill file is examined],
    then: [no Bibliography references section exists],
  )
]

#requirement("skill-references-domain-language", priority: "shall", action: "removed", modifies: "cli")[
  The requirement mandating that skill templates use `@fuzzy-matching`
  (from domain-language.yaml) SHALL be removed from cli.typ.
]

#requirement("init-creates-example-bibliography", priority: "should", action: "added", modifies: "config")[
  The `typspec init` command SHOULD write a minimal `example.yaml` to
  the `bibliographies/` directory. This gives users a reference format
  for adding their own bibliography terms.

  The file SHALL contain a minimal valid example with one or two
  generic entries, NOT typspec-repo-specific terms like `damlev` or
  `fuzzy-matching`.   It SHALL start with a comment linking to the
  Hayagriva file format documentation and the JSON Schema tracking
  issue (https://github.com/typst/hayagriva/issues/33).

  #scenario("init creates example.yaml",
    when: [`typspec init` runs],
    then: [`typspec/bibliographies/example.yaml` exists with generic content and Hayagriva docs link],
  )
]

= Tasks

#task_group("1. Update skill files", (
  task([Remove @fuzzy-matching and @damlev references from propose.md], done: true, labels: ("docs",)),
  task([Replace hardcoded domain-language.yaml with generic placeholder in propose.md], done: true, labels: ("docs",)),
  task([Remove Bibliography references section from archive.md], done: true, labels: ("docs",)),
  task([Remove @fuzzy-matching reference from explore.md], done: true, labels: ("docs",)),
))

#task_group("2. Add example.yaml scaffold", (
  task([Write example.yaml to typspec/bibliographies/ with Hayagriva docs comment], done: true, labels: ("docs",)),
  task([Update cmd_init() to write example.yaml during typspec init], done: true, labels: ("cli",)),
))

#task_group("3. Update specs", (
  task([Update ai-skills.typ: skill-explore, skill-propose, skill-archive requirements], done: true, labels: ("docs",)),
  task([Remove skill-references-domain-language from cli.typ], done: true, labels: ("docs",)),
))

#task_group("4. Verify", (
  task([Run typspec init --tools opencode, verify skills have no repo-specific refs], done: true, labels: ("tests",)),
  task([Run cargo build with no warnings], done: true, labels: ("tests",)),
))


