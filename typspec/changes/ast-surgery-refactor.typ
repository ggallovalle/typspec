#import "../src/lib.typ": change, decision, requirement, scenario, task, task_group

#show: change.with(id: "ast-surgery-refactor", modifies: ("core", "cli"))

= Proposal

== Motivation

The `surgery.rs` module uses string-based heuristics to find and extract
requirement nodes from Typst syntax trees:

- `find_matching_op` calls `node.into_text()` and searches for `"requirement(\"id\""` as a substring
- `extract_body_from_node` searches for `(` and `)` by character position in the serialized text
- Both manually track bracket/paren depth instead of using the typed AST

This is fragile. Nested strings, escaped quotes, or unusual formatting can
break the matching. The `typst_syntax` crate provides a fully typed AST
(`ast::FuncCall`, `ast::Ident`, `ast::Args`, `ast::Expr`) that should be
used instead.

The behavior after the refactor must stay identical — same matching, same
body extraction, same tree manipulation. Only the implementation changes.

== Scope

In scope:
- Replace string matching in `find_matching_op` with typed AST traversal
- Replace string matching in `extract_body_from_node` with typed AST traversal
- Both functions must produce identical output for all current inputs
- All existing tests must pass unchanged

Out of scope:
- Changing the tree manipulation logic (apply_ops stays as-is)
- Adding new functionality
- Performance optimization beyond removing string allocations

= Design

#decision(
  "Use `ast::FuncCall::from_untyped` to identify requirement calls",
  rationale: [
    Instead of serializing the node to text and searching for substring
    `requirement("id"`, cast the node to `ast::FuncCall`, get its callee
    as `ast::Ident`, and check the identifier name directly. This is
    type-safe, handles all formatting variants (extra spaces, line breaks),
    and avoids string allocation.
  ],
  alternatives: [
    - Current string matching: fragile, breaks on formatting changes.
    - Regex on serialized text: still string-based, adds dependency.
  ],
)

#decision(
  "Use `ast::Args` to find the positional `id` argument and body block",
  rationale: [
    `ast::FuncCall::args()` returns an `ast::Args` iterator. The first
    positional argument is the requirement ID (a string). The last argument
    is the body content block. Traversing this via AST is precise and
    avoids manual bracket-depth tracking.
  ],
  alternatives: [
    - Current paren-depth tracking: duplicates the parser's work.
    - Searching for the body `[` after `)`: wrong on nested calls.
  ],
)

= Spec Deltas

== ADDED Requirements

#requirement("find-matching-op-uses-ast", priority: "shall", action: "added", modifies: "core")[
  The `find_matching_op` function SHALL use `ast::FuncCall::from_untyped`
  to identify requirement calls, and `ast::Ident` to check the callee name.

  To extract the requirement ID, it SHALL traverse `ast::FuncCall::args()`
  and inspect the first positional argument as `ast::Expr::Str`.

  #scenario("matching with extra whitespace",
    given: [a requirement call with extra spaces: `#requirement(  "id",  priority: "shall")[...]`],
    when: [find_matching_op runs],
    then: [correctly matches the requirement by ID],
  )

  #scenario("matching with single quotes",
    given: [a requirement call: `#requirement('id', priority: 'shall')[...]`],
    when: [find_matching_op runs],
    then: [correctly matches the requirement by ID],
  )

  #scenario("matching with multiline args",
    given: [a requirement call with line breaks between arguments],
    when: [find_matching_op runs],
    then: [correctly matches the requirement by ID],
  )
]

#requirement("extract-body-uses-ast", priority: "shall", action: "added", modifies: "core")[
  The `extract_body_from_node` function SHALL use `ast::FuncCall` and its
  child nodes to find the requirement body content block, instead of
  searching for `[` and `]` by character position in serialized text.

  It SHALL locate the body content block `[...]` as the last content child
  of the `FuncCall` node and serialize it back via `into_text()`.

  #scenario("body extraction with nested brackets",
    given: [a requirement body containing nested `[` and `]` characters],
    when: [extract_body_from_node runs],
    then: [correctly extracts the full body without truncation],
  )

  #scenario("body extraction with scenarios",
    given: [a requirement body with `#scenario(when: [...], then: [...])`],
    when: [extract_body_from_node runs],
    then: [all scenario content is included in the extracted body],
  )

  #scenario("body extraction no match",
    given: [a syntax tree without the target requirement ID],
    when: [extract_body_from_node runs],
    then: [returns `None`],
  )
]

== MODIFIED Requirements

#requirement("find-matching-op", action: "modified", modifies: "core")[
  `find_matching_op` previously used `node.into_text()` and substring
  matching to find requirements. It SHALL now use the typed AST.
  All existing tests MUST pass without changes.
]

= Tasks

#task_group("1. Refactor find_matching_op", (
  task([Cast FuncCall node, check callee via ast::Ident], done: false, labels: ("core",)),
  task([Extract requirement ID via ast::Args → first positional Str arg], done: false, labels: ("core",)),
  task([Remove all into_text() and string-based matching from find_matching_op], done: false, labels: ("core",)),
))

#task_group("2. Refactor extract_body_from_node", (
  task([Traverse FuncCall args to find body content block], done: false, labels: ("core",)),
  task([Serialize body content block via into_text() only at the end], done: false, labels: ("core",)),
  task([Remove all char-by-char bracket depth tracking], done: false, labels: ("core",)),
))

#task_group("3. Verify", (
  task([Run all existing tests — they must pass unchanged], done: false, labels: ("tests",)),
  task([Test edge cases: single quotes, extra whitespace, nested brackets], done: false, labels: ("tests",)),
  task([Run full archive end-to-end to confirm behavior is identical], done: false, labels: ("tests",)),
))
