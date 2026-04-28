# Getting Started

This guide walks through the complete typspec workflow with a concrete
example. You'll learn how specs, changes, and archiving work together.

## How It Works

typspec helps you and your AI coding assistant agree on what to build
before writing code.

```
propose ──► apply ──► archive
   │           │          │
   ▼           ▼          ▼
 scope     implement   merge deltas
 + design  tasks       + preserve history
```

**Three core commands:**

| Command | What it does |
|---------|-------------|
| `typspec new change` | Scaffolds a change document (proposal, design, spec-deltas, tasks) |
| `typspec validate` | Compiles the `.typ` file and checks for errors |
| `typspec archive` | Merges spec-deltas and moves the change to archive |

## What typspec Creates

After running `typspec init`, your project has this structure:

```
typspec/
├── specs/           # Source of truth (specification files)
├── changes/         # Active change documents
├── archive/         # Completed changes (audit trail)
├── bibliographies/  # Hayagriva bibliography files
└── typspec.jsonc    # Project configuration
```

**Two key directories:**

- **`specs/`** — The source of truth. These `.typ` files describe how
  your system behaves, organized by domain.

- **`changes/`** — Proposed modifications. Each change is a single
  `.typ` file containing all sections. When a change is archived, its
  spec-deltas merge into the main specs.

## Example: Adding a Health Check Endpoint

Let's walk through adding a `/health` endpoint to an API.

### 1. Initialize the project

```bash
typspec init
```

Creates the standard typspec directory layout.

### 2. Start the change

```bash
typspec new change add-health-endpoint
```

This creates `typspec/changes/add-health-endpoint.typ`:

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

== ADDED Requirements

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
  task([Write integration test], done: false),
))
```

### 3. Fill in the details

Edit the file to describe your change. Here's what a filled-in change
looks like:

```typst
#show: change.with(id: "add-health-endpoint")

= Proposal

== Motivation

Operators need a way to check if the service is alive without
authenticating. This enables load balancer health checks and
Kubernetes readiness probes.

== Scope

In scope:
- GET /health returning 200 OK with JSON body
- Works without authentication
- Includes dependency health (database, cache)

Out of scope:
- Detailed metrics or diagnostic endpoints
- Historical health data

= Design

#decision(
  "Simple handler, no auth",
  rationale: [
    Health checks must work without auth so load balancers and
    orchestration systems can probe the endpoint. The handler
    pings the database and cache, returning their status.
  ],
  alternatives: [
    - Auth-only health check: breaks LB integration.
    - Deep diagnostics: too heavy for frequent polling.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("health-endpoint", priority: "shall", action: "added")[
  The system SHALL expose a GET /health endpoint.

  #scenario("returns ok when healthy",
    when: [service and all dependencies are up],
    then: [200 OK with `{"status": "ok"}`],
  )

  #scenario("returns degraded when dependency down",
    given: [the database is unreachable],
    when: [GET /health is called],
    then: [503 with `{"status": "degraded", "database": "down"}`],
  )

  #scenario("no auth required",
    when: [GET /health is called without credentials],
    then: [200 OK (not 401)],
  )
]

= Tasks

#task_group("Implementation", (
  task([Add GET /health route to the router], done: false),
  task([Implement health handler with DB/cache checks], done: false),
  task([Add /health to the no-auth middleware whitelist], done: false),
  task([Write integration test for health check], done: false),
))
```

### 4. Validate as you go

```bash
typspec validate typspec/changes/add-health-endpoint.typ
```

Compiles the document with Typst and reports any errors. No PDF is
generated — this is a fast syntax and structure check.

### 5. Track progress

```bash
typspec status add-health-endpoint
```

Shows a summary of requirements, scenarios, decisions, and tasks:

```
Status: add-health-endpoint
  Requirements: 1
  Scenarios: 3
  Tasks: 2/4 complete

  [dec] Simple handler, no auth
  [req] health-endpoint (added)
  [x] Add /health route to the router
  [x] Implement health handler
  [ ] Add to no-auth whitelist
  [ ] Write integration test
```

### 6. Render to PDF (optional)

```bash
typspec render typspec/changes/add-health-endpoint.typ
```

Generates a PDF for sharing with reviewers.

### 7. Archive when done

```bash
typspec archive add-health-endpoint
```

This:
1. Reads the spec-delta requirements from the change
2. Applies ADDED/MODIFIED/REMOVED deltas to the target spec
3. Moves the change to `typspec/archive/2026-04-28-add-health-endpoint.typ`

The main spec now includes the health endpoint requirements, and the
change is preserved in the archive for audit history.

## Next Steps

- [Concepts](concepts.md) — Deeper understanding of specs, changes, and deltas
- [Commands](commands.md) — Full reference for all CLI subcommands
- [Workflows](workflows.md) — Common patterns and when to use each command
