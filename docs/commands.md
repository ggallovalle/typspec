# Commands

Full reference for all `typspec` CLI subcommands. For workflow patterns,
see [Workflows](workflows.md). For concepts, see [Concepts](concepts.md).

## Global Flags

Available on every command:

| Flag | Description |
|------|-------------|
| `--json` | Machine-readable JSON output |
| `--dry-run` | Preview actions without executing |
| `-v` | Verbosity: `-v` = warning, `-vv` = info, `-vvv` = debug |

---

## typspec init

Scaffold a new typspec project in the current or specified directory.

```bash
typspec init [path] [--tools <tools>]
```

| Argument | Description |
|----------|-------------|
| `path` | Target directory (default: current directory) |
| `--tools` | Comma-separated AI tool IDs: `claude`, `codex`, `opencode`, `all`, `none` |

**What it creates:**

```
typspec/
├── specs/
├── changes/
├── archive/
├── bibliographies/
│   └── example.yaml
└── typspec.jsonc
```

**Examples:**

```bash
# Initialize in current directory
typspec init

# Initialize in a specific directory
typspec init ./my-project

# Initialize with AI skills for OpenCode
typspec init --tools opencode

# Initialize with multiple tools
typspec init --tools claude,opencode
```

---

## typspec new

Create a new spec or change file from a template.

```bash
typspec new <spec|change> <name>
```

| Subcommand | Description |
|------------|-------------|
| `spec <name>` | Creates a new `.typ` spec file in `typspec/specs/` |
| `change <name>` | Creates a new change document in `typspec/changes/` |

**Examples:**

```bash
typspec new spec auth
typspec new change add-rate-limiting
```

### Spec template

```typst
#show: spec.with(title: "auth")

= auth

== Requirement 1

#requirement("req-1", priority: "shall")[
  Description of what the system SHALL do.

  #scenario("scenario name",
    when: [action],
    then: [expected result],
  )
]
```

### Change template

```typst
#show: change.with(id: "add-rate-limiting")

= Proposal

== Motivation

Why is this change needed?

== Scope

What is and isn't changing.

= Design

#decision("Title", rationale: [Why this approach.])

= Spec Deltas

== ADDED Requirements

#requirement("new-req", priority: "shall", action: "added")[
  Description.

  #scenario("name",
    when: [action],
    then: [result],
  )
]

= Tasks

#task_group("Implementation", (
  task([Do the thing], done: false),
))
```

---

## typspec list

List active specs or changes. Defaults to changes.

```bash
typspec list [--specs] [--all] [--json]
```

| Flag | Description |
|------|-------------|
| `--specs` | List specs instead of changes |
| `--all` | Include archive in listing |
| `--json` | Machine-readable JSON output |

**Alias:** `typspec ls`

**Examples:**

```bash
# List active changes
typspec list

# List specs
typspec list --specs

# List everything (specs + changes + archive)
typspec list --all
```

Output shows names with relative paths:

```
  add-health-endpoint (typspec/changes/add-health-endpoint.typ)
```

---

## typspec status

Display metadata from a spec or change.

```bash
typspec status <name> [--json]
```

| Argument | Description |
|----------|-------------|
| `name` | Name of the spec or change (without `.typ` extension) |
| `--json` | Raw metadata from the compiled document |

The command searches `typspec/specs/` first, then `typspec/changes/`.
If not found, it suggests close matches using fuzzy matching.

**Examples:**

```bash
# Show spec details
typspec status module-api

# Show change progress
typspec status add-health-endpoint

# Raw JSON output
typspec status add-health-endpoint --json
```

**Human-readable output:**

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

---

## typspec validate

Compile a `.typ` file and check for errors.

```bash
typspec validate [path]
```

| Argument | Description |
|----------|-------------|
| `path` | File to validate (default: current directory) |

**Examples:**

```bash
# Validate a change file
typspec validate typspec/changes/add-health-endpoint.typ

# Validate all specs (current directory)
typspec validate typspec/specs/
```

On success:
```
✓ typspec/changes/add-health-endpoint.typ is valid
```

On error, Typst diagnostics are shown with file and line information.

---

## typspec render

Compile a `.typ` file to PDF.

```bash
typspec render [path] [--watch]
```

| Argument | Description |
|----------|-------------|
| `path` | File to render (default: most recently modified `.typ` file) |
| `--watch` | Auto-recompile on file changes |

The PDF is written alongside the `.typ` file (same name, `.pdf` extension).

**Examples:**

```bash
# Render a spec
typspec render typspec/specs/module-api.typ

# Render a change with auto-reload
typspec render typspec/changes/add-health-endpoint.typ --watch

# Render the most recently modified file
typspec render
```

---

## typspec archive

Complete a change by merging its spec-deltas and moving it to the
archive.

```bash
typspec archive <change-name> [--yes]
```

| Argument | Description |
|----------|-------------|
| `change-name` | Name of the change to archive |
| `--yes` | Skip confirmation |

**What it does:**
1. Compiles the change file and reads its metadata
2. Extracts requirement bodies from the source
3. Applies ADDED/MODIFIED/REMOVED deltas to target specs
4. Checks for git conflicts (uncommitted spec changes)
5. Moves the change to `typspec/archive/YYYY-MM-DD-<name>.typ`

**Examples:**

```bash
typspec archive add-health-endpoint
typspec archive add-health-endpoint --yes
```

---

## typspec which

Locate a file by name across specs, changes, and archive directories.

```bash
typspec which <name>
```

| Argument | Description |
|----------|-------------|
| `name` | Name of the spec, change, or archived change |

Searches in order: specs → changes → archive. For archive files, the
date prefix (`YYYY-MM-DD-`) is ignored during matching.

If no exact match is found, fuzzy matching suggests close names.

**Examples:**

```bash
typspec which module-api
# → typspec/specs/module-api.typ

typspec which add-health-endpoint
# → typspec/changes/add-health-endpoint.typ    (if still active)
# → typspec/archive/2026-04-28-add-health-endpoint.typ  (if archived)
```

---

## typspec install

Fetch workspace dependencies declared in `typspec.jsonc`.

```bash
typspec install
```

For `git`-based workspace entries, clones the repository at the
specified ref into `.typspec/cache/`.

---

## typspec completion

Generate shell completion scripts.

```bash
typspec completion <shell>
```

| Argument | Description |
|----------|-------------|
| `shell` | `zsh`, `bash`, `fish`, or `powershell` |

**Note:** Requires the `usage` CLI to be installed
([usage.jdx.dev](https://usage.jdx.dev)). The generated script calls
`usage complete-word` with a spec from `typspec usage`.

**Examples:**

```bash
typspec completion zsh > ~/.zsh/functions/_typspec
```

---

## Hidden Commands

These commands are used internally and not shown in help output.

### typspec usage

Outputs a usage KDL spec for shell completion generation.

```bash
typspec usage
```

### typspec schema

Outputs the JSON Schema for `typspec.jsonc` (generated from Rust
structs).

```bash
typspec schema > assets/typspec.schema.json
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Error (invalid input, validation failure, etc.) |
| `130` | User cancellation (SIGINT) |

## Next Steps

- [Getting Started](getting-started.md) — Walk through the workflow with an example
- [Concepts](concepts.md) — Deeper understanding of specs, changes, and deltas
- [Workflows](workflows.md) — Common patterns and when to use each command
