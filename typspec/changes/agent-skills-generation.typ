#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "agent-skills-generation", modifies: ("cli", "config"))

= Proposal

== Motivation

typspec needs AI agent skills so users can do the full typspec workflow:
propose, explore, apply, archive — all through natural language commands
in their AI coding assistant (Claude Code, CodEX, OpenCode).

Skills are *markdown* files (not Typst) because that's what AI agents
understand. They contain instructions + YAML frontmatter that tell the AI
how to invoke the `typspec` CLI.

Generation happens via `typspec init --tools <tool1,tool2,...>` using
Tera templates. This is heavily inspired by OpenSpec's `openspec init`
flow, adapted for the typspec CLI and conventions.

== Scope

In scope:
- `typspec init --tools claude,codex,opencode` generates skill files
- Three supported tools: `claude`, `codex`, `opencode`
- Extensible via `Tools` enum + registry pattern for future contributors
- Skills: `typspec-propose`, `typspec-explore`, `typspec-apply`, `typspec-archive`
- Templates rendered with Tera, shipped as embedded strings in binary
- Skills reference `typspec` CLI commands (`list`, `status`, `new`, `archive`, etc.)
- Skill generation respects configured paths from typspec.jsonc

Out of scope:
- Command files / slash-command adapters (skills-only delivery for now)
- Interactive prompts (non-interactive `--tools` flag only for MVP)
- All 12+ OpenSpec workflows (just the core 4: propose, explore, apply, archive)
- OpenSpec's delivery modes (`both`, `commands`, `skills`) — skills-only for now

= Design

#decision(
  "Skills are markdown, generated via Tera templates embedded in the CLI binary",
  rationale: [
    AI agents consume markdown files, not Typst. Tera is the designated
    templating engine, and templates are embedded via `include_str!` or
    the `rust-embed` crate — no external template files at runtime.
  ],
  alternatives: [
    - Ship templates as files in `templates/` dir: requires install step.
    - Generate skills as Typst: agents don't read Typst.
  ],
)

#decision(
  "Core 4 workflows only: propose, explore, apply, archive",
  rationale: [
    Matches the `core` profile from OpenSpec and the commands currently
    implemented in the CLI. Keeps the MVP focused. Additional workflows
    (verify, sync, etc.) can be added as templates later.
  ],
  alternatives: [
    - All OpenSpec workflows: too many, half rely on features CLI doesn't have.
    - Just propose + apply: too minimal, explore and archive are key.
  ],
)

#decision(
  "Tool config via CLI flags and typspec.jsonc, not interactive prompts",
  rationale: [
    Motivational use case is `mise run typspec -- init --tools claude,codex,opencode`.
    No inquirer dependency, no interactive TUI. Future interactive init can
    build on this non-interactive foundation.
  ],
  alternatives: [
    - Interactive prompts: complex, needs inquirer-like crate.
    - No tool config: auto-detect installed tools.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("init-tools-flag", priority: "shall", action: "added", modifies: "cli")[
  The `typspec init` command SHALL accept a `--tools` flag that accepts
  a comma-separated list of AI tool IDs. Supported tool IDs for the MVP:
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

#requirement("skill-templates", priority: "shall", action: "added", modifies: "cli")[
  Skill templates SHALL be Tera templates embedded in the CLI binary.

  Each template SHALL generate a `SKILL.md` file in the tool's skills
  directory (e.g., `.claude/skills/typspec-propose/SKILL.md`).

  Templates SHALL reference the `typspec` CLI for all operations.

  The following skills SHALL be generated for each selected tool:

  - `typspec-propose` — guides the AI through creating a change document
  - `typspec-explore` — explore mode for thinking through ideas
  - `typspec-apply` — implement tasks from a change
  - `typspec-archive` — archive a completed change

  Each skill SHALL include YAML frontmatter with:
  - `name`: the skill name
  - `description`: what the skill does
  - `compatibility`: requires typspec CLI

  #scenario("skill file structure",
    given: [tool `claude` is selected],
    when: [init generates skills],
    then: [
      `.claude/skills/typspec-propose/SKILL.md` exists,
      `.claude/skills/typspec-explore/SKILL.md` exists,
      `.claude/skills/typspec-apply/SKILL.md` exists,
      `.claude/skills/typspec-archive/SKILL.md` exists,
    ],
  )

  #scenario("skill content references typspec CLI",
    given: [a generated SKILL.md file],
    when: [AI reads it],
    then: [it references `typspec list`, `typspec new`, `typspec status`, etc.],
  )
]

