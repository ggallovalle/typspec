#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "docs-site", modifies: ("docs",))

= Proposal

== Motivation

The `docs.typ` spec defines requirements for a full documentation site
(installation guide, getting-started tutorial, concepts, commands, and
workflows) modeled after OpenSpec's docs structure. These requirements
were written into the spec but not yet implemented.

== Scope

In scope:
- `docs/installation.md` — install methods, prerequisites, troubleshooting
- `docs/getting-started.md` — concrete walkthrough with example
- `docs/concepts.md` — specs, changes, deltas, archive, diagrams
- `docs/commands.md` — every CLI subcommand with examples
- `docs/workflows.md` — common patterns and when to use each command

Out of scope:
- README (already done)
- API docs or reference documentation
- `apps/docs` documentation site (future)

= Design

#decision(
  "Flat docs/ directory, one file per topic",
  rationale: [
    OpenSpec uses flat Markdown files in a `docs/` directory. This is
    simple, linkable, and works with GitHub's built-in rendering. No
    static site generator needed for now.

    Each page should match the depth and quality of OpenSpec's docs:
    - getting-started: concrete example walkthrough with file contents
      and expected output (https://github.com/Fission-AI/OpenSpec/blob/main/docs/getting-started.md)
    - concepts: philosophy, big-picture diagram, artifact flow, delta
      specs, glossary
      (https://github.com/Fission-AI/OpenSpec/blob/main/docs/concepts.md)
    - commands: every subcommand with syntax, args, examples, tips
      (https://github.com/Fission-AI/OpenSpec/blob/main/docs/commands.md)

    When `apps/docs` is built later, these files can be imported or
    cross-referenced.
  ],
  alternatives: [],
)

= Spec Deltas

== ADDED Requirements

#requirement("docs-installation", priority: "shall", action: "added", modifies: "docs")[
  Documented in `docs.typ`.
]

#requirement("docs-getting-started", priority: "shall", action: "added", modifies: "docs")[
  Documented in `docs.typ`.
]

#requirement("docs-concepts", priority: "shall", action: "added", modifies: "docs")[
  Documented in `docs.typ`.
]

#requirement("docs-commands", priority: "shall", action: "added", modifies: "docs")[
  Documented in `docs.typ`.
]

#requirement("docs-workflows", priority: "shall", action: "added", modifies: "docs")[
  Documented in `docs.typ`.
]

= Tasks

#task_group("1. Write documentation pages", (
  task([Write docs/installation.md: prerequisites, cargo/binstall/mise/source, troubleshooting], done: true, labels: ("docs",)),
  task([Write docs/getting-started.md: walkthrough with concrete example matching OpenSpec depth], done: true, labels: ("docs",)),
  task([Write docs/concepts.md: specs, changes, deltas, archive, artifacts, diagrams matching OpenSpec depth], done: true, labels: ("docs",)),
  task([Write docs/commands.md: all CLI subcommands with args, flags, examples matching OpenSpec depth], done: true, labels: ("docs",)),
  task([Write docs/workflows.md: common patterns, when to use each command], done: true, labels: ("docs",)),
))

#bibliography("../bibliographies/domain-language.yaml", style: "iso-690-numeric")
