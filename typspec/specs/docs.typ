#import "../src/lib.typ": spec, requirement, scenario

#show: spec.with(title: "Typspec Documentation")

= Typspec Documentation Specification

This document specifies the project documentation, covering the README
and a full documentation site similar to OpenSpec's docs structure.

= README

#requirement("readme-hero", priority: "shall")[
  The README SHALL open with a clear pitch explaining what typspec is:
  a structured specification system powered by Typst that solves the
  problems of Markdown-based spec approaches.

  It SHALL reference the motivations: frustrations with OpenSpec,
  the brokenness of Markdown for structured specs, and the discovery
  of Typst as a better foundation.

  #scenario("hero section exists",
    when: [README is opened],
    then: [first section explains the problem and typspec's approach],
  )
]

#requirement("readme-installation", priority: "shall")[
  The README SHALL document all installation methods with copy-paste
  commands: cargo install, cargo binstall, mise, build from source.

  #scenario("install methods documented",
    when: [README is examined],
    then: [all install commands present],
  )
]

#requirement("readme-quickstart", priority: "shall")[
  The README SHALL include a quickstart walkthrough of the basic
  typspec workflow: init, status, new change, archive.

  #scenario("quickstart present",
    when: [README is read],
    then: [step-by-step quickstart with commands exists],
  )
]

#requirement("readme-badges", priority: "should")[
  The README SHALL display badges for crates.io version, CI status,
  and license.

  #scenario("badges displayed",
    when: [README is rendered on GitHub],
    then: [badges visible at top],
  )
]

#requirement("readme-structure", priority: "should")[
  The README SHALL include a repository structure diagram showing the
  post-restructure layout.

  #scenario("structure diagram",
    when: [README is examined],
    then: [current repo structure documented],
  )
]

= Documentation Site

#requirement("docs-installation", priority: "shall")[
  A `docs/installation.md` SHALL exist covering all install methods
  in depth: prerequisites, each method step-by-step, verification,
  and troubleshooting.

  #scenario("installation doc",
    when: [docs/installation.md exists],
    then: [covers all install methods with troubleshooting],
  )
]

#requirement("docs-getting-started", priority: "shall")[
  A `docs/getting-started.md` SHALL walk through the complete
  typspec workflow with a concrete example, mirroring the depth of
  OpenSpec's getting-started guide.

  #scenario("getting-started doc",
    when: [docs/getting-started.md exists],
    then: [walkthrough with example init → propose → apply → archive],
  )
]

#requirement("docs-concepts", priority: "shall")[
  A `docs/concepts.md` SHALL explain the core ideas: specs, changes,
  deltas, archive, artifacts, and how they fit together. It SHALL
  include diagrams for the workflow flow.

  #scenario("concepts doc",
    when: [docs/concepts.md exists],
    then: [explains specs, changes, deltas, archive with diagrams],
  )
]

#requirement("docs-commands", priority: "shall")[
  A `docs/commands.md` SHALL document all CLI subcommands with
  arguments, flags, examples, and scenarios.

  #scenario("commands doc",
    when: [docs/commands.md exists],
    then: [every CLI subcommand documented with examples],
  )
]

#requirement("docs-workflows", priority: "shall")[
  A `docs/workflows.md` SHALL describe common patterns and when to
  use each command, similar to OpenSpec's workflows guide.

  #scenario("workflows doc",
    when: [docs/workflows.md exists],
    then: [common typspec workflows documented],
  )
]

#bibliography("../bibliographies/domain-language.yaml", style: "iso-690-numeric")
#requirement("readme-hero", priority: "shall")[
The README SHALL open with a clear pitch explaining what typspec is
  and why it exists.
]
#requirement("readme-installation", priority: "shall")[
The README SHALL document cargo install, cargo binstall, and mise
  installation methods with copy-paste commands.
]
#requirement("readme-quickstart", priority: "shall")[
The README SHALL include a quickstart walkthrough of the basic
  typspec workflow.
]
#requirement("readme-badges", priority: "shall")[
The README SHALL display crates.io, CI, and license badges.
]
#requirement("readme-structure", priority: "shall")[
The README SHALL include a repository structure diagram.
]
