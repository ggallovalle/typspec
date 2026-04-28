#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "git-mv-archive", modifies: ("cli",))

= Proposal

== Motivation

When archiving a change, the CLI uses `std::fs::rename()` to move the file
from `typspec/changes/` to `typspec/archive/`. This breaks git history — the
file appears as deleted in one directory and added in another, with no
connection between the two.

Using `git mv` instead preserves the file's history: `git log --follow`
can trace the change file across the move, and blame/annotations remain
intact.

The switch should be conditional — only use `git mv` when the file is
tracked by git. Fall back to `std::fs::rename` when the file is not in a
git repository or is untracked.

== Scope

In scope:
- Replace `std::fs::rename` with `git mv` in `cmd_archive`
- Check if change file is tracked by git before using `git mv`
- Fall back to `std::fs::rename` when not in a git repo
- Update the `archive` command spec accordingly

Out of scope:
- `git mv` for spec file modifications (those are content changes, not moves)
- Handling nested git repos or submodules

= Design

#decision(
  "Conditional git mv — check if file is git-tracked first",
  rationale: [
    `git mv` only works on tracked files in a git repository. Running it on
    untracked files or outside git repos will error. A simple check via
    `git ls-files --error-unmatch <file>` tells us if the file is tracked.
    If tracked, use `git mv`. Otherwise, fall back to `fs::rename`.
  ],
  alternatives: [
    - Always use `git mv`: fails on untracked files or non-git directories.
    - Always use `fs::rename` (current): loses history.
    - Use `git mv` and catch errors, fall back: leaves error messages in output.
  ],
)

#decision(
  "Check via `git ls-files --error-unmatch`",
  rationale: [
    Quiet check — exits 0 if tracked, 1 if not. No output, just exit code.
    Faster than parsing `git status` or `git log`.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("git-mv-for-tracked-files", priority: "should", action: "added", modifies: "cli")[
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

= Tasks

#task_group("1. Implementation", (
  task([Add git-tracked check using `git ls-files --error-unmatch`], done: false, labels: ("cli",)),
  task([Replace `fs::rename` with conditional `git mv` / `fs::rename`], done: false, labels: ("cli",)),
  task([Add error fallback when git command fails], done: false, labels: ("cli",)),
))

#task_group("2. Tests", (
  task([Test archive with git-tracked change file], done: false, labels: ("tests",)),
  task([Test archive with untracked change file], done: false, labels: ("tests",)),
  task([Test archive outside git repository], done: false, labels: ("tests",)),
))

#task_group("3. Documentation", (
  task([Update CLI spec with git mv scenarios], done: false, labels: ("docs",)),
))
