#import "../src/lib.typ": spec, requirement, scenario, decision

#show: spec.with(title: "Typspec Publishing")

= Typspec Publishing Specification

This document specifies how typspec skills are packaged and published
for installation via tools like `skills.sh` and Claude Code plugins.

== Plugin Manifest

#requirement("plugin-json", priority: "shall")[
  The repository SHALL contain a `.claude-plugin/plugin.json` file at the
  root that declares the plugin name and lists all available skills.

  ```json
  {
    "name": "typspec-skills",
    "skills": [
      "./skills/typspec/typspec-propose/SKILL.md",
      "./skills/typspec/typspec-explore/SKILL.md",
      "./skills/typspec/typspec-apply/SKILL.md",
      "./skills/typspec/typspec-archive/SKILL.md"
    ]
  }
  ```

  #scenario("plugin.json exists",
    when: [repository is scanned],
    then: [`.claude-plugin/plugin.json` is present with valid JSON],
  )

  #scenario("all skills listed",
    when: [plugin.json is parsed],
    then: [all published skills are listed in the `skills` array],
  )
]

== Skill Directory Structure

#requirement("skill-directory-structure", priority: "shall")[
  Published skills SHALL live at `skills/typspec-<workflow>/SKILL.md`.

  ```
  skills/
    typspec-propose/SKILL.md
    typspec-explore/SKILL.md
    typspec-apply/SKILL.md
    typspec-archive/SKILL.md
  ```

  This mirrors the convention used by `skills.sh` and the mattpocock/skills
  repository. Each skill is a single `SKILL.md` file with YAML frontmatter.

  #scenario("skills dir structure",
    when: [repository is published],
    then: [`skills/typspec-propose/SKILL.md` exists with frontmatter],
  )
]

== YAML Frontmatter

#requirement("skill-frontmatter", priority: "shall")[
  Each `SKILL.md` SHALL have YAML frontmatter with at minimum `name` and
  `description`. The name should be short and descriptive. The description
  should be thorough enough for skills.sh to display meaningfully.

  ```yaml
  ---
  name: typspec-propose
  description: Propose a new change with all artifacts generated in one step...
  ---
  ```

  The description SHALL be the same as the one used in the `.agents/skills/`
  generated versions.

  #scenario("frontmatter has name and description",
    when: [skill is loaded by skills.sh],
    then: [name and description are displayed],
  )
]

== Relationship to Generated Skills

#requirement("published-vs-generated", priority: "should")[
  The published skills under `skills/typspec/` SHALL be the canonical source
  of truth. The `typspec init --tools` command SHALL copy or reference these
  files when generating per-tool skills under `.agents/skills/` or
  `.claude/skills/`.

  The published skills serve as:
  - The installable package for `skills.sh` and Claude Code plugins
  - The template source for `typspec init --tools`
  - A reference for users who want to inspect skills before installing

  #scenario("published skills match generated",
    when: [`typspec init --tools claude` generates skills],
    then: [the generated `.claude/skills/` files match `skills/typspec/`],
  )
]

#bibliography("../bibliographies/domain-language.yaml", style: "iso-690-numeric")
