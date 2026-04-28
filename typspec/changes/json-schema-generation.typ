#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "json-schema-generation", modifies: ("config", "cli", "module-api"))

= Proposal

== Motivation

The `typspec.jsonc` config file currently has `$schema` pointing to
`https://typspec.dev/schemas/v1.json` — a URL that doesn't resolve.
Users get no editor LSP support (autocomplete, validation, hover docs)
when editing their config.

We need a real JSON Schema that:
- Lives at `assets/typspec.schema.json` in the repo
- Is reachable at the raw GitHub URL
- Reflects the actual Rust structs (source of truth)
- Has proper descriptions for every field for LSP hover

== Scope

In scope:
- Add `schemars` dependency to `crates/core`
- Derive `JsonSchema` on `TypspecConfig`, `ProjectConfig`, `WorkspaceEntry`
- Add doc comments to config structs for schema descriptions
- Add hidden `typspec schema` command outputting the JSON Schema
- Run `typspec schema > assets/typspec.schema.json` once, commit the file
- Update `typspec init` template to use the raw GitHub URL
- Update local `typspec/typspec.jsonc` to use the new URL

Out of scope:
- CI validation that schema is up to date (no CI configured yet)
- `paths` and `bibliographies` fields (not in the struct yet)
- Additional config fields beyond what the struct defines

= Design

#decision(
  "Generate schema from Rust structs via schemars",
  rationale: [
    Hand-writing a JSON Schema drifts from the code within days.
    `schemars` reads `#[derive(JsonSchema)]` and serde attributes
    (`#[serde(tag = "type")]`, `#[serde(default)]`, etc.) to
    produce a schema that exactly matches the Rust deserialization.

    Doc comments (`/// ...`) on structs and fields become `description`
    in the schema, giving users LSP hover docs in editors. No
    separate documentation to maintain.
  ],
  alternatives: [
    - Hand-write schema.json: drifts, manual updates.
    - Build script (build.rs): writes to OUT_DIR, not assets/.
    - Separate binary crate: more overhead than a hidden CLI command.
  ],
)

#decision(
  "Hidden typspec schema command to generate the file",
  rationale: [
    `typspec schema` outputs the JSON Schema to stdout, same pattern
    as `typspec usage` for the KDL spec. Run `typspec schema >
    assets/typspec.schema.json` to regenerate. The file is checked in
    so the raw GitHub URL resolves immediately.
  ],
  alternatives: [
    - Integration test that writes the file: tests shouldn't write
      to the source tree.
    - Build script: writes to OUT_DIR, not assets/.
  ],
)

#decision(
  "Schema URL points to raw GitHub",
  rationale: [
    No domain available yet. Raw GitHub URLs are stable when pinned
    to a branch.

    URL: https://raw.githubusercontent.com/ggallovalle/typspec/main/assets/typspec.schema.json

    When a release is tagged, this can be pinned to a tag instead.
  ],
  alternatives: [],
)

= Spec Deltas

== MODIFIED Requirements

#requirement("config-discovery", priority: "shall", action: "modified", modifies: "config")[
  The CLI SHALL discover config files by walking up from the current
  working directory.

  The `$schema` field in the generated config SHALL point to the raw
  GitHub URL of the schema file, not a typspec.dev domain.

  #scenario("init writes correct schema URL",
    when: [`typspec init` runs],
    then: [`$schema` in typspec.jsonc is the raw GitHub URL],
  )
]

#requirement("schema-project", priority: "shall", action: "modified", modifies: "config")[
  The `project` section SHALL define the identity of the current
  package. The JSON Schema description for each field SHALL come
  from doc comments on the Rust struct.
]

= Tasks

#task_group("1. Add schemars dependency", (
  task([Add `schemars` to crates/core/Cargo.toml with derive feature], done: true, labels: ("core",)),
))

#task_group("2. Derive JsonSchema on config types", (
  task([Derive JsonSchema on TypspecConfig, ProjectConfig, WorkspaceEntry], done: true, labels: ("core",)),
  task([Add doc comments to struct fields for LSP descriptions], done: true, labels: ("core",)),
))

#task_group("3. Add typspec schema command", (
  task([Add schema generation function in core that outputs JSON Schema], done: true, labels: ("core",)),
  task([Add hidden typspec schema subcommand to CLI, call core function], done: true, labels: ("cli",)),
  task([Update the dollar-schema URL written by typspec init to raw GitHub], done: true, labels: ("cli",)),
))

#task_group("4. Generate and verify", (
  task([Run typspec schema > assets/typspec.schema.json], done: true, labels: ("docs",)),
  task([Verify generated schema validates our typspec/typspec.jsonc], done: true, labels: ("tests",)),
  task([Run cargo build with no warnings], done: true, labels: ("tests",)),
))

#bibliography("../bibliographies/domain-language.yaml", style: "iso-690-numeric")