#requirement("tool-directory-mapping", priority: "shall", action: "added", modifies: "config")[
  Each supported tool SHALL have a known skills directory path:

  | Tool      | Skills dir                 | Reason                         |
  |-----------|----------------------------|--------------------------------|
  | `claude`  | `.claude/skills/`          | Claude Code convention         |
  | `codex`   | `.agents/skills/`          | Standard AI skills directory   |
  | `opencode`| `.agents/skills/`          | Standard AI skills directory   |

  The mapping SHALL be defined in Rust code via a `Tool` enum and registry.
  Adding a new tool only requires adding a new variant and its skills dir.

  #scenario("new tool added",
    when: [a contributor adds a new variant to the Tool enum],
    then: [no other code changes needed — template rendering is generic],
  )
]

#requirement("attribution-comment", priority: "should", action: "added", modifies: "cli")[
  Each generated SKILL.md file SHALL contain an attribution comment at the
  top indicating it was generated by typspec and inspired by OpenSpec:

  ```
  // Generated by typspec (https://github.com/ggallovalle/typspec)
  // Inspired by OpenSpec (https://github.com/Fission-AI/OpenSpec)
  ```

  This comment SHALL NOT appear in the rendered skill content visible to
  the AI — it SHALL be a markdown HTML comment (`<!-- ... -->`) so it's
  invisible when rendered.

  #scenario("attribution present",
    given: [a generated SKILL.md file],
    when: [inspecting the file source],
    then: [top of file contains `<!-- Generated by typspec...`],
  )
]

#requirement("mermaid-diagrams", priority: "should", action: "added", modifies: "cli")[
  The `typspec-propose` and `typspec-explore` skill templates SHALL
  prefer Mermaid diagram syntax over ASCII art for structured diagrams
  (flowcharts, sequence diagrams, state machines).

  ASCII art is acceptable when the concept doesn't map to a standard
  Mermaid diagram type.

  #scenario("propose uses mermaid",
    given: [the propose skill describes a workflow],
    when: [rendering a flow],
    then: [uses ```mermaid flowchart LR ...``` instead of ASCII arrows],
  )

  #scenario("fallback to ascii",
    given: [a concept with no Mermaid equivalent],
    when: [rendering],
    then: [uses ASCII art as fallback],
  )
]

= Tasks

#task_group("1. Dependencies", (
  task([Add `tera` and `serde` deps to CLI crate], done: false, labels: ("cli",)),
))

#task_group("2. Tool Registry", (
  task([Define `Tool` enum with Claude, Codex, OpenCode variants + skills_dir() method], done: false, labels: ("cli",)),
  task([Add `--tools` flag parser to Init command: parse comma-separated, validate, resolve "all"/"none"], done: false, labels: ("cli",)),
  task([Add tool directory detection: check if target tool config dir exists in project], done: false, labels: ("cli",)),
))

#task_group("3. Tera Templates", (
  task([Write typspec-propose template (Tera, embedded)], done: false, labels: ("cli",)),
  task([Write typspec-explore template (Tera, embedded)], done: false, labels: ("cli",)),
  task([Write typspec-apply template (Tera, embedded)], done: false, labels: ("cli",)),
  task([Write typspec-archive template (Tera, embedded)], done: false, labels: ("cli",)),
  task([Wire Tera engine + render function in CLI], done: false, labels: ("cli",)),
))

#task_group("4. Init Command", (
  task([In `cmd_init`, handle `--tools` flag and generate skills for each selected tool], done: false, labels: ("cli",)),
  task([Create skill directories and write SKILL.md files], done: false, labels: ("cli",)),
  task([Print summary of generated skills on success], done: false, labels: ("cli",)),
))

#task_group("5. Self-test", (
  task([Run `typspec init --tools codex` in a temp dir, verify skills generated], done: false, labels: ("tests",)),
  task([Run `typspec init --tools none` — verify no skills dirs created], done: false, labels: ("tests",)),
  task([Run `typspec init --tools invalid` — verify error + tool list], done: false, labels: ("tests",)),
))
