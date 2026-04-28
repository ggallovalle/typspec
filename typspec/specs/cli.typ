#import "../src/lib.typ": spec, requirement, scenario, decision

#show: spec.with(title: "Typspec CLI")

= Typspec CLI Specification

This document specifies the commands and behavior of the `typspec` CLI.

== Global Flags

#requirement("global-flags", priority: "shall")[
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

#requirement("cmd-init", priority: "shall")[
  Scaffold a new typspec project in the current or specified directory.

  Creates `typspec/specs/`, `typspec/changes/`, and a default `typspec.jsonc`.

  #scenario("init in current directory",
    when: [`typspec init`],
    then: [directories created, typspec.jsonc written with defaults],
  )

  #scenario("init with path",
    when: [`typspec init ./my-project`],
    then: [structure created inside `./my-project`],
  )
]

=== typspec new

#requirement("cmd-new", priority: "shall")[
  Create a new spec or change file from a template.

  #scenario("new spec",
    when: [`typspec new spec module-api`],
    then: [`typspec/specs/module-api.typ` created from template],
  )

  #scenario("new change",
    when: [`typspec new change add-feature`],
    then: [`typspec/changes/add-feature.typ` created from template],
  )
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
  Archive a completed change. Merges spec-deltas into target specs, then moves the change to the archive directory.

  #scenario("archive with added requirements",
    given: [change with `#requirement(..., action: "added")`],
    when: [`typspec archive my-change`],
    then: [new requirements inserted into target spec, change moved to archive],
  )

  #scenario("archive with removed requirements",
    given: [change with `#requirement(..., action: "removed")`],
    when: [`typspec archive my-change`],
    then: [requirements removed from target spec via AST surgery],
  )

  #scenario("archive detects spec conflict",
    given: [target spec has uncommitted changes],
    when: [`typspec archive my-change`],
    then: [warning displayed, conflicting specs skipped],
  )

  #scenario("dry-run archive",
    when: [`typspec archive my-change --dry-run`],
    then: [all merge operations described, no files modified],
  )
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
  Fetch workspace dependencies declared in `typspec.jsonc` workspaces.

  For `git`-based workspaces, clones at the specified ref into a local cache.

  #scenario("install git workspace",
    given: [config with `git` workspace entry and `tag`],
    when: [`typspec install`],
    then: [repository cloned at specified tag into `.typspec/cache/`],
  )
]

== Exit Codes

#requirement("exit-codes", priority: "shall")[
  The CLI SHALL use exit code 0 for success, 1 for errors, and 130 for user cancellation (SIGINT).
]

== Command Resolution

