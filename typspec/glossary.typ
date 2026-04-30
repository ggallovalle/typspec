#let entries = (
  (
    key: "damlev",
    short: "damlev",
    long: "Damerau-Levenshtein distance",
    description: [
      String metric for measuring edit distance between two sequences.
      An extension of Levenshtein distance that also considers
      transpositions of two adjacent characters as a single edit.
      #link("https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance")[Wikipedia].
    ],
  ),
  (
    key: "fuzzy-matching",
    short: "fuzzy matching",
    long: "fuzzy name resolution with edit distance",
    description: [
      When a spec or change name doesn't match exactly, typspec uses
      the @damlev to find the closest match.
      Names with similarity above approximately 67% are suggested to the
      user as "did you mean" tips.
      Applied in the `status`, `archive`, and `which` commands.
    ],
  ),
  (
    key: "modifies",
    short: "modifies",
    long: "spec targeting",
    description: [
      The mechanism by which a change or requirement declares which spec(s) it
      targets. At the change level, `modifies` lists all specs a change affects.
      At the requirement level, it targets a single spec within a multi-spec
      change. When a change modifies only one spec, requirement-level `modifies`
      is optional.
    ],
  ),
  (
    key: "spec-delta",
    short: "spec delta",
    long: "a set of requirements targeting a spec",
    description: [
      A collection of `#requirement` calls within a change document that
      share the same target spec. Each spec-delta carries an action
      (`added`, `modified`, or `removed`). During archive, requirements
      are grouped by their @modifies field into per-spec deltas and
      applied to the corresponding spec file.
    ],
  ),
)

#import "@preview/glossarium:0.5.10"


#let glossary(body) = {
  show: glossarium.make-glossary
  glossarium.register-glossary(entries)
  body
  glossarium.print-glossary(entries)
}
