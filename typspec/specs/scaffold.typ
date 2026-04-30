#import "../src/lib.typ": spec, requirement, scenario
#import "../links.typ"
#import "../glossary.typ"

#show: glossary.glossary
#show: spec.with(title: "Typspec Scaffold")

= Typspec Scaffold Specification

This document specifies the behavior of the `typspec init` and
`typspec new` commands. For the command's CLI interfaces (name, args,
flags, exit codes), see #links.spec-cli.

== Initialization

#requirement("init-tools-flag", priority: "shall")[
  The `typspec init` command SHALL accept a `--tools` flag that accepts
  a comma-separated list of AI tool IDs. Supported tool IDs:
  `claude`, `codex`, `opencode`.

  Passing `--tools all` SHALL select all supported tools.
  Passing `--tools none` SHALL skip skill generation entirely.
  Passing an invalid tool ID SHALL error with available options.

  #scenario("tools with valid IDs",
    when: [`typspec init --tools claude,codex`],
    then: [skills generated for Claude and CodEX],
  )

  #scenario("tools all",
    when: [`typspec init --tools all`],
    then: [skills generated for all supported tools],
  )

  #scenario("tools none",
    when: [`typspec init --tools none`],
    then: [init runs without generating any skills],
  )

  #scenario("tools invalid ID",
    when: [`typspec init --tools invalidtool`],
    then: [error with list of valid tool IDs],
  )
]

#requirement("init-example-bibliography", priority: "should")[
  The `typspec init` command SHOULD write a minimal `example.yaml` to
  the `bibliographies/` directory. This gives users a reference format
  for adding their own bibliography terms.

  The file SHALL contain a minimal valid example with one or two
  generic entries, NOT typspec-repo-specific terms like `damlev` or
  `fuzzy-matching`. It SHALL start with a comment linking to the
  Hayagriva file format documentation.

  #scenario("init creates example.yaml",
    when: [`typspec init` runs],
    then: [`typspec/bibliographies/example.yaml` exists with generic content],
  )
]

== Skill Generation

#requirement("skill-directory-mapping", priority: "shall")[
  Each supported tool SHALL have a known skills directory path:

  | Tool      | Skills dir          |
  |-----------|---------------------|
  | `claude`  | `.claude/skills/`   |
  | `codex`   | `.agents/skills/`   |
  | `opencode`| `.agents/skills/`   |

  The mapping SHALL be defined in Rust code via a `Tool` enum and registry.
  Adding a new tool only requires adding a new variant and its skills dir.

  #scenario("new tool added",
    when: [a contributor adds a new variant to the Tool enum],
    then: [no other code changes needed — template rendering is generic],
  )
]