#requirement("config-discovery", priority: "shall")[
Path resolution SHALL be relative to the config file's directory, not CWD.
  This ensures consistent behavior regardless of which subdirectory the user
  runs commands from.
]
#requirement("fuzzy-name-matching", priority: "shall")[
  The `status` and `archive` commands SHALL perform @fuzzy-matching when a
  spec or change name is not found.

  The CLI SHALL collect all available names from the appropriate directory,
  compute @damlev edit distance against the user's input, and display
  the closest match when @fuzzy-matching is enabled (~67% similarity).

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
#requirement("added-body-from-source", priority: "shall")[
When building `DeltaOp` for an "added" requirement, the CLI SHALL extract
  the requirement's body from the change file's source text.

  Extraction SHALL find the `#requirement("id", ...)` call in the change file
  and capture everything inside its body content block `[...]`.

  Fallback to a TODO stub only when extraction fails (e.g., the source file
  was modified after compilation).

  #scenario("body extracted from change file",
    given: [change file has `#requirement("my-id", action: "added")[actual body #scenario(...)]`],
    when: [archive processes this requirement],
    then: [target spec receives `#requirement("my-id")[actual body #scenario(...)]`],
  )

  #scenario("fallback to TODO on extraction failure",
    given: [change file source cannot be read or parsed],
    when: [archive processes added requirement],
    then: [TODO stub inserted as before],
  )
]
#requirement("archive-routes-by-modifies", priority: "shall")[
The archive command SHALL use each requirement's `modifies` field to
  decide which spec file to apply the delta to.

  Requires are grouped by target spec, and each group is applied only to
  its corresponding spec file.

  #scenario("requirements routed to different specs",
    given: [change modifies ("cli", "config"), req-a targets "cli", req-b targets "config"],
    when: [archive runs],
    then: [req-a inserted into cli.typ only, req-b into config.typ only],
  )
]
#requirement("validation-requirement-in-change-modifies", priority: "shall")[
If a requirement specifies a spec in its `modifies` that is NOT listed in
  the change's top-level `modifies`, the archive SHALL produce an error
  listing the available specs from the change declaration.

  #scenario("requirement targets undeclared spec",
    given: [change modifies ("cli",), requirement modifies ("config")],
    when: [archive runs],
    then: [error: "'config' not in change modifies. Available: cli"],
  )
]
#requirement("validation-target-spec-exists", priority: "shall")[
If the target spec file for a requirement does not exist on disk, the
  archive SHALL error and suggest existing spec names using the "did you
  mean" @damlev heuristic.

  #scenario("target spec file missing",
    given: [typspec/specs/config.typ does not exist],
    when: [archive tries to apply delta to "config"],
    then: [error: "spec 'config' not found", with suggestion of closest existing spec],
  )
]
#requirement("archive-routes-by-modifies", priority: "shall")[
The archive command SHALL use each requirement's `modifies` field to
  decide which spec file to apply the delta to.

  Requires are grouped by target spec, and each group is applied only to
  its corresponding spec file.

  #scenario("requirements routed to different specs",
    given: [change modifies ("cli", "config"), req-a targets "cli", req-b targets "config"],
    when: [archive runs],
    then: [req-a inserted into cli.typ only, req-b into config.typ only],
  )
]
#requirement("validation-requirement-in-change-modifies", priority: "shall")[
If a requirement specifies a spec in its `modifies` that is NOT listed in
  the change's top-level `modifies`, the archive SHALL produce an error
  listing the available specs from the change declaration.

  #scenario("requirement targets undeclared spec",
    given: [change modifies ("cli",), requirement modifies ("config")],
    when: [archive runs],
    then: [error: "'config' not in change modifies. Available: cli"],
  )
]
#requirement("validation-target-spec-exists", priority: "shall")[
If the target spec file for a requirement does not exist on disk, the
  archive SHALL error and suggest existing spec names using the "did you
  mean" @damlev heuristic.

  #scenario("target spec file missing",
    given: [typspec/specs/config.typ does not exist],
    when: [archive tries to apply delta to "config"],
    then: [error: "spec 'config' not found", with suggestion of closest existing spec],
  )
]
#requirement("added-body-from-source", priority: "shall")[
When building `DeltaOp` for an "added" requirement, the CLI SHALL extract
  the requirement's body from the change file's source text.

  Extraction SHALL find the `#requirement("id", ...)` call in the change file
  and capture everything inside its body content block `[...]`.

  Fallback to a TODO stub only when extraction fails (e.g., the source file
  was modified after compilation).

  #scenario("body extracted from change file",
    given: [change file has `#requirement("my-id", action: "added")[actual body #scenario(...)]`],
    when: [archive processes this requirement],
    then: [target spec receives `#requirement("my-id")[actual body #scenario(...)]`],
  )

  #scenario("fallback to TODO on extraction failure",
    given: [change file source cannot be read or parsed],
    when: [archive processes added requirement],
    then: [TODO stub inserted as before],
  )
]
#requirement("added-body-from-source", priority: "shall")[
When building `DeltaOp` for an "added" requirement, the CLI SHALL extract
  the requirement's body from the change file's source text.

  Extraction SHALL find the `#requirement("id", ...)` call in the change file
  and capture everything inside its body content block `[...]`.

  Fallback to a TODO stub only when extraction fails (e.g., the source file
  was modified after compilation).

  #scenario("body extracted from change file",
    given: [change file has `#requirement("my-id", action: "added")[actual body #scenario(...)]`],
    when: [archive processes this requirement],
    then: [target spec receives `#requirement("my-id")[actual body #scenario(...)]`],
  )

  #scenario("fallback to TODO on extraction failure",
    given: [change file source cannot be read or parsed],
    when: [archive processes added requirement],
    then: [TODO stub inserted as before],
  )
]
#requirement("git-mv-for-tracked-files", priority: "shall")[
When archiving a change, the CLI SHALL use `git mv` to move the file
  if the change file is tracked by git. Otherwise, SHALL fall back to
  `std::fs::rename`.

  #scenario("change file is git-tracked",
    given: [change file is tracked by git],
    when: [archive runs],
    then: [`git mv` is used, file history preserved],
  )

  #scenario("change file is not git-tracked",
    given: [change file is untracked or not in a git repo],
    when: [archive runs],
    then: [`std::fs::rename` is used, same behavior as today],
  )

  #scenario("git command fails",
    given: [git is installed but `git mv` fails for some reason],
    when: [archive runs],
    then: [error is reported, archive continues with `fs::rename` as fallback],
  )
]
#requirement("cli-uses-configured-paths", priority: "shall")[
All CLI commands SHALL resolve spec, change, and archive directories from
  config rather than using hardcoded paths.

  The `init` command SHALL create directories at the configured paths.

  #scenario("init respects configured paths",
    given: [config with `paths.specs = "docs/specs"`],
    when: [`typspec init`],
    then: [creates `docs/specs/` instead of `typspec/specs/`],
  )

  #scenario("list reads from configured paths",
    given: [config with `paths.changes = "proposals"`],
    when: [`typspec list`],
    then: [reads from `proposals/` directory],
  )

  #scenario("archive uses configured archive dir",
    given: [config with `paths.archive = "completed"`],
    when: [`typspec archive my-change`],
    then: [change moved to `completed/`],
  )

  #scenario("status resolves from configured paths",
    given: [config with `paths.specs = "specs"`, same file exists],
    when: [`typspec status module-api`],
    then: [reads `specs/module-api.typ`],
  )
]
#requirement("init-tools-flag", priority: "shall")[
The `typspec init` command SHALL accept a `--tools` flag that accepts
  a comma-separated list of AI tool IDs. Supported tool IDs for the MVP:
  `claude`, `codex`, `opencode`.

  Passing `--tools all` SHALL select all supported tools.
  Passing `--tools none` SHALL skip skill generation entirely.
  Passing an invalid tool ID SHALL error with available options.

  #scenario("tools with valid IDs",
    when: [`typspec init --tools claude,codex`],
    then: [skills generated for Claude and CodEX],
  )

  #scenario("tools all",
    when: [`typspec init --tools all`],
    then: [skills generated for all supported tools],
  )

  #scenario("tools none",
    when: [`typspec init --tools none`],
    then: [init runs without generating any skills],
  )

  #scenario("tools invalid ID",
    when: [`typspec init --tools invalidtool`],
    then: [error with list of valid tool IDs],
  )
]
#requirement("skill-templates", priority: "shall")[
All four skill templates SHALL be updated to reflect current typspec
  behavior. Specific changes per template:

  *propose*: Reference `typspec list --specs` with paths, `typspec which`,
  canonical structure (`typspec/typspec.jsonc`, `typspec/specs/`, etc.),
  `#bibliography("typspec/bibliographies/...")` for citations. When no
  existing spec fits the change, prompt user to create a new spec with
  `typspec new spec <name>`.

  *explore*: Mention `typspec which` for finding files, `@fuzzy-matching`
  for name resolution, canonical directory layout.

  *apply*: Reference `typspec list` with paths, `typspec status` for
  task descriptions and paths.

  *archive*: Mention `typspec which` for finding archived changes,
  `typspec/bibliographies/` for references.
]
#requirement("attribution-comment", priority: "shall")[
Each generated SKILL.md file SHALL contain an attribution comment at the
  top indicating it was generated by typspec and inspired by OpenSpec:

  ```
  // Generated by typspec (https://github.com/ggallovalle/typspec)
  // Inspired by OpenSpec (https://github.com/Fission-AI/OpenSpec)
  ```

  This comment SHALL NOT appear in the rendered skill content visible to
  the AI — it SHALL be a markdown HTML comment (`<!-- ... -->`) so it's
  invisible when rendered.

  #scenario("attribution present",
    given: [a generated SKILL.md file],
    when: [inspecting the file source],
    then: [top of file contains `<!-- Generated by typspec...`],
  )
]
#requirement("mermaid-diagrams", priority: "shall")[
The `typspec-propose` and `typspec-explore` skill templates SHALL
  prefer Mermaid diagram syntax over ASCII art for structured diagrams
  (flowcharts, sequence diagrams, state machines).

  ASCII art is acceptable when the concept doesn't map to a standard
  Mermaid diagram type.

  #scenario("propose uses mermaid",
    given: [the propose skill describes a workflow],
    when: [rendering a flow],
    then: [uses ```mermaid flowchart LR ...``` instead of ASCII arrows],
  )

  #scenario("fallback to ascii",
    given: [a concept with no Mermaid equivalent],
    when: [rendering],
    then: [uses ASCII art as fallback],
  )
]
#requirement("cli-sets-root-for-bibliographies", priority: "shall")[
The CLI SHALL pass `--root` set to the config file's parent directory
  when invoking `typst compile` for rendering, validation, and queries.

  This ensures that bibliography paths like
  `typspec/bibliographies/file.yaml` resolve correctly from any spec,
  change, or archive document, regardless of their subdirectory.

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

