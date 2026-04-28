# Workflows

Common patterns for using typspec, from simple changes to complex
multi-domain work.

## Quick Reference

| Workflow | When to use |
|----------|-------------|
| [Simple change](#simple-change) | One domain, clear scope, few tasks |
| [Multi-domain change](#multi-domain-change) | Change touches multiple specs |
| [AI-assisted](#ai-assisted) | Using an AI coding assistant |
| [Exploring first](#exploring-first) | Requirements are unclear |
| [Parallel changes](#parallel-changes) | Working on multiple features at once |

---

## Simple Change

**Best for:** Adding a small feature, fixing a bug, updating
documentation.

### Steps

```
typspec new change my-feature
  │
  ▼
Edit the .typ file (proposal → spec-deltas → design → tasks)
  │
  ▼
typspec validate typspec/changes/my-feature.typ
  │
  ▼
Implement the tasks (edit code)
  │
  ▼
Mark tasks done: true in the .typ file
  │
  ▼
typspec archive my-feature
```

### Example

```bash
# 1. Scaffold
typspec new change fix-login-error

# 2. Validate after writing
typspec validate typspec/changes/fix-login-error.typ

# 3. Archive when done
typspec archive fix-login-error
```

---

## Multi-Domain Change

**Best for:** A feature that touches multiple areas (e.g., adding a
payment method that requires API changes, UI changes, and database
changes).

In this workflow, the change's `modifies` field lists multiple specs:

```typst
#show: change.with(id: "add-subscriptions", modifies: ("module-api", "cli"))
```

Each requirement targets a specific spec:

```typst
#requirement("create-subscription", priority: "shall",
    action: "added", modifies: "module-api")[
  ...
]

#requirement("cancel-subscription", priority: "shall",
    action: "added", modifies: "cli")[
  ...
]
```

When archived, each delta is routed to its respective spec file.

### Steps

```
typspec new change add-subscriptions
  │
  ▼
Set modifies: ("module-api", "cli") in the change header
  │
  ▼
Write spec-deltas with per-requirement modifies: fields
  │
  ▼
Validate, implement, archive (same as simple)
```

---

## AI-Assisted

**Best for:** Teams using Claude Code, OpenCode, or other AI coding
tools. The AI reads the change document and implements tasks.

### Setup

```bash
typspec init --tools opencode
```

This installs agent skills under `.agents/skills/` that teach the AI
how to work with typspec.

### Workflow

```
Human: /typspec-propose add-health-endpoint
  │
  ▼
AI: Creates typspec/changes/add-health-endpoint.typ
    with proposal, spec-deltas, design, and tasks
  │
  ▼
Human: (reviews and edits the change document)
  │
  ▼
Human: /typspec-apply
  │
  ▼
AI: Works through tasks, writes code,
    marks tasks done: true
  │
  ▼
Human: /typspec-archive
  │
  ▼
AI: Merges deltas and archives the change
```

### Slash Commands

| Command | What it does |
|---------|-------------|
| `/typspec-propose` | Scopes and scaffolds a change |
| `/typspec-explore` | Investigates before committing |
| `/typspec-apply` | Implements tasks from a change |
| `/typspec-archive` | Archives and merges deltas |

The AI uses `typspec list --specs` to discover existing specs,
`typspec status <name>` to inspect metadata, and `typspec which <name>`
to find file locations.

---

## Exploring First

**Best for:** Requirements are unclear, you need to investigate the
codebase, or you want to compare approaches before committing.

### Steps

```
/typspec-explore
  │
  ▼
AI investigates the codebase, compares options,
discusses tradeoffs with you
  │
  ▼
When clarity emerges → /typspec-propose <name>
```

### Example

```
You: /typspec-explore

AI:  What would you like to explore?

You: How should we handle rate limiting?

AI:  Let me investigate your current setup...
     [Searches codebase]

     I see three approaches for your stack:

     1. Token bucket in-memory (simple, lost on restart)
     2. Redis-based sliding window (persistent, needs Redis)
     3. API gateway rate limiting (external dependency)

     Your API currently doesn't use Redis. Option 1 is
     simplest to start. Want to formalize this?

You: Let's start with token bucket.

AI:  Ready when you are. Run /typspec-propose add-rate-limiting.
```

---

## Parallel Changes

**Best for:** Working on multiple features simultaneously. Each change
is independent and can be implemented and archived separately.

```
typspec/changes/
├── add-health-endpoint.typ    ← in progress
├── fix-login-error.typ        ← in progress
└── add-rate-limiting.typ      ← drafted, not started
```

### Managing Parallel Changes

```bash
# See all active changes
typspec list

# Check specific change progress
typspec status add-health-endpoint
typspec status fix-login-error

# Archive each independently when done
typspec archive fix-login-error
```

### Conflict Avoidance

If two changes modify different requirements in the same spec, they
can be archived in any order. If they modify the same requirement,
archive the first one, then update the second change's delta to
reflect the merged state.

---

## Best Practices

### Change Names

Use descriptive kebab-case names:

```bash
# Good
typspec new change add-rate-limiting
typspec new change fix-session-timeout

# Avoid
typspec new change update
typspec new change changes
typspec new change wip
```

### Validation Frequency

Validate after every significant edit:

```bash
typspec validate typspec/changes/my-change.typ
```

Catches Typst syntax errors early and keeps the feedback loop tight.

### Task Granularity

Keep tasks small enough to complete in one session:

```typst
task([Add GET /health route], done: false),  # good
task([Implement the entire API], done: false),  # too large
```

### Archive When Done

Don't leave completed changes in the active changes directory.
Archive them — this:
- Keeps the active list clean
- Merges requirements into the source of truth
- Preserves the change for audit history

## Next Steps

- [Getting Started](getting-started.md) — Walk through the workflow with an example
- [Concepts](concepts.md) — Deeper understanding of specs, changes, and deltas
- [Commands](commands.md) — Full CLI reference
