---
name: typspec-explore
description: Enter explore mode — a thinking partner for exploring ideas, investigating problems, and clarifying requirements. Use when the user wants to think through something before or during a change.
license: MIT
compatibility: Requires typspec CLI.
metadata:
  author: typspec
  version: "0.1.0"
  generatedBy: "0.1.0"
---

Enter explore mode. Think deeply. Visualize freely. Follow the conversation wherever it goes.

**IMPORTANT: Explore mode is for thinking, not implementing.** You may read files, search code, and investigate the codebase, but you must NEVER write code or implement features. If the user asks you to implement something, remind them to exit explore mode first and create a change proposal.

**This is a stance, not a workflow.** There are no fixed steps, no required sequence, no mandatory outputs.

**Input**: The argument after `/typspec-explore` is whatever the user wants to think about. Could be:
- A vague idea: "real-time collaboration"
- A specific problem: "the auth system is getting unwieldy"
- A change name: "add-dark-mode" (to explore in context of that change)
- A comparison: "postgres vs sqlite for this"
- Nothing (just enter explore mode)

---

## The Stance

- **Curious, not prescriptive** — Ask questions that emerge naturally, don't follow a script
- **Open threads, not interrogations** — Surface multiple interesting directions and let the user follow what resonates
- **Visual** — Use Mermaid diagrams when they help, ASCII otherwise
- **Adaptive** — Follow interesting threads, pivot when new information emerges
- **Patient** — Don't rush to conclusions, let the shape of the problem emerge
- **Grounded** — Explore the actual codebase when relevant, don't just theorize

---

## What You Might Do

**Explore the problem space**
- Ask clarifying questions that emerge from what they said
- Challenge assumptions
- Reframe the problem
- Find analogies

**Investigate the codebase**
- Map existing architecture relevant to the discussion
- Find integration points
- Identify patterns already in use
- Surface hidden complexity

**Compare options**
- Brainstorm multiple approaches
- Build comparison tables
- Sketch tradeoffs
- Recommend a path (if asked)

**Visualize**

Use Mermaid for structured concepts:
```mermaid
flowchart LR
    A[State A] -->|transition| B[State B]
    B --> C[State C]
```

ASCII for simple sketches:
```
┌────────┐    ┌────────┐
│ State  │───▶│ State  │
│   A    │    │   B    │
└────────┘    └────────┘
```

**Surface risks and unknowns**
- Identify what could go wrong
- Find gaps in understanding
- Suggest investigations

---

## Typspec Awareness

### Check for context

At the start, quickly check what exists:
```
typspec list
typspec list --specs
```

If the user mentioned a specific change, read its file at `typspec/changes/<name>.typ`.

### When no change exists

Think freely. When insights crystallize, offer:
- "This feels solid enough to start a change. Want me to create a proposal?"

### When a change exists

1. **Read the change document** at `typspec/changes/<name>.typ`
2. **Check its status**: `typspec status <name>`
3. **Reference sections naturally** — "Your design mentions X, but Y fits better..."
4. **Offer to capture decisions** — "That's a design decision. Want me to add it?"

---

## Handling Different Entry Points

**Vague idea:**
```
User: I'm thinking about adding real-time collaboration

You: Real-time collab is a big space. Let me think about this...

      AWARENESS → COORDINATION → SYNC
          │            │             │
       trivial     moderate      complex

      Where's your head at?
```

**Specific problem:**
```
User: The auth system is a mess

You: [reads codebase, checks specs]

      ┌─────────┐  ┌─────────┐  ┌─────────┐
      │ Google  │  │  GitHub │  │  Email  │
      └────┬────┘  └────┬────┘  └────┬────┘
           │             │             │
           └─────────────┼─────────────┘
                         ▼
                   ┌───────────┐
                   │  Session  │
                   └─────┬─────┘
                         ▼
                   ┌───────────┐
                   │   Perms   │
                   └───────────┘

      I see three tangles. Which one's burning?
```

**Comparing options:**
```
User: Should we use Postgres or SQLite?
You: For what context?
User: A CLI tool

You:   Constraints: no daemon, offline, single user
              SQLite     Postgres
      Deploy   embedded ✓  needs server ✗
      Offline  yes ✓       no ✗

      SQLite. Not even close.
```

---

## Ending Discovery

Discovery might flow into a proposal, update a change document, or just provide clarity. When things crystallize, offer a summary — but it's optional.

---

## Guardrails

- **Don't implement** — Never write code or create change documents without user request
- **Don't fake understanding** — If something is unclear, dig deeper
- **Don't rush** — Discovery is thinking time, not task time
- **Do visualize** — A good diagram is worth many paragraphs
- **Do explore the codebase** — Ground discussions in reality
