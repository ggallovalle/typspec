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
The `status` and `archive` commands SHALL perform fuzzy matching when a
  spec or change name is not found.

  The CLI SHALL collect all available names from the appropriate directory,
  compute @damlev edit distance against the user's input, and display
  the closest match when the similarity exceeds approximately 67%.

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
Skill templates SHALL be Tera templates embedded in the CLI binary.

  Each template SHALL generate a `SKILL.md` file in the tool's skills
  directory (e.g., `.claude/skills/typspec-propose/SKILL.md`).

  Templates SHALL reference the `typspec` CLI for all operations.

  The following skills SHALL be generated for each selected tool:

  - `typspec-propose` — guides the AI through creating a change document
  - `typspec-explore` — explore mode for thinking through ideas
  - `typspec-apply` — implement tasks from a change
  - `typspec-archive` — archive a completed change

  Each skill SHALL include YAML frontmatter with:
  - `name`: the skill name
  - `description`: what the skill does
  - `compatibility`: requires typspec CLI

  #scenario("skill file structure",
    given: [tool `claude` is selected],
    when: [init generates skills],
    then: [
      `.claude/skills/typspec-propose/SKILL.md` exists,
      `.claude/skills/typspec-explore/SKILL.md` exists,
      `.claude/skills/typspec-apply/SKILL.md` exists,
      `.claude/skills/typspec-archive/SKILL.md` exists,
    ],
  )

  #scenario("skill content references typspec CLI",
    given: [a generated SKILL.md file],
    when: [AI reads it],
    then: [it references `typspec list`, `typspec new`, `typspec status`, etc.],
  )
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
