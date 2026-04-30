#import "../src/lib.typ": spec, requirement, scenario
#import "../links.typ"
#import "../glossary.typ"

#show: glossary.glossary
#show: spec.with(title: "Typspec CLI")

= Typspec CLI Specification

This document specifies the interface of the `typspec` CLI: its commands,
flags, exit codes, and cross-cutting behavior. For the business logic each
command performs, see the referenced domain spec.

== Global Flags

#requirement("global-flags")[
  The CLI SHALL support global flags available on all commands.

  #scenario("dry-run implies verbose",
    given: [user runs `typspec archive my-change --dry-run`],
    when: [command would perform side effects],
    then: [actions described but not executed, log level = info],
  )

  #scenario("verbose flag levels",
    given: [user runs `typspec status my-change`],
    when: [no `-v` given, only errors shown],
    then: [`-v` = warning level, `-vv` = info, `-vvv` = debug],
  )

  #scenario("JSON output",
    given: [user adds `--json` flag],
    when: [command runs],
    then: [output is machine-readable JSON to stdout],
  )

  #scenario("dry-run flag",
    given: [user adds `--dry-run` flag],
    when: [command runs],
    then: [no side effects, all actions described],
  )
]

== Commands

=== typspec init

#requirement("cmd-init")[
  Scaffold a new typspec project.

  Arguments: `[path]` — target directory (optional, defaults to CWD).
  Flags: `--tools <list>` — comma-separated tool IDs.
  Exit: 0 on success, 1 on error.

  Behavior specified in #links.spec-scaffold.
]

=== typspec new

#requirement("cmd-new")[
  Create a new spec or change file from a template.

  Arguments: `spec <name>` or `change <name>`.
  Exit: 0 on success, 1 on error.

  Behavior specified in #links.spec-scaffold.
]

=== typspec list

#requirement("cmd-list", priority: "shall")[
  List active specs or changes. Defaults to changes.

  `ls` SHALL be an alias for `list` with identical behavior.

  #scenario("list specs",
    when: [`typspec list --specs`],
    then: [all `.typ` files in `typspec/specs/` listed],
  )

  #scenario("list changes",
    when: [`typspec list`],
    then: [all `.typ` files in `typspec/changes/` listed],
  )

  #scenario("list JSON output",
    when: [`typspec list --json`],
    then: [JSON array of file names],
  )

  #scenario("ls alias",
    when: [`typspec ls`],
    then: [identical to `typspec list` output],
  )
]

=== typspec status

#requirement("cmd-status", priority: "shall")[
  Display metadata from a spec or change by compiling and querying.

  #scenario("status shows requirements",
    given: [spec file with `#requirement` calls],
    when: [`typspec status module-api`],
    then: [all requirements listed with IDs and priorities],
  )

  #scenario("status shows tasks",
    given: [change file with `#task` calls],
    when: [`typspec status my-change`],
    then: [tasks listed with done status, summary shown],
  )

  #scenario("status JSON",
    when: [`typspec status my-change --json`],
    then: [raw metadata from compiled document output],
  )
]

=== typspec render

#requirement("cmd-render", priority: "shall")[
  Compile a `.typ` file to PDF, with optional watch mode.

  If no path is given, renders the most recently modified `.typ` file.

  #scenario("render with path",
    when: [`typspec render typspec/specs/module-api.typ`],
    then: [PDF generated at `typspec/specs/module-api.pdf`],
  )

  #scenario("render with watch",
    when: [`typspec render typspec/specs/module-api.typ --watch`],
    then: [file recompiled on changes until interrupted],
  )
]

=== typspec archive

#requirement("cmd-archive", priority: "shall")[
  Archive a completed change.

  Arguments: `<name>` — change to archive.
  Flags: `[-n, --dry-run]` — preview without side effects.
  Exit: 0 on success, 1 on error (including validation failures).

  Behavior specified in #links.spec-archive.
]

=== typspec validate

#requirement("cmd-validate", priority: "shall")[
  Compile a `.typ` file and check for errors.

  #scenario("validate valid spec",
    when: [`typspec validate typspec/specs/module-api.typ`],
    then: [success message, exit code 0],
  )

  #scenario("validate with error",
    given: [`.typ` file with syntax error],
    when: [`typspec validate typspec/specs/broken.typ`],
    then: [error reported with file and line, non-zero exit],
  )
]

=== typspec install

#requirement("cmd-install", priority: "should")[
  Fetch workspace dependencies declared in `typspec.jsonc`.

  Exit: 0 on success, 1 on error.

  Behavior specified in #links.spec-install.
]

=== typspec which

#requirement("which-command", priority: "shall")[
  Locate a file by name across specs, changes, and archive directories.

  Search order: specs → changes → archive. The first match is returned.
  If no exact match, applies @fuzzy-matching for suggestions.

  #scenario("which finds a spec",
    when: [`typspec which module-api`],
    then: [outputs full path like `typspec/specs/module-api.typ`],
  )

  #scenario("which finds an archived change",
    when: [`typspec which customizable-paths`],
    then: [outputs path in archive directory],
  )

  #scenario("which with typo shows suggestion",
    when: [`typspec which modle-api`],
    then: [error + "tip: a similar name exists: 'module-api'"],
  )

  #scenario("which with no match and no close name errors",
    when: [`typspec which completely-unrelated`],
    then: [error without suggestion],
  )
]

=== typspec usage

