# Concepts

This guide explains the core ideas behind typspec and how they fit
together. For practical usage, see [Getting Started](getting-started.md).

## Philosophy

Specifications should be precise, renderable, and machine-readable.
Markdown falls short — ambiguous syntax, no structured data, and
fragile PDF pipelines. Typst solves this with deterministic rendering
and structured markup.

typspec is built on four principles:

```
precise not ambiguous    — Typst eliminates Markdown's syntax issues
structured not freeform  — requirements, scenarios, decisions are first-class
renderable not raw       — beautiful PDFs from the same source
change-aware not static  — deltas make modifications explicit
```

## The Big Picture

typspec organizes your work into two main areas:

```
┌────────────────────────────────────────────────────────────┐
│                     typspec/                                │
│                                                            │
│   ┌──────────────────┐      ┌──────────────────────────┐   │
│   │     specs/       │      │        changes/           │   │
│   │                  │      │                           │   │
│   │  Source of truth │◄─────│  Proposed modifications   │   │
│   │  How your system │ merge│  Each change = one .typ   │   │
│   │  currently works │      │  Has all sections inside  │   │
│   │                  │      │                           │   │
│   └──────────────────┘      └──────────────────────────┘   │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Specs** describe current behavior. **Changes** propose modifications.
When a change is archived, its deltas merge into the source of truth.

## Specs

A spec is a `.typ` file containing structured requirements and
scenarios. Each requirement describes a specific behavior, and each
scenario is a concrete example of that behavior in action.

### Spec Structure

```typst
#show: spec.with(title: "Module: API")

= Module: API Specification

#requirement("rate-limiting", priority: "shall")[
  The API SHALL limit requests to 100 per minute per client.

  #scenario("within limit",
    when: [client makes 50 requests in a minute],
    then: [all requests succeed with 200],
  )

  #scenario("rate exceeded",
    when: [client makes 101 requests in a minute],
    then: [the 101st request returns 429 Too Many Requests],
  )
]
```

### Key Elements

| Element | Purpose |
|---------|---------|
| `#requirement("id")` | A specific behavior the system must have |
| `priority: "shall" / "should" / "may"` | RFC 2119 keywords indicating strength |
| `#scenario("name")` | A concrete example of the requirement |
| `when: [action]` | The trigger or input |
| `then: [result]` | The expected outcome |

### Organizing Specs

Specs are grouped by domain into files:

```
typspec/specs/
├── module-api.typ    # API behavior
├── cli.typ           # CLI commands
├── config.typ        # Config schema
├── ai-skills.typ     # Agent skill requirements
└── publishing.typ    # Distribution
```

## Changes

A change is a proposed modification to your system, packaged as a
single `.typ` file with everything needed to understand and implement
it.

### Change Structure

```
typspec/changes/add-health-endpoint.typ
├── Proposal      — why and what (motivation, scope)
├── Design        — how (decisions with rationale)
├── Spec Deltas   — what's changing (ADDED/MODIFIED/REMOVED)
└── Tasks         — implementation checklist
```

### Change Lifecycle

```
proposal ──► spec-deltas ──► design ──► tasks ──► implement ──► archive
   │              │             │          │            │
   ▼              ▼             ▼          ▼            ▼
 why            what          how       steps       merge + save
+ scope       changes      approach   to take
```

Each section builds on the previous one. The proposal captures intent,
spec-deltas define what changes, design explains the approach, and
tasks break it into implementable steps.

## Spec Deltas

Delta specs are the key concept that makes typspec work for brownfield
development. They describe **what's changing** rather than restating
the entire spec.

### Delta Sections

```typst
== ADDED Requirements

#requirement("new-feature", priority: "shall", action: "added")[
  New behavior.
]

== MODIFIED Requirements

#requirement("existing-feature", priority: "shall", action: "modified")[
  Changed behavior.
]

== REMOVED Requirements

#requirement("old-feature", priority: "shall", action: "removed")[
  Deprecated behavior.
]
```

### What Happens on Archive

