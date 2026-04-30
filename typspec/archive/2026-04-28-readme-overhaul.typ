#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "readme-overhaul", modifies: ("docs",))

= Proposal

== Motivation

The README is the project's presentation card to the world. It's currently
35 lines describing an outdated crate structure — no installation
instructions, no quickstart, no explanation of why typspec exists.

A great README attracts users and makes onboarding smooth. Inspiration
from awesome-readme (github.com/matiassingers/awesome-readme).

== Scope

In scope:
- Hero section: what typspec is, why it exists (Markdown is broken,
  OpenSpec frustrations, Typst discovery)
- Installation: cargo install, cargo binstall, mise, from source
- Quickstart: init → status → change → archive walkthrough
- Badges: crates.io, CI, license
- Repository structure diagram (post-restructure)
- Links to the blog post about Markdown being broken for context

Out of scope:
- Full documentation site (future `apps/docs`)
- API docs or reference documentation

= Design

#decision(
  "README is the single docs surface for now",
  rationale: [
    No documentation site exists yet. The README serves as the
    primary entry point until apps/docs is built. Keep it
    comprehensive but not overwhelming — hero, install, quickstart,
    structure, license. Link out to external references for deeper
    context.
  ],
  alternatives: [],
)

= Spec Deltas

== ADDED Requirements

#requirement("readme-hero", priority: "shall", action: "added", modifies: "docs")[
  The README SHALL open with a clear pitch explaining what typspec is
  and why it exists.
]

#requirement("readme-installation", priority: "shall", action: "added", modifies: "docs")[
  The README SHALL document cargo install, cargo binstall, and mise
  installation methods with copy-paste commands.
]

#requirement("readme-quickstart", priority: "shall", action: "added", modifies: "docs")[
  The README SHALL include a quickstart walkthrough of the basic
  typspec workflow.
]

#requirement("readme-badges", priority: "should", action: "added", modifies: "docs")[
  The README SHALL display crates.io, CI, and license badges.
]

#requirement("readme-structure", priority: "should", action: "added", modifies: "docs")[
  The README SHALL include a repository structure diagram.
]

= Tasks

#task_group("1. Write README", (
  task([Write hero section: problem statement, typspec solution, links to inspiration], done: true, labels: ("docs",)),
  task([Write installation section: cargo install, binstall, mise, from source], done: true, labels: ("docs",)),
  task([Write quickstart section: init → status → change → archive], done: true, labels: ("docs",)),
  task([Add badges: crates.io, CI, license], done: true, labels: ("docs",)),
  task([Update repo structure diagram to match new layout], done: true, labels: ("docs",)),
))

