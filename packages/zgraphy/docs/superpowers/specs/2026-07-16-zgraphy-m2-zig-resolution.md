# zgraphy M2.2: Evidence-Preserving Zig Resolution

## Problem

The M2.1 compiler-AST boundary extracts declarations, imports, and calls, but
the v1 indexer resolves a call by its leaf name and then searches every symbol
in the repository. That loses lexical scope and import bindings. It also drops
useful uncertainty: a function value such as
`const loader = if (flag) alpha.load else beta.load` becomes a name-only
concept with no explicit candidate set.

M2.2 must produce useful agent facts without pretending to run Zig semantic
analysis. Every resolution must therefore be source-grounded, deterministic,
bounded, and explicit about whether it is resolved, ambiguous, or unresolved.

## Product contract

For a corpus of valid repository-relative Zig files, zgraphy will:

1. Extend compiler-AST facts with import bindings, local bindings, initializer
   spans, and field-access references inside binding initializers.
2. Resolve direct same-file calls and imported `alias.member` calls using exact
   file and declaration identity.
3. Follow a called local function-value binding to every source-visible
   imported callable candidate in its initializer.
4. Publish exactly one of `resolved`, `ambiguous`, or `unresolved` for each
   call, with a sorted source-qualified candidate set and reason.
5. Materialize local binding nodes and `dispatches_to` candidate edges only
   after the independent resolution result validates.
6. Preserve ambiguous candidates rather than selecting one by repository scan
   order or global name uniqueness.

The existing graph `calls` edge remains the extracted call-site relationship.
For an ambiguous local function value, the local binding node receives one
`dispatches_to` edge per candidate with ambiguous provenance. The semantic-v2
ontology already defines `dispatches_to`, and its benchmark-v1 compatibility
mapping projects it as `selects_candidate`.

## Structural facts

`ZigParser.Result` adds:

- `Import.binding`: the containing variable declaration name and enclosing
  declaration when the import is statically bound, or empty when no binding is
  provable.
- `Binding`: name, enclosing declaration, declaration/name/initializer spans,
  and whether it is local or file scoped.
- `BindingReference`: binding name, enclosing declaration, compact field-access
  expression, and exact span. References are extracted only from AST nodes
  contained by the initializer span.

These facts participate in parser limits, validation, ordering, summaries, and
fingerprints. Comments and strings remain incapable of creating facts.

## Resolution boundary

`ZigResolution.Corpus` owns parsed file results and resolves them as one bounded
unit. It accepts files in any order but sorts all externally visible outputs.
The resolution result contains calls and flat candidates linked by resolution
index. Candidate identity is `(target_path, target_name)`; no leaf-only or
global-uniqueness identity is allowed.

Resolution precedence is:

1. A preceding same-function local binding with the exact bare callee name;
   its initializer contributes every exact imported callable reference.
2. A same-file declaration with the exact bare callee name when no local
   binding shadows it.
3. An exact `alias.member` whose visible alias is a static import binding and whose
   normalized target file declares the exact member.
4. Unresolved, with zero candidates.

One candidate is `resolved`; two or more are `ambiguous`. Duplicate references
collapse to one candidate. Relative import normalization may not escape the
corpus root, use absolute paths, or invent a target that is absent from the
corpus.

## Graph materialization

The build path parses each Zig source once, indexes structural facts, stores the
parsed result in the corpus, resolves after all files are known, validates the
result, and then materializes it. A local binding is a stable `concept` node in
the current v1 graph so persisted node kinds do not change in this slice.

For each local binding used as a call target:

- enclosing symbol `calls` local binding remains extracted/ambiguous;
- local binding `dispatches_to` each candidate symbol;
- one candidate edge uses inferred provenance, while multiple candidates use
  ambiguous provenance;
- edge source path and line come from the exact call/binding evidence.

The old repository-global unique-name resolver must not resolve a call that has
an explicit M2.2 outcome. It remains temporarily available only for legacy
facts outside the corpus resolver until the rest of M2 is migrated.

## Acceptance evidence

The `zig-ambiguity` fixture is the primary oracle. M2.2 passes only when:

- imports bind `alpha` and `beta` to their exact normalized files;
- `loader` is local to `choose` and references `alpha.load` and `beta.load`;
- `loader()` is `ambiguous`, with exactly those two sorted candidates;
- repeated analysis produces the same fingerprint;
- the graph contains both candidate edges and no invented third candidate;
- the canonical differential adapter matches both `selects_candidate`
  relations and derives the `call_resolution=ambiguous` fact;
- malformed, escaping, duplicate, and bounded-input behavior remains typed;
- Testing v2 evidence has no findings, pending fibers, leaks, or logged errors.

## Non-goals

M2.2 does not claim compiler type checking, comptime evaluation, pointer or
closure flow, generic instantiation, method dispatch, package-manager module
resolution, or interprocedural return-value analysis. Those require later M2
and M4 semantic passes. Unsupported cases remain unresolved rather than being
guessed.