#bibliography("../bibliographies/domain-language.yaml", style: "iso-690-numeric")
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
#requirement("which-command", priority: "shall")[
The CLI SHALL provide a `typspec which <name>` command that locates a
  file by name across specs, changes, and archive directories.

  Search order SHALL be: specs → changes → archive. The first match is
  returned. If no exact match is found, the CLI SHALL apply the same
  "did you mean" fuzzy matching used by `status` and `archive`
  (@damlev, ~67% threshold).

  #scenario("which finds a spec",
    when: [`typspec which module-api`],
    then: [outputs the full path like `typspec/specs/module-api.typ`],
  )

  #scenario("which finds an archived change",
    when: [`typspec which customizable-paths`],
    then: [outputs the path in archive directory],
  )

  #scenario("which with typo shows suggestion",
    when: [`typspec which modle-api`],
    then: [shows error + "tip: a similar name exists: 'module-api'"],
  )

  #scenario("which with no match and no close name errors",
    when: [`typspec which completely-unrelated`],
    then: [error without suggestion],
  )
]
#requirement("skill-updates-for-list", priority: "shall")[
The skill templates SHALL reference `typspec list` and `typspec list --specs`
  as showing file paths, e.g., `module-api (typspec/specs/module-api.typ)`.

  #scenario("propose skill references list with paths",
    when: [skill is rendered],
    then: [it tells AI to use `typspec list --specs` to find specs with their paths],
  )
]
#requirement("skill-references-which", priority: "shall")[
The skill templates SHALL reference `typspec which <name>` as the way to
  find the exact file path for a spec, change, or archived change.

  #scenario("archive skill references which",
    when: [skill is rendered],
    then: [it tells AI to use `typspec which <name>` to find archived changes],
  )
]
#requirement("single-source-skills", priority: "shall")[
Skill templates SHALL be sourced from the canonical `skills/typspec/`
  directory only. The `crates/cli/templates/` directory and `tera`
  dependency SHALL be removed.

  At compile time, each `SKILL.md` file from `skills/typspec/` SHALL be
  embedded via `include_str!()`. The YAML `metadata.generatedBy` field
  SHALL contain a `VERSION` marker that gets replaced with the crate
  version at generation time.

  #scenario("tera removed",
    when: [crate compiles],
    then: [no `tera` dependency, no `templates/` directory],
  )

  #scenario("skills embedded",
    when: [CLI runs `init --tools`],
    then: [skills written from embedded source, match `skills/` canonical forms],
  )

  #scenario("version injected",
    when: [skill is generated],
    then: [`metadata.generatedBy` matches the CLI version, not hardcoded],
  )
]
#requirement("cmd-usage", priority: "shall")[
The CLI SHALL provide a hidden `usage` subcommand that outputs a
  `.usage.kdl` format spec describing the full CLI.

  The spec SHALL include:
  - All commands, flags, and positional args
  - `complete` directives for dynamic value completion on `status`,
    `archive`, and `which` arguments
  - Hidden flags (`hide=#true`) for `--complete` on `list`

  #scenario("usage outputs valid KDL",
    when: [`typspec usage`],
    then: [output is valid usage KDL spec, parsable by `usage lint`],
  )

  #scenario("usage spec includes complete directives",
    when: [`typspec usage`],
    then: [spec contains `complete` for status/archive/which name args],
  )
]
#requirement("cmd-completion", priority: "shall")[
The CLI SHALL provide a `completion <shell>` subcommand that outputs a
  shell completion script for the given shell.

  The generated script SHALL:
  - Error with clear message if `usage` CLI is not installed
  - Cache the spec from `typspec usage` in `$TMPDIR`
  - Call `usage complete-word` to generate completions
  - Match mise's generated completion script structure exactly

  #scenario("completion zsh outputs valid script",
    when: [`typspec completion zsh > _typspec`],
    then: [script contains `#compdef typspec` and calls `usage complete-word`],
  )

  #scenario("completion errors without usage",
    when: [`usage` CLI is not installed, user sources completion script],
    then: [script prints error message instructing to install usage],
  )
]
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
