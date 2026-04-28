# typspec

A structured specification system powered by Typst. Define, manage, and render
software specifications as beautiful PDFs — with CLI tooling for AI-assisted
workflows.

## What is this?

typspec replaces the need for separate markdown-based spec systems (like
OpenSpec) with a unified approach:

- **Specs** as Typst documents — structured requirements, scenarios, and
  decisions rendered to PDF
- **Changes** as single Typst documents — proposal, design, spec-deltas, and
  tasks in one file
- **CLI** for project management — create, query, archive specs and changes
- **AI skills** for agent-assisted workflows — propose, apply, archive

## Repository Structure

```
/
├── crates/
│   ├── cli/          # typspec CLI (binary)
│   └── core/         # core library (crate integration)
├── typspec/          # Typst module (@preview/typspec)
├── .config/
│   └── typspec/      # this project's own config
├── LICENSE
└── README.md
```

## License

MIT — see LICENSE.
