#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "cli-publishing", modifies: ("publishing",))

= Proposal

== Motivation

The `typspec` CLI currently lives in a workspace with two crates: `typspec`
(the binary) and `typspec-core` (the library). This prevents publishing
to crates.io because:

1. Path dependencies must be resolved — `typspec-core` isn't published
2. No crate metadata (license, repository URL)
3. The binary's embedded skill files (`include_str!`) reference paths
   relative to the workspace root — need to verify these survive
   packaging

Users should be able to install via:
- `cargo install typspec`
- `cargo binstall typspec` (pre-built binary)
- `mise use cargo:typspec` or `mise use cargo-binstall:typspec`

Note: README overhaul is handled by a separate change targeting the `docs` spec.

== Scope

In scope:
- Merge `typspec-core` into the CLI crate (absorb as internal modules)
- Add missing Cargo.toml metadata (license, repository, homepage, keywords)
- Remove `crates/core/` directory, update workspace members
- GitHub Actions CI: test on push/PR, build binaries on tag
- GitHub Releases with binary assets for `cargo binstall` support
- `mise run publish` task for the release workflow
- Version tag convention (`v0.1.0`, `v0.2.0`, etc.)

Out of scope:
- Publishing `typspec-core` separately (it's internal forever)
- Setting up docs.rs or documentation site
- Creating a `typspec-cli` crate alias or rename

= Design

#decision(
  "Merge core into CLI crate, keep workspace root clean",
  rationale: [
    The `typspec-core` crate is 939 lines across 5 files — trivially
    small. Absorbing it into `crates/cli/src/` removes the only
    workspace-internal path dependency, simplifies publishing, and
    keeps the repo structure open for future additions like
    `apps/docs`.

    All `typspec_core::` imports in main.rs become `crate::` imports.
    The internal module structure stays exactly as-is, just moved via
    `git mv` for history preservation.
  ],
  alternatives: [
    - Publish both crates: unnecessary public API surface, two
      `cargo publish` commands per release.
    - Single crate at repo root src/: conflicts with future apps/ dir.
  ],
)

#decision(
  "GitHub Actions: test, build binaries, publish",
  rationale: [
    For `cargo install`: just publish to crates.io on tag.

    For `cargo binstall`: the tool looks up the crate on crates.io,
    finds the GitHub Release, and downloads a pre-built binary. The
    release needs assets named `<crate>-<version>-<target>.tar.gz`.
    The CI builds these on tag push and uploads via `gh release`.

    CI commands are delegated to mise tasks (`mise run ci-test`,
    `mise run ci-build`, etc.) so the workflow YAML stays minimal
    and the same commands work locally. The workflow runs
    `mise run ci-test` on every push/PR. On a `v*` tag, it
    additionally builds release binaries for linux, macos, and
    windows, creates a GitHub Release, uploads assets, and publishes
    to crates.io.
  ],
  alternatives: [
    - cargo-dist: full automation but complex setup for first release.
    - Manual binary upload: error-prone, no CI guard rails.
  ],
)

#decision(
  "0.1.0 for first publish, v0.x.y for pre-release",
  rationale: [
    Semantic versioning: 0.x means API is unstable, which is honest
    for a CLI in active development. 1.0.0 comes when the CLI is
    stable enough to commit to backwards compat.

    Tags follow the `v` prefix convention: `v0.1.0`, `v0.2.0`, etc.
  ],
  alternatives: [],
)

= Spec Deltas

== ADDED Requirements

#requirement("crate-publishing", priority: "shall", action: "added", modifies: "publishing")[
  The `typspec` CLI crate SHALL be published to crates.io so users can
  install via `cargo install typspec`.

  The crate SHALL be a single crate (no internal path dependencies).
  The Cargo.toml SHALL include `license`, `repository`, `homepage`,
  `keywords`, and `categories` for crates.io discoverability.

  GitHub Releases SHALL attach pre-built binaries for `cargo binstall`
  support. Binary assets SHALL follow the naming convention
  `<crate>-<version>-<target-triple>.tar.gz`.

  The repository SHALL maintain a GitHub Actions workflow that:
  - Runs `mise run ci-test` on every push and pull request
  - On a `v`-prefixed git tag: runs `mise run ci-release` which
    builds release binaries, creates a GitHub Release, publishes
    to crates.io

  The workflow SHALL delegate to `mise run ci-*` tasks rather than
  inlining cargo commands, so the same commands work locally.

  Version tags SHALL follow the `v<semver>` pattern (e.g., `v0.1.0`).

  #scenario("cargo publish dry-run passes",
    when: [`cargo publish --dry-run` runs],
    then: [no warnings about missing metadata or path dependencies],
  )

  #scenario("README has install instructions",
    when: [README.md is examined],
    then: [cargo install, cargo binstall, and mise install methods documented],
  )

  #scenario("GitHub Release has binaries",
    given: [a `v*` tag is pushed],
    when: [GitHub Actions finishes],
    then: [release has .tar.gz assets for linux, macos, and windows targets],
  )

  #scenario("CI publishes to crates.io",
    given: [a `v*` tag is pushed],
    when: [GitHub Actions runs],
    then: [crate is published to crates.io],
  )

  #scenario("CI runs tests on push",
    when: [a push or PR is made],
    then: [GitHub Actions runs `mise run ci-test`],
  )
]

#requirement("readme-install-instructions", priority: "should", action: "added", modifies: "docs")[
  Documented in the `docs` spec change.
]

== REMOVED Requirements

#requirement("published-vs-generated", priority: "should", action: "removed", modifies: "publishing")[
  Replaced by `crate-publishing`. The publishing spec now covers crate
  publishing as the primary distribution mechanism. Skills are embedded
  in the crate via `include_str!()` — they're no longer distributed
  as a separate skills.sh package.
]

= Tasks

#task_group("1. Merge core into CLI crate", (
  task([git mv crates/core/src/ crates/cli/src/core/], done: true, labels: ("cli",)),
  task([Remove typspec-core path dep from cli/Cargo.toml, absorb its deps], done: true, labels: ("cli",)),
  task([Update workspace members: remove typspec-core from root Cargo.toml], done: true, labels: ("build",)),
  task([Replace all typspec_core:: with crate:: in main.rs], done: true, labels: ("cli",)),
  task([Delete crates/core/ directory], done: true, labels: ("build",)),
))

#task_group("2. Fix publish readiness", (
  task([Add license, repository, homepage, keywords, categories to Cargo.toml], done: true, labels: ("build",)),
  task([Verify cargo publish --dry-run passes with no warnings], done: true, labels: ("tests",)),
  task([Run cargo build with no warnings], done: true, labels: ("tests",)),
))

#task_group("3. Set up CI and mise tasks", (
  task([Create mise tasks: ci-test, ci-build, ci-release, and publish], done: true, labels: ("build",)),
  task([Create .github/workflows/ci.yml calling mise run ci-test / ci-release], done: true, labels: ("ci",)),
  task([Add CARGO_REGISTRY_TOKEN secret setup instructions], done: true, labels: ("docs",)),
))

