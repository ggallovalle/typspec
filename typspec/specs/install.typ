#import "../src/lib.typ": spec, requirement, scenario
#import "../links.typ"
#import "../glossary.typ"

#show: glossary.glossary
#show: spec.with(title: "Typspec Install")

= Typspec Install Specification

This document specifies the behavior of the `typspec install` command.
For the command's CLI interface (name, args, flags, exit codes), see
#links.spec-cli.

== Workspace Dependencies

#requirement("install-git-workspace", priority: "should")[
  The install command SHALL fetch workspace dependencies declared in
  `typspec.jsonc` workspaces.

  For `git`-based workspaces, the command SHALL clone the repository at
  the specified ref (`tag` or `commit`) into a local cache.

  #scenario("install git workspace",
    given: [config with `git` workspace entry and `tag`],
    when: [`typspec install`],
    then: [repository cloned at specified tag into `.typspec/cache/`],
  )
]
