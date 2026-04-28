<div align="center">

# typspec

**Structured specifications powered by Typst.**

[![Crates.io](https://img.shields.io/crates/v/typspec)](https://crates.io/crates/typspec)
[![CI](https://img.shields.io/github/actions/workflow/status/ggallovalle/typspec/ci.yml?branch=main)](https://github.com/ggallovalle/typspec/actions)
[![License](https://img.shields.io/github/license/ggallovalle/typspec)](LICENSE)

Define, manage, and render software specifications as beautiful PDFs — with AI-assisted workflows.

</div>

---

## Why typspec?

Specifications should be precise, renderable, and machine-readable. Markdown
falls short on all three:

- **Ambiguous syntax** — bold, italic, and nested formatting have multiple
  valid interpretations ([CommonMark helps, but the language itself is
  broken](https://bgslabs.org/blog/why-are-we-using-markdown/))
- **No structured data** — requirements, scenarios, and decisions blur
  into freeform prose
- **Poor rendering** — Markdown-to-PDF pipelines are fragile and inconsistent
- **No built-in change management** — tracking what changed and why is manual

typspec solves this with [Typst](https://typst.app/), a modern typesetting
language that gives you deterministic rendering, structured markup, and
first-class PDF output.

### Inspiration

typspec was inspired by [OpenSpec](https://openspec.dev/) — which pioneered
AI-assisted specification workflows — and built on the realization that
Typst eliminates the core problems of Markdown-based spec systems.

---

## Installation

### cargo install

```bash
cargo install typspec
```

### cargo binstall

Requires [`cargo-binstall`](https://github.com/cargo-bins/cargo-binstall).

```bash
cargo binstall typspec
```

### mise

```bash
mise use cargo:typspec
# or with pre-built binaries:
mise use cargo-binstall:typspec
```

### Build from source

```bash
git clone https://github.com/ggallovalle/typspec
cd typspec
cargo build --release
./target/release/typspec --help
```

---

## Quickstart

### Initialize a project

```bash
typspec init
```

Creates the standard layout:

```
typspec/
├── specs/           # Specification files (.typ)
├── changes/         # Active change documents
├── archive/         # Archived changes
└── bibliographies/  # Hayagriva bibliography files
```

### See what exists

```bash
typspec list --specs
```

After init, the specs directory is empty. Specs and changes are created
as you work.

### Your first change

Let's walk through a real change — adding a `/health` endpoint to an API.

**1. Start the change**

```bash
typspec new change add-health-endpoint
```

This creates `typspec/changes/add-health-endpoint.typ` — a single
document with all the sections you need:

```typst
#show: change.with(id: "add-health-endpoint")

= Proposal

== Motivation

Why is this change needed?

== Scope

What is and isn't changing.

= Design

#decision("Title", rationale: [Why this approach.])

= Spec Deltas

#requirement("health-endpoint", priority: "shall", action: "added")[
  The system SHALL expose a GET /health endpoint.

  #scenario("returns ok",
    when: [service is running],
    then: [200 OK with `{"status": "ok"}`],
  )
]

= Tasks

#task_group("Implementation", (
  task([Add /health route to the router], done: false),
  task([Write integration test for health check], done: false),
))
```

**2. Fill in the details**

Edit the file to add your motivation, design decisions, and requirements.
The `#requirement()` blocks use structured fields that the CLI can query.

**3. Validate as you go**

```bash
typspec validate typspec/changes/add-health-endpoint.typ
```

Compiles the document and checks for errors. The CLI uses Typst under
the hood, so you get real language-level validation.

**4. Render to PDF (optional)**

```bash
typspec render typspec/changes/add-health-endpoint.typ
typspec render typspec/specs/module-api.typ
```

Generates a PDF alongside the `.typ` file — useful for reviews or
documentation.

**5. Track progress**

```bash
typspec status add-health-endpoint
```

Shows requirements, scenarios, decisions, and task completion:

```
Status: add-health-endpoint
  Requirements: 1
  Scenarios: 1
  Tasks: 1/2 complete

  [dec] Title
  [req] health-endpoint (added)
  [x] Add /health route to the router
  [ ] Write integration test for health check
```

**6. Archive when done**

```bash
typspec archive add-health-endpoint
```

Merges the spec-deltas into the target specs and moves the change to
`typspec/archive/2026-04-28-add-health-endpoint.typ` for audit history.

### AI-assisted workflow

typspec ships with agent skills for AI coding tools:

```bash
typspec init --tools opencode
```

This installs skills under `.agents/skills/` that guide AI assistants
through the full workflow:

| Skill | Slash command | What it does |
|-------|--------------|--------------|
| `typspec-propose` | `/typspec-propose` | Scopes and scaffolds a change |
| `typspec-explore` | `/typspec-explore` | Investigates before committing |
| `typspec-apply` | `/typspec-apply` | Implements tasks from a change |
| `typspec-archive` | `/typspec-archive` | Archives and merges deltas |

The AI reads the project context from `typspec.jsonc`, inspects existing
specs, and works through the change document step by step.

---

## Repository Structure

```
typspec/
├── crates/
│   ├── cli/              # typspec CLI (binary)
│   │   └── src/
│   │       ├── main.rs
│   │       ├── skills.rs
│   │       ├── config.rs
│   │       ├── fuzzy.rs
│   │       ├── metadata.rs
│   │       └── surgery.rs
│   └── core/             # Core library
│       └── src/
│           ├── lib.rs
│           ├── config.rs
│           ├── fuzzy.rs
│           ├── metadata.rs
│           └── surgery.rs
├── skills/
│   └── typspec/          # Canonical AI skill files
│       ├── typspec-propose/SKILL.md
│       ├── typspec-explore/SKILL.md
│       ├── typspec-apply/SKILL.md
│       └── typspec-archive/SKILL.md
├── typspec/              # Project data
│   ├── specs/
│   ├── changes/
│   ├── archive/
│   └── bibliographies/
├── assets/
│   └── typspec.schema.json
├── Cargo.toml             # Workspace manifest
└── LICENSE
```

---

## License

MIT — see [LICENSE](LICENSE).
