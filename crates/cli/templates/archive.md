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

**Finding archived changes**

Use `typspec which <name>` to find archived changes by name
(@fuzzy-matching applies). Archived changes are preserved with their
full metadata — use `typspec status <name>` on them to inspect.

**Bibliography references**

Add `#bibliography("typspec/bibliographies/domain-language.yaml", style: "iso-690-numeric")`
at the end of spec documents to resolve `@fuzzy-matching` and `@damlev`
citations. The CLI passes `--root` so paths resolve from the project root.
