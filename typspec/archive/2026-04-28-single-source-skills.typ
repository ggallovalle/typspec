#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "single-source-skills", modifies: ("cli", "publishing"))

= Proposal

== Motivation

Skills currently exist in two places:
- `crates/cli/templates/*.md` — Tera templates embedded in the binary
- `skills/typspec/typspec-*/SKILL.md` — Canonical source for skills.sh publishing

Both must be kept in sync manually. Updating one without the other causes
drift. There should be one source of truth.

The `skills/` directory is the natural canonical source because:
1. It's what skills.sh and Claude Code plugins discover
2. The `.claude-plugin/plugin.json` references it
3. It's in the repo, versioned, and reviewable
4. The Tera templates don't actually use any template variables anymore —
   they're static markdown with no `{{ }}` placeholders

The approach: remove the Tera templates, embed the canonical `skills/`
files directly via `include_str!()` at compile time, and have
`init --tools` write them as-is (with only the version number injected
via a simple string replace).

== Scope

In scope:
- Remove `crates/cli/templates/` directory
- Remove `tera` dependency from CLI crate
- Remove Tera rendering logic from `skills.rs`
- Embed `skills/typspec/typspec-*/SKILL.md` via `include_str!()` in Rust
- Dynamic version injection: replace a `VERSION` placeholder in the YAML
  frontmatter at generation time
- `init --tools` copies from embedded skills or from `skills/` on disk

Out of scope:
- Moving `skills/` directory to a different location
- Changing the `.claude-plugin/plugin.json` format
- Adding new skills beyond the core 4

= Design

#decision(
  "Embed canonical skills via include_str!, remove Tera",
  rationale: [
    The `skills/typspec/` directory is the single source of truth. At
    compile time, `include_str!("../../skills/typspec/typspec-propose/SKILL.md")`
    embeds each file directly. No template engine needed since the content
    is static markdown. The only dynamic part is the version number in
    the YAML frontmatter, handled by a simple string replace of a
    `VERSION` marker in the YAML `generatedBy` field.
  ],
  alternatives: [
    - Keep Tera: two sources of truth, need to sync.
    - build.rs generates Rust code from skills/: extra build step for no clear gain.
    - Read from skills/ at runtime: depends on CWD being the repo root.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("single-source-skills", priority: "shall", action: "added", modifies: "cli")[
  Skill templates SHALL be sourced from the canonical `skills/typspec/`
  directory only. The `crates/cli/templates/` directory and `tera`
  dependency SHALL be removed.

  At compile time, each `SKILL.md` file from `skills/typspec/` SHALL be
  embedded via `include_str!()`. The YAML `metadata.generatedBy` field
  SHALL contain a `VERSION` marker that gets replaced with the crate
  version at generation time.

  #scenario("tera removed",
    when: [crate compiles],
    then: [no `tera` dependency, no `templates/` directory],
  )

  #scenario("skills embedded",
    when: [CLI runs `init --tools`],
    then: [skills written from embedded source, match `skills/` canonical forms],
  )

  #scenario("version injected",
    when: [skill is generated],
    then: [`metadata.generatedBy` matches the CLI version, not hardcoded],
  )
]

== REMOVED Requirements

#requirement("tera-templates", action: "removed", modifies: "cli")[
  The Tera template system for skills SHALL be removed. Templates were
  previously at `crates/cli/templates/*.md` and rendered with Tera.
]

= Tasks

#task_group("1. Remove Tera", (
  task([Remove `tera` dependency from Cargo.toml], done: true, labels: ("cli",)),
  task([Delete `crates/cli/templates/` directory], done: true, labels: ("cli",)),
))

#task_group("2. Embed Canonical Skills", (
  task([Replace Tera rendering with `include_str!()` for each of the 4 skills], done: true, labels: ("cli",)),
  task([Add VERSION placeholder to YAML frontmatter in canonical skills], done: true, labels: ("docs",)),
  task([Inject version via simple string replace in generate_skills()], done: true, labels: ("cli",)),
  task([Remove tera::Context and tera::Tera usage from skills.rs], done: true, labels: ("cli",)),
))

#task_group("3. Verify", (
  task([Run `typspec init --tools opencode`, verify skills match canonical], done: true, labels: ("tests",)),
  task([Run `cargo build` with no warnings], done: true, labels: ("tests",)),
))
