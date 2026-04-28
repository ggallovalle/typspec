---
name: typspec-propose
description: Propose a new change with all artifacts generated in one step. Use when the user wants to quickly describe what they want to build and get a complete change document with proposal, design, spec-deltas, and tasks ready for implementation.
license: MIT
compatibility: Requires typspec CLI.
metadata:
  author: typspec
  version: "0.1.0"
  generatedBy: "0.1.0"
---

Propose a new change — create a change document with all sections in one step.

I'll create a change with:
- Proposal (why & what)
- Design decisions (how)
- Spec-deltas (requirements with scenarios)
- Tasks (implementation checklist)

When ready to implement, run `/typspec-apply`.

---

**Input**: The argument after `/typspec-propose` is the change name OR a description of what the user wants to build.

**Steps**

1. **If no clear input provided, ask what they want to build**

   Use the **AskUserQuestion tool** to ask:
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add dark mode" → `add-dark-mode`).

   **Do NOT proceed without understanding what the user wants to build.**

2. **Discover what exists**
   ```
   typspec list --specs
   typspec list
   ```
   This shows existing specs with their file paths. Use `typspec which <name>` to find a file's exact location.

3. **Evaluate spec fit**

   If the change doesn't logically fit any existing spec, explain to the user:
   > "The scope of this change doesn't align with any existing specs. We need a new spec to define this domain."

   Then prompt: `typspec new spec <name>` to create it before proceeding.

4. **Create the change file**
   ```
   typspec new change <name>
   ```
   This creates a scaffolded `.typ` file at `typspec/changes/<name>.typ`.

5. **Fill the change document**

   The change document is a single `.typ` file. Fill in these sections:

   **Proposal section:**
   - Motivation — why this change is needed
   - Scope — what's in and out of scope

   **Design section:**
   - Use `#decision("Title", rationale: [...], alternatives: [...])` blocks

   **Spec-deltas section:**
   - `#requirement("id", action: "added")[body #scenario(...)]` for new requirements
   - `#requirement("id", action: "modified")[body]` for changed requirements
   - `#requirement("id", action: "removed")[body]` for removed requirements
   - Add `modifies: "spec-name"` if the change targets a specific spec
   - If change modifies multiple specs, each requirement MUST have `modifies:` set

   **Tasks section:**
   - `#task_group("Group", (task([Description], done: false), ...))`
   - Add `assignee: "ai"` or `assignee: "human"` for responsibility
   - Add `labels: ("label",)` for filtering
   - Add `refs: ("url",)` for external references

6. **Set the change's `modifies`**
   - `#show: change.with(id: "<name>", modifies: ("spec-a", "spec-b"))`

7. **Add bibliography for citations**
   - At the end: `#bibliography("typspec/bibliographies/domain-language.yaml", style: "iso-690-numeric")`
   - Use `@fuzzy-matching` and `@damlev` for fuzzy matching references

8. **Verify it compiles**
   ```
   typspec validate typspec/changes/<name>.typ
   ```

9. **Show a summary**

   After completing, summarize:
   - Change name and location
   - Count of requirements, scenarios, decisions, tasks
   - "Ready for implementation. Run `/typspec-apply` or ask me to implement."

**Guardrails**

- Create ALL sections of the change document — not just the proposal
- If change doesn't fit existing specs, explain and prompt for a new spec
- If change modifies multiple specs, each requirement MUST have `modifies:` set
- Always verify the file compiles after writing
