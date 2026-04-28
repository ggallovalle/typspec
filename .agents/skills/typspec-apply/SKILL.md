---
name: typspec-apply
description: Implement tasks from a change document. Works through the task list in typspec/changes/<name>.typ, writing code and checking off items. Can resume where left off if interrupted.
license: MIT
compatibility: Requires typspec CLI.
metadata:
  author: typspec
  version: "0.1.0"
  generatedBy: "0.1.0"
---

Implement tasks from a change document. Works through the task list, writing
code and checking off items.

---

**Input**: The argument after `/typspec-apply` is the change name. If not provided, infer from context.

**Steps**

1. **Identify the change to implement**
   ```
   typspec list
   ```
   If no change specified and multiple exist, ask which one.

2. **Read the change document**
   ```
   typspec status <name> --json
   ```
   This gives you requirements, scenarios, decisions, and tasks with
   completion status. Also read the full file at `typspec/changes/<name>.typ`.

3. **Understand what needs to be done**
   - Check the proposal for motivation and scope
   - Read the design decisions for rationale
   - Check the spec-deltas for what requirements change
   - Task `done: false` items are what needs implementing

4. **Work through tasks one by one**

   Use the **TodoWrite tool** to track progress through the tasks.

   For each task:
   - Read any context needed (existing code, specs, etc.)
   - Implement the required changes
   - Mark the task as `done: true` in the change file

5. **Verify after each task**
   ```
   typspec validate typspec/changes/<name>.typ
   ```
   Also run any relevant project tests.

6. **Check final status**
   ```
   typspec status <name>
   ```

**Output**

When all tasks complete:
- "All tasks complete. Run `/typspec-archive <name>` to archive."

If some remain: "X/Y tasks complete. Continue with `/typspec-apply`."

**Resuming**

Can resume where left off — task completion is tracked in the `.typ` file's
`done:` field. Just re-run `typspec status <name>` to see what's left.