#requirement("cmd-usage", priority: "shall")[
  Output a `.usage.kdl` format spec describing the full CLI.

  The spec SHALL include all commands, flags, positional args, and
  `complete` directives for dynamic value completion on `status`,
  `archive`, and `which` arguments.

  #scenario("usage outputs valid KDL",
    when: [`typspec usage`],
    then: [output is valid usage KDL spec, parsable by `usage lint`],
  )

  #scenario("usage spec includes complete directives",
    when: [`typspec usage`],
    then: [spec contains `complete` for status/archive/which name args],
  )
]

=== typspec completion

#requirement("cmd-completion", priority: "shall")[
  Output a shell completion script for the given shell.

  The script SHALL call `usage complete-word` to generate completions and
  cache the spec from `typspec usage` in `$TMPDIR`.

  #scenario("completion zsh outputs valid script",
    when: [`typspec completion zsh > _typspec`],
    then: [script contains `#compdef typspec` and calls `usage complete-word`],
  )

  #scenario("completion errors without usage",
    when: [`usage` CLI is not installed, user sources completion script],
    then: [script prints error message instructing to install usage],
  )
]

== Exit Codes

#requirement("exit-codes", priority: "shall")[
  The CLI SHALL use exit code 0 for success, 1 for errors, and 130 for
  user cancellation (SIGINT).
]

== Cross-cutting Behavior

=== Config Discovery

#requirement("config-discovery", priority: "shall")[
  Path resolution SHALL be relative to the config file's directory, not CWD.
  This ensures consistent behavior regardless of which subdirectory the user
  runs commands from.
]

=== Name Resolution

#requirement("fuzzy-name-matching", priority: "shall")[
  The `status` and `archive` commands SHALL perform @fuzzy-matching when a
  spec or change name is not found.

  The CLI SHALL collect all available names from the appropriate directory,
  compute @damlev edit distance against the user's input, and display
  the closest match when ~67% similarity threshold is met.

  #scenario("suggests closest match on typo",
    given: [a change named `customizable-paths` exists],
    when: [user runs `typspec status customizalbs-path`],
    then: [error shows `did you mean 'customizable-paths'?`],
  )

  #scenario("no suggestion when no close match",
    given: [available names are `module-api`, `cli`, `config`],
    when: [user runs `typspec status completely-unrelated`],
    then: [error shows without any suggestion],
  )

  #scenario("multiple suggestions for equal distance",
    given: [names `add-auth` and `add-cache` both exist],
    when: [user runs `typspec status add-`],
    then: [shows both: `did you mean 'add-auth' or 'add-cache'?`],
  )

  #scenario("output format matches clap",
    when: [suggestion is shown],
    then: [format is `tip: a similar name exists: '<name>'`],
  )
]

=== Typst Invocation

#requirement("cli-sets-root-for-bibliographies", priority: "shall")[
  The CLI SHALL pass `--root` set to the config file's parent directory
  when invoking `typst compile` for rendering, validation, and queries.

  This ensures bibliography and citation paths resolve correctly from any
  spec, change, or archive document regardless of subdirectory.

  #scenario("render sets root",
    when: [`typspec render typspec/specs/module-api.typ`],
    then: [internally calls `typst compile --root <project-root> ...`],
  )

  #scenario("validate sets root",
    when: [`typspec validate typspec/specs/module-api.typ`],
    then: [internally calls `typst compile --root <project-root> ...`],
  )

  #scenario("status sets root",
    when: [`typspec status module-api`],
    then: [internally calls `typst query --root <project-root> ...`],
  )
]

=== Output Formatting

#requirement("list-shows-paths", priority: "shall")[
  The `typspec list` and `typspec list --specs` commands SHALL show the
  relative file path alongside each entry name.

  In human-readable mode:
  ```
    module-api (typspec/specs/module-api.typ)
  ```

  In JSON mode, each entry SHALL include a `path` field:
  ```json
  [{"name": "module-api", "path": "typspec/specs/module-api.typ"}]
  ```

  #scenario("list specs shows paths",
    when: [`typspec list --specs`],
    then: [output shows `name (relative/path.typ)` for each spec],
  )

  #scenario("list changes shows paths",
    when: [`typspec list`],
    then: [output includes paths for each change file],
  )

  #scenario("list with JSON includes path field",
    when: [`typspec list --json`],
    then: [JSON array with `name` and `path` fields per entry],
  )
]

=== Completions

#requirement("cmd-list-complete", priority: "shall")[
  The `list` command SHALL support a hidden `--complete` flag that
  outputs bare names (one per line) for use by `usage`'s `complete`
  directive.

  Output SHALL follow this order:
  - `typspec list --complete` — change names only
  - `typspec list --specs --complete` — spec names only
  - `typspec list --all --complete` — specs first, then changes, then
    archive names (with date prefixes stripped)

  #scenario("list --complete outputs change names",
    when: [`typspec list --complete`],
    then: [one change name per line, no paths or descriptions],
  )

  #scenario("list --specs --complete outputs spec names",
    when: [`typspec list --specs --complete`],
    then: [one spec name per line],
  )

  #scenario("list --all --complete includes archive names",
    given: [archived change `2026-04-28-old-feature.typ` exists],
    when: [`typspec list --all --complete`],
    then: [output includes `old-feature` (date prefix stripped)],
  )
]

#requirement("usage-as-runtime-dep", priority: "shall")[
  The completion scripts SHALL depend on the `usage` CLI being installed.
  If `usage` is not found, the completion script SHALL print an error
  and exit cleanly.

  #scenario("missing usage shows helpful error",
    when: [completion script runs without `usage` installed],
    then: [message: "Error: usage CLI not found. See https://usage.jdx.dev"],
  )
]
