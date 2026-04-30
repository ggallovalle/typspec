#import "../src/lib.typ": spec, requirement, scenario
#import "../links.typ"
#import "../glossary.typ"

#show: glossary.glossary
#show: spec.with(title: "Typspec Archive")

= Typspec Archive Specification

This document specifies the behavior of the `typspec archive` command.
For the command's CLI interface (name, args, flags, exit codes), see
#links.spec-cli.

== Archive Operation

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

== Validation

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

== File Management

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

