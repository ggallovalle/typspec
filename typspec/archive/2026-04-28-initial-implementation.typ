#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "initial-implementation", title: "Initial Implementation", modifies: ("module-api", "cli", "config"))

= Proposal

== Motivation

typspec exists to provide a structured, Typst-native specification system with
CLI tooling for AI-assisted workflows. The initial implementation must establish
the core module functions, CLI commands, and config schema so that development
can proceed using typspec itself (dogfooding).

== Scope

In scope:
- Core Typst module functions: `spec`, `change`, `requirement`, `scenario`, `decision`, `task`, `task_group`
- CLI commands: `init`, `new`, `list`, `status`, `render`, `archive`, `validate`, `install`
- Config schema with workspaces, exports, bibliographies
- AST surgery for archive spec-delta merging
- Mise-style config discovery

Out of scope:
- Registry support (publish/install from a central registry)
- Lockfile generation
- Skills for `.agents/skills/` (separate effort)

== Design

#decision(
  "Metadata-Based Data Extraction",
  rationale: [Leverages Typst's built-in query system, avoiding the need for parallel data files or custom parsers. The Typst runtime validates the document structure, and the CLI queries the result.],
  alternatives: [
    - YAML/JSON sidecar files: dual file maintenance, drifts over time.
    - Direct AST parsing: fragile, reimplements Typst's own logic.
  ],
)

#decision(
  "AST Surgery for Archive Merging",
  rationale: [Preserves original formatting exactly. An in-order traversal of the SyntaxNode tree recreates source text verbatim, so the merged output retains all whitespace, comments, and hand-crafted formatting.],
)

#decision(
  "Config Discovery (Mise-Style)",
  rationale: [No root pollution. Users can nest the config wherever fits their project structure. Multiple packages in a monorepo each have their own config that references each other via workspaces.],
)

#decision(
  "Workspaces with Location Types",
  rationale: [Stable IDs decouple references from filesystem paths. Moving a package only requires updating the workspace entry, not every change file.],
)

#decision(
  "Simple Versioning via Git SHA",
  rationale: [No semver, no lockfile, no complex dependency resolution. If nobody touched the target spec since you started, merge is safe. If someone did, you need to review. This defers hard versioning problems until cross-repo publishing arises.],
)

== Spec Deltas

=== ADDED Requirements

(All requirements for the initial implementation are ADDED — see the individual
spec files for full requirement definitions.)

- module-api.typ: All requirements for `spec`, `change`, `requirement`, `scenario`, `decision`, `task`, `task_group` functions.
- cli.typ: All requirements for `init`, `new`, `list`, `status`, `render`, `archive`, `validate`, `install` commands and their flags.
- config.typ: All requirements for the `typspec.jsonc` schema including project, workspaces, exports, bibliographies, context.

== Tasks

#task_group("1. Typst Module", (
  task([Implement `spec` document template with metadata emission], done: true),
  task([Implement `change` document template with metadata emission], done: true),
  task([Implement `requirement` function with scenario support], done: true),
  task([Implement `scenario` function with given/when/then fields], done: true),
  task([Implement `decision` function with rationale and alternatives], done: true),
  task([Implement `task` function with content-block body, done, assignee, labels, refs], done: true),
  task([Implement `task_group` function], done: true),
  task([Wire the module entrypoint in `typspec/src/lib.typ`], done: true),
))

#task_group("2. Core Library", (
  task([Implement config parsing (`typspec.jsonc` → struct)], done: true),
  task([Implement config discovery (walk-up, merge, user config)], done: true),
  task([Implement metadata querying (wrap `typst::query`)], done: true),
  task([Implement AST surgery: find node by metadata ID], done: true),
  task([Implement AST surgery: replace requirement node], done: true),
  task([Implement AST surgery: insert new requirement node], done: true),
  task([Implement AST surgery: remove requirement node], done: true),
  task([Implement archive merge orchestration (delta processing)], done: true),
  task([Implement git SHA conflict detection], done: true),
))

#task_group("3. CLI", (
  task([Scaffold `main.rs` with clap command definitions], done: true),
  task([Implement `init` command], done: true),
  task([Implement `new spec` and `new change` with templates], done: true),
  task([Implement `list` command with specs/changes filtering], done: true),
  task([Implement `status` command with metadata display], done: true),
  task([Implement `render` command with optional `--watch`], done: true),
  task([Implement `archive` command], done: true),
  task([Implement `validate` command with compile check], done: true),
  task([Implement `install` command for git workspace dependencies], done: true),
  task([Implement global flags: --json, --dry-run, -v/-vv/-vvv], done: true),
  task([Implement `ls` alias for `list` command], done: true),
))

#task_group("4. Dogfooding", (
  task([Render all three spec files as PDFs using typspec render], done: true),
  task([Archive this change using typspec archive], done: true),
  task([Verify specs are merged correctly], done: true),
))