| Section | Meaning | Archive Action |
|---------|---------|----------------|
| `action: "added"` | New behavior | Appended to target spec |
| `action: "modified"` | Changed behavior | Replaces existing requirement |
| `action: "removed"` | Deprecated behavior | Deleted from target spec |

### Why Deltas

**Clarity.** A delta shows exactly what's changing. No need to diff
against the current spec mentally.

**Conflict avoidance.** Two changes can modify different requirements
in the same spec file without conflict.

**Brownfield fit.** Most work modifies existing systems. Deltas make
this explicit rather than an afterthought.

## Tasks

Tasks break implementation into concrete steps with checkboxes:

```typst
#task_group("Implementation", (
  task([Add GET /health route to the router], done: false),
  task([Write integration test], done: false),
))
```

The CLI tracks task completion:

```bash
typspec status add-health-endpoint
```

Shows which tasks are done (`[x]`) and which remain (`[ ]`). Tasks
are marked `done: true` in the `.typ` file as they're completed.

## Archive

Archiving completes a change by merging its spec-deltas into the main
specs and preserving the change for history.

### What Happens

```
Before archive:

typspec/
├── specs/
│   └── module-api.typ  ◄───────────────┐
└── changes/                            │
    └── add-health-endpoint.typ         │ merge
        └── Spec Deltas ────────────────┘

After archive:

typspec/
├── specs/
│   └── module-api.typ  (now includes health endpoint)
└── archive/
    └── 2026-04-28-add-health-endpoint.typ  (preserved)
```

### The Archive Process

1. **Merge deltas.** ADDED/MODIFIED/REMOVED requirements are applied
   to the target spec via AST surgery.
2. **Move to archive.** The change file gets a date prefix and moves
   to `typspec/archive/`.
3. **Preserve context.** The full change document remains intact for
   audit history.

## How It All Fits Together

```
┌─────────────────────────────────────────────────────────────┐
│                       TYPSPEC FLOW                           │
│                                                             │
│  ┌──────────────┐                                            │
│  │  1. PROPOSE  │  typspec new change <name>                 │
│  │              │  Creates .typ file with all sections       │
│  └──────┬───────┘                                            │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                            │
│  │  2. FILL IN  │  Edit the .typ file:                       │
│  │   DETAILS    │  proposal → spec-deltas → design → tasks   │
│  └──────┬───────┘                                            │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                            │
│  │  3. VALIDATE │  typspec validate <file>                   │
│  │              │  Typst-level syntax and structure check    │
│  └──────┬───────┘                                            │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                            │
│  │  4. TRACK    │  typspec status <name>                     │
│  │              │  Requirements, tasks, progress             │
│  └──────┬───────┘                                            │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐     ┌────────────────────────────────┐    │
│  │  5. ARCHIVE  │────►│  Deltas merge into main specs   │    │
│  │              │     │  Change moves to archive/        │    │
│  └──────────────┘     │  Specs are now source of truth  │    │
│                       └────────────────────────────────┘    │
│                                                             │
│  The virtuous cycle:                                        │
│  specs → change → implement → archive → specs (updated)     │
└─────────────────────────────────────────────────────────────┘
```

## Glossary

| Term | Definition |
|------|------------|
| **Archive** | The process of completing a change, merging its spec-deltas into the main specs, and moving the file to `typspec/archive/` |
| **Change** | A proposed modification to the system, documented in a single `.typ` file with proposal, design, spec-deltas, and tasks |
| **Delta** | A change's requirements described as ADDED/MODIFIED/REMOVED relative to the current specs |
| **Requirement** | A specific behavior the system must have, defined with a `#requirement()` block |
| **Scenario** | A concrete example of a requirement in action, using when/then format |
| **Spec** | A `.typ` file containing the source-of-truth requirements for a domain |
| **Task** | A checklist item in a change, tracked as done/not done |

## Next Steps

- [Getting Started](getting-started.md) — Walk through the workflow with an example
- [Commands](commands.md) — Full CLI reference
- [Workflows](workflows.md) — Common patterns and when to use each command
