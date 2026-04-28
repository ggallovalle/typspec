#set document(title: "Typspec CLI", author: "Gerson Gallo")

= Typspec CLI Specification

This document specifies the commands and behavior of the `typspec` CLI.

== Global Flags

The CLI SHALL support the following global flags available on all commands:

```
--dry-run    Preview actions without executing. Implies -vv (info level).
--json       Output machine-readable JSON instead of human-readable text.
             Default: human-readable.
-v           Warning-level logging (default is error).
-vv          Info-level logging.
-vvv         Debug-level logging.
```

==== Scenario: dry-run implies verbose

- GIVEN a user runs `typspec archive my-change --dry-run`
- WHEN the command would perform side effects
- THEN the actions are described but not executed
- AND log level is set to info

==== Scenario: verbose flag levels

- GIVEN a user runs `typspec status my-change`
- WHEN no `-v` flag is given, only errors are shown
- WHEN `-v` is used, warnings and above are shown
- WHEN `-vv` is used, info and above are shown
- WHEN `-vvv` or more is used, debug and above are shown

== typspec init

Scaffold a new typspec project in the current directory.

Usage: `typspec init [path]`

If no path is given, uses the current directory. Creates `typspec/specs/`, `typspec/changes/`, and a default `typspec.jsonc`.

==== Scenario: init in current directory

- GIVEN a directory with no typspec setup
- WHEN `typspec init` is run
- THEN `typspec/specs/` and `typspec/changes/` are created
- AND `typspec.jsonc` is created with defaults

==== Scenario: init with path

- GIVEN a target directory
- WHEN `typspec init ./my-project` is run
- THEN the typspec structure is created inside `./my-project`

== typspec new

Create a new spec or change file from a template.

Usage:
```
typspec new spec <name>
typspec new change <name>
```

==== Scenario: new spec

- WHEN `typspec new spec module-api` is run
- THEN `typspec/specs/module-api.typ` is created from the spec template

==== Scenario: new change

- WHEN `typspec new change add-feature` is run
- THEN `typspec/changes/add-feature.typ` is created from the change template

== typspec list

List active specs or changes.

Usage:
```
typspec list specs
typspec list changes
typspec ls specs       (alias)
typspec ls changes     (alias)
```

When neither `specs` nor `changes` is specified, defaults to `changes`. The `ls` alias SHALL behave identically to `list`.

==== Scenario: list specs

- WHEN `typspec list specs` is run
- THEN all `.typ` files in `typspec/specs/` are listed
- AND their titles are displayed

==== Scenario: list changes

- WHEN `typspec list changes` is run
- THEN all `.typ` files in `typspec/changes/` are listed with their task completion status

==== Scenario: JSON output

- WHEN `typspec list changes --json` is run
- THEN a JSON array of change objects is output to stdout
- AND each object includes `id`, `title`, `task_count`, `tasks_done`

== typspec status

Display metadata from a spec or change.

Usage: `typspec status <name>`

Compiles the `.typ` file and queries for all `typspec:*` metadata elements.

==== Scenario: status for change shows tasks

- GIVEN a change file with `#task` calls
- WHEN `typspec status my-change` is run
- THEN all tasks are listed with their `done` status
- AND a summary shows `3/5 tasks complete`

==== Scenario: status for spec shows requirements

- GIVEN a spec file with `#requirement` calls
- WHEN `typspec status module-api` is run
- THEN all requirements are listed with their IDs and priorities
- AND scenario counts are shown

==== Scenario: JSON output includes metadata

- WHEN `typspec status my-change --json` is run
- THEN the output includes the raw metadata from the compiled document

== typspec render

Compile a `.typ` file to PDF, with optional watch mode.

Usage:
```
typspec render [path]
typspec render [path] --watch
```

If no path is given, renders the most recently modified spec or change.

==== Scenario: render with path

- GIVEN a spec file at `typspec/specs/module-api.typ`
- WHEN `typspec render typspec/specs/module-api.typ` is run
- THEN a PDF is generated at `typspec/specs/module-api.pdf`

==== Scenario: render with watch

- WHEN `typspec render typspec/specs/module-api.typ --watch` is run
- THEN the file is recompiled on changes
- AND the process continues until interrupted

== typspec archive

Archive a completed change. Merges spec-deltas into target specs, then moves the change to the archive directory.

Usage: `typspec archive <name>`

=== Archive Process

The archive command SHALL:

1. Compile the change `.typ` file and query for `typspec:requirement` metadata with `action` set.
2. For each requirement with `action: "added"`, `action: "modified"`, or `action: "removed"`:
   - Parse the target spec file using `typst_syntax`.
   - Locate the requirement node by `id` using AST traversal.
   - Reconstruct the tree with the modification applied.
   - Write the modified tree back to source.
3. Check if the target spec has been modified since the change was created (git SHA comparison).
4. If conflict detected, warn the user and skip the conflicting requirement.
5. Move the change file to `typspec/archive/<name>.typ`.

==== Scenario: archive with added requirements

- GIVEN a change with spec-deltas containing `action: "added"`
- AND the target spec does not contain those requirement IDs
- WHEN `typspec archive my-change` is run
- THEN the new requirements are inserted into the target spec
- AND the change is moved to archive

==== Scenario: archive with removed requirements

- GIVEN a change with spec-deltas containing `action: "removed"`
- AND the target spec contains those requirement IDs
- WHEN `typspec archive my-change` is run
- THEN those requirement nodes are removed from the target spec via AST surgery

==== Scenario: archive detects spec conflict

- GIVEN the target spec was modified after the change was created
- WHEN `typspec archive my-change` is run
- THEN a warning is displayed
- AND conflicting requirements are skipped
- AND the user is shown which requirements could not be merged

==== Scenario: archive skips unchanged specs

- GIVEN a change with no spec-deltas (tooling-only change)
- WHEN `typspec archive my-change` is run
- THEN no spec files are modified
- AND the change is moved to archive

==== Scenario: dry-run archive

- WHEN `typspec archive my-change --dry-run` is run
- THEN all merge operations are described in detail
- AND no files are modified

== typspec validate

Compile a `.typ` file and check that all metadata elements conform to expected structure.

Usage: `typspec validate [path]`

==== Scenario: validate valid spec

- GIVEN a well-formed spec `.typ` file
- WHEN `typspec validate typspec/specs/module-api.typ` is run
- THEN the command exits with code 0
- AND a success message is shown

==== Scenario: validate with compilation error

- GIVEN a `.typ` file with a syntax error
- WHEN `typspec validate typspec/specs/broken.typ` is run
- THEN the command reports the error with file and line
- AND exits with a non-zero code

== typspec install

Fetch workspace dependencies declared in `typspec.jsonc` workspaces.

Usage: `typspec install`

For `git`-based workspaces, clones or fetches the repository and caches it locally. For `registry`-based workspaces (future), downloads from the registry.

==== Scenario: install git workspace dependency

- GIVEN `typspec.jsonc` has a workspace entry with `git` and `tag`
- WHEN `typspec install` is run
- THEN the repository is cloned at the specified tag into a local cache

== Exit Codes

The CLI SHALL use the following exit codes:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (validation failure, missing files, archive conflict) |
| 130 | Cancelled by user (SIGINT) |

== Command Resolution

The CLI SHALL discover the nearest `typspec.jsonc` by walking up from the current working directory. If none is found, commands that require a project context SHALL error with a message suggesting `typspec init`.

==== Scenario: cli outside project

- GIVEN the current directory has no `typspec.jsonc` in any parent
- WHEN any project command is run
- THEN the CLI errors with "No typspec project found. Run `typspec init` to create one."
