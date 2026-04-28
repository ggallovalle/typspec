// typspec — Typst module for structured specifications.

// ── Internal state ─────────────────────────────
#let __scenario-count = state("typspec:scenario-count", 0)

// ── Document templates ─────────────────────────

#let spec(it, title: none, bibliography: none) = {
  set document(title: title)
  show: doc => page(margin: (x: 2.5cm, y: 2cm), doc)
  set heading(numbering: "1.1")
  set text(size: 11pt)
  if bibliography != none {
    let bs = if type(bibliography) == "array" {
      bibliography
    } else {
      (bibliography,)
    }
    for b in bs {
      bibliography(b, style: "iso-690-numeric")
    }
  }
  it
}

#let change(it, id: none, title: none, modifies: none) = {
  set document(title: title)
  show: doc => page(margin: (x: 2.5cm, y: 2cm), doc)
  set heading(numbering: "1.1")
  set text(size: 11pt)
  metadata((kind: "typspec:change", id: id, modifies: modifies))
  it
}

// ── Requirements ───────────────────────────────

#let requirement(id, priority: "shall", action: none, modifies: none, body) = {
  metadata((kind: "typspec:requirement", id: id, priority: priority, action: action, modifies: modifies))
  heading(level: 2, numbering: "1.", id)
  body
  v(0.5em)
}

// ── Scenarios ──────────────────────────────────

#let scenario(name, when: none, then: none, given: none) = {
  __scenario-count.update(x => x + 1)
  let n = context __scenario-count.get()
  metadata((kind: "typspec:scenario", name: name))
  block(
    inset: 8pt,
    fill: luma(245),
    radius: 4pt,
    [
      *Scenario #n:* #name \
      #if given != none [#linebreak() *GIVEN* #given \
      ]
      *WHEN* #when \
      *THEN* #then
    ],
  )
  v(0.3em)
}

// ── Decisions ──────────────────────────────────

#let decision(title, rationale: none, alternatives: none) = {
  metadata((kind: "typspec:decision", title: title))
  heading(level: 3, title)
  [*Rationale:* #rationale]
  if alternatives != none {
    parbreak()
    [*Alternatives considered:* #alternatives]
  }
  v(0.5em)
}

// ── Tasks ──────────────────────────────────────

#let task(body, done: false, assignee: none, labels: none, refs: none) = {
  metadata((kind: "typspec:task", done: done, assignee: assignee, labels: labels, refs: refs))
  let marker = if done { "[x]" } else { "[ ]" }
  box(width: 1em, align(left, text(marker)))
  body
  linebreak()
}

#let task_group(name, tasks) = {
  metadata((kind: "typspec:task-group", name: name))
  heading(level: 2, name)
  tasks.join([])
}
