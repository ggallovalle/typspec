#set document(title: "Change: Initial Implementation", author: "Gerson Gallo")

= Proposal: Initial typspec Implementation

== Motivation

typspec exists to provide a structured, Typst-native specification system with
CLI tooling for AI-assisted workflows. The initial implementation must establish
the core module functions, CLI commands, and config schema so that development
can proceed using typspec itself (dogfooding).

== Scope

In scope:
- Core Typst module functions: `spec`, `change`, `requirement`, `scenario`, `decision`, `task`, `task-group`
- CLI commands: `init`, `new`, `list`, `status`, `render`, `archive`, `validate`, `install`
- Config schema with workspaces, exports, bibliographies
- AST surgery for archive spec-delta merging
- Mise-style config discovery

Out of scope:
- Registry support (publish/install from a central registry)
- Lockfile generation
- Skills for `.agents/skills/` (separate effort)

= Design

== Decision: Metadata-Based Data Extraction

The typspec module functions SHALL emit `metadata()` elements with a `typspec:*`
kind prefix. The CLI SHALL extract structured data by compiling the `.typ` file
and querying for these metadata elements.

Rationale: This leverages Typst's built-in query system, avoiding the need for
parallel data files or custom parsers. The Typst runtime validates the document
structure, and the CLI queries the result.

Alternatives:
- YAML/JSON sidecar files: dual file maintenance, drifts over time.
- Direct AST parsing: fragile, reimplements Typst's own logic.

== Decision: AST Surgery for Archive Merging

The `typspec archive` command SHALL parse both the change file and the target
spec file into `typst_syntax::SyntaxNode` trees, traverse to find the relevant
requirement nodes by ID, and reconstruct the tree with modifications applied.

Rationale: Preserves original formatting exactly. An in-order traversal of the
SyntaxNode tree recreates source text verbatim, so the merged output retains
all whitespace, comments, and hand-crafted formatting.

== Decision: Config Discovery (Mise-Style)

The CLI SHALL walk up from the current directory, checking multiple path
conventions (`typspec.jsonc`, `typspec/config.jsonc`, `.config/typspec.jsonc`,
`.config/typspec/typspec.jsonc`) plus `.local.` overrides and
`TYPSPEC_ENV`-specific variants. Both `.json` and `.jsonc` are accepted.
Parent configs merge with child overrides. User global config at
`~/.config/typspec/` serves as base.

Rationale: No root pollution. Users can nest the config wherever fits their
project structure. Multiple packages in a monorepo each have their own config
that references each other via workspaces.

== Decision: Workspaces with Location Types

Workspace entries in `typspec.jsonc` SHALL support three location types:
`path` (local monorepo), `git` (remote repo with tag/commit), and `registry`
(future, central catalog). Each entry is a stable ID that change documents
reference in `modifies:`.

Rationale: Stable IDs decouple references from filesystem paths. Moving a
package only requires updating the workspace entry, not every change file.

== Decision: Simple Versioning via Git SHA

When archiving, the CLI SHALL compare the git SHA of the target spec at change
creation time against its current git SHA. If they differ, a conflict is
declared and the conflicting requirement is skipped.

Rationale: No semver, no lockfile, no complex dependency resolution. If nobody
touched the target spec since you started, merge is safe. If someone did, you
need to review. This defers hard versioning problems until cross-repo
publishing arises.

= Spec Deltas

== ADDED Requirements

(All requirements for the initial implementation are ADDED — see the individual
spec files for full requirement definitions.)

- module-api.typ: All requirements for `spec`, `change`, `requirement`, `scenario`,
  `decision`, `task`, `task-group` functions.
- cli.typ: All requirements for `init`, `new`, `list`, `status`, `render`,
  `archive`, `validate`, `install` commands and their flags.
- config.typ: All requirements for the `typspec.jsonc` schema including
  project, workspaces, exports, bibliographies, context.

= Tasks

== 1. Typst Module

- [x] 1.1 Implement `spec` document template with metadata emission
- [x] 1.2 Implement `change` document template with metadata emission
- [x] 1.3 Implement `requirement` function with scenario support
- [x] 1.4 Implement `scenario` function with given/when/then fields
- [x] 1.5 Implement `decision` function with rationale and alternatives
- [x] 1.6 Implement `task` function with content-block body, `done`, `assignee`, `labels`, `refs` parameters
- [x] 1.7 Implement `task-group` function
- [x] 1.8 Wire the module entrypoint in `typspec/src/lib.typ`

== 2. Core Library

- [x] 2.1 Implement config parsing (`typspec.jsonc` → struct)
- [x] 2.2 Implement config discovery (walk-up, merge, user config)
- [x] 2.3 Implement metadata querying (wrap `typst::query`)
- [x] 2.4 Implement AST surgery: find node by metadata ID
- [x] 2.5 Implement AST surgery: replace requirement node
- [x] 2.6 Implement AST surgery: insert new requirement node
- [x] 2.7 Implement AST surgery: remove requirement node
- [x] 2.8 Implement archive merge orchestration (delta processing)
- [ ] 2.9 Implement git SHA conflict detection

== 3. CLI

- [x] 3.1 Scaffold `main.rs` with clap command definitions
- [x] 3.2 Implement `init` command
- [x] 3.3 Implement `new spec` and `new change` with templates
- [x] 3.4 Implement `list` command with specs/changes filtering
- [x] 3.5 Implement `status` command with metadata display
- [x] 3.6 Implement `render` command with optional `--watch`
- [x] 3.7 Implement `archive` command with file move
- [x] 3.8 Implement `validate` command with compile check
- [ ] 3.9 Implement `install` command for git workspace dependencies
- [x] 3.10 Implement global flags: `--json`, `--dry-run`, `-v`/`-vv`/`-vvv` levels
- [x] 3.11 Implement `ls` alias for `list` command

== 4. Dogfooding

- [x] 4.1 Render all three spec files as PDFs using `typspec render`
- [ ] 4.2 Archive this change using `typspec archive initial-implementation`
- [ ] 4.3 Verify specs are merged correctly by reviewing the spec files
