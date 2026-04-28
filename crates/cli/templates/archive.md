---
name: typspec-archive
description: Archive a completed change. Merges spec-deltas into target specs via AST surgery, then moves the change file to the archive directory. Checks for git conflicts before merging.
license: MIT
compatibility: Requires typspec CLI.
metadata:
  author: typspec
  version: "0.1.0"
  generatedBy: "0.1.0"
---

Archive a completed change. Merges spec-deltas into target specs via AST
surgery, then moves the change file to the archive directory.

---

**Input**: The argument after `/typspec-archive` is the change name. If not
provided, infer from context.

**Steps**

1. **Verify all tasks are complete**
   ```
   typspec status <name>
   ```
   If tasks remain incomplete, warn the user but offer to proceed.

2. **Read the change document** for full context
   - What specs does it modify? (check `modifies` list)
   - What requirements are being added/modified/removed? (check `action:`)

3. **Run the archive command**
   ```
   typspec archive <name>
   ```
   This:
   - Compiles the change file and queries for spec-delta metadata
   - Extracts full requirement bodies from the change source
   - Applies ADDED/MODIFIED/REMOVED deltas to target spec files
   - Checks for git conflicts (uncommitted spec changes)
   - Moves the change to `typspec/archive/YYYY-MM-DD-<name>.typ`

4. **Verify specs still compile**
   ```
   typspec validate typspec/specs/<spec>.typ
   ```

5. **Commit the changes**
   ```
   git add -A && git commit -m "feat: implemented <change>"
   ```

**Guardrails**

- Run `typspec status <name>` first to check task completion
- If spec files have uncommitted changes, archive will warn but proceed
- Archived changes are preserved — use `typspec status` on them to see metadata
