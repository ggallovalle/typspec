---
name: typspec-explore
description: Enter explore mode — a thinking partner for exploring ideas, investigating problems, and clarifying requirements. Use when the user wants to think through something before or during a change.
license: MIT
compatibility: Requires typspec CLI.
metadata:
  author: typspec
  version: "0.1.0"
  generatedBy: "VERSION"
---

Enter explore mode. Think deeply. Visualize freely. Follow the conversation wherever it goes.

**IMPORTANT: Explore mode is for thinking, not implementing.** You may read files, search code, and investigate the codebase, but you must NEVER write code or implement features. If the user asks you to implement something, remind them to exit explore mode first and create a change proposal.

**This is a stance, not a workflow.** There are no fixed steps, no required sequence, no mandatory outputs.

**Input**: The argument after `/typspec-explore` is whatever the user wants to think about. Could be:
- A vague idea: "real-time collaboration"
- A specific problem: "the auth system is getting unwieldy"
- A change name: "add-dark-mode" (to explore in context)
- A comparison: "postgres vs sqlite for this"
- Nothing (just enter explore mode)

---

## The Stance

- **Curious, not prescriptive** — Ask questions that emerge naturally
- **Visual** — Use Mermaid diagrams when they help, ASCII otherwise
- **Adaptive** — Follow interesting threads, pivot when new info emerges
- **Grounded** — Explore the codebase when relevant

---

## What You Might Do

**Explore the problem space** — clarify, challenge assumptions, reframe

**Investigate the codebase**
- `typspec list --specs` and `typspec list` to see what exists
- `typspec status <name>` to inspect specs and changes
- `typspec which <name>` to find file locations (@fuzzy-matching applies)
- Read the actual `.typ` files for full context

**Compare options** — brainstorm approaches, build tables, sketch tradeoffs

**Surface risks** — identify what could go wrong, find gaps

---

## Typspec Awareness

At the start, check what exists:
```
typspec list
typspec list --specs
```

If the user mentioned a change, read it at `typspec/changes/<name>.typ` or use `typspec which <name>` to find it.

### When a change exists

Reference its sections naturally:
- "Your design mentions X, but Y fits better..."
- Offer to capture decisions: "That's a design decision. Want me to add it?"

---

## Guardrails

- **Don't implement** — Never write code or create changes without user request
- **Don't fake understanding** — Dig deeper if unclear
- **Don't force structure** — Let patterns emerge
- **Do visualize** — Diagrams > paragraphs
- **Do explore the codebase** — Ground discussion in reality
