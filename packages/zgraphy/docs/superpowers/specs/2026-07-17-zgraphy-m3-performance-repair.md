# zgraphy M3 Performance Repair: Bounded Lazy Storage and Reused Meaning

## Outcome

The M3 exit path must retain the exact graph, native indexes, origin ledger,
immutable-generation recovery and clean-build equivalence already required by
M3.9 while removing work that scales with configured maxima or repeats parsing
and validation already completed by the same transaction.

This is an implementation repair inside `req-m3-exit-qualification`; it does
not weaken the corpus, sampling, targets or claim gate. The paired ReleaseSafe
receipt remains the only evidence that can close M3.

## Profile evidence

The first correct self-host sample measured approximately 10.43 seconds and
407.7 MB peak RSS. A five-second Darwin sample of the measured build identified
three responsible boundaries:

1. `nendb.GraphData.init` allocates columns for 100,000 nodes, 500,000 edges
   and every 64-dimensional vector before the first record. One graph therefore
   reserves about 36.9 MB, and publication holds multiple immutable, replay and
   origin-validation graphs concurrently.
2. `rpc_continuity.Corpus.resolve` reparses every Zig and TypeScript document
   from copied source even though the extraction session reported 116 cache
   hits and the primary resolver corpora already own validated parsed results.
   It consumed 1,481 of 4,156 captured samples.
3. origin ownership construction and validation repeatedly scan all prior
   records and graph records. On the qualification graph this means quadratic
   work over approximately 19,800 ownership rows, plus repeated complete
   secondary-index validation.

## Slice A: lazy bounded NenDB columns

`Options.max_nodes`, `max_edges` and `max_lexical_postings` remain hard,
fail-closed limits. They no longer imply eager allocation.

- A fresh `GraphData` allocates small non-zero node and edge column capacities
  capped by the configured maxima.
- Before a node or edge mutation, every parallel struct-of-arrays column grows
  transactionally to one shared geometric capacity no larger than its hard
  limit.
- Growth allocates all successor columns first, copies only active rows, then
  frees all prior columns. Allocation failure leaves the original graph intact.
- Vector storage grows with the node columns and preserves exactly 64 values
  for every active node.
- Removal, lookup, fingerprints, snapshots, deltas and secondary indexes remain
  defined only over active counts, not spare capacity.
- Public capacity fields continue to report configured hard limits; tests may
  inspect allocated column lengths to prove the implementation is lazy.

Acceptance requires a graph configured with production-sized limits to begin
well below those limits, grow across at least two boundaries, preserve all
nodes/vectors/edges/indexes, and still reject the first record above each hard
limit.

## Slice B: reuse validated parser and resolver products

The standalone `rpc_continuity.Corpus.resolve` path remains available for
callers that only have source documents. The repository indexer uses a new
prepared path supplied with the exact products already built in the current
transaction:

- canonical Proto resolution;
- generated-binding lineage;
- TypeScript module resolution and the TypeScript parsed corpus; and
- the Zig parsed corpus.

The prepared path validates every supplied product and verifies that its
document paths, corpus fingerprints and Proto/module identities match the
continuity corpus. It must fail closed on a missing, extra or mismatched parsed
document. It executes the same continuity engine and must return a byte-for-byte
equivalent canonical result/fingerprint to the standalone path on the mixed
fixture. No raw-source fallback is allowed after prepared validation begins.

The extraction receipt continues to count only actual parser work. Reusing a
prepared result cannot turn an invalid cache entry into a hit or hide a changed
file.

## Slice C: indexed origin construction and validation

Origin ownership remains one-to-one and complete. Linear indexes replace
repeated scans without changing the artifact schema or canonical sort order.

- Builder insertion uses a hash key over the complete `RecordRef` identity and
  rejects duplicate ownership before mutating the artifact.
- Coverage validation builds a bounded owner-ID set and record-key set once.
- Every ownership row must reference a declared owner and an exact live graph
  record; edge existence uses the native relation-specific adjacency index.
- Because ownership rows are unique, live, and equal in cardinality to the
  graph's complete record count, that bijection proves total coverage without a
  second graph-by-ownership nested scan.
- Canonical sort validation, summaries, fingerprints, overlay collisions and
  malformed-artifact failures remain unchanged.

## Slice D: proof-carrying semantic-no-op generations

The profiled build still spends most of its remaining time loading, cloning,
validating, serializing and replaying the complete graph after an edit whose
parsed meaning is unchanged. A semantic no-op is therefore a first-class
incremental transaction, not a reason to mutate the active generation or serve
an old source manifest.

The initial supported proof is deliberately narrow and fail closed:

- the active generation, repository context, ownership assignments, path set,
  classifications and dispositions must still be valid and unchanged;
- one or more changed files must be non-generated, deeply indexed Zig source
  units already present in the validated extraction manifest;
- each current file is read against the discovery digest and parsed with the
  same parser identity and limits as the prior cache entry;
- all declarations, imports, calls, call arguments, bindings, references,
  summaries, source spans and every source slice materialized as graph search
  text must be byte-equivalent to the prior validated parser result; and
- unsupported languages, generated files, manifest/config/causal changes,
  path changes, parser/cache corruption, repository-context changes, origin
  overlays, repair requests, or any failed equivalence check fall back to the
  complete existing build and publication path.

The proof excludes total source length and bytes outside graph-bearing spans,
so an appended comment can be a semantic no-op. Moving a declaration with a
leading comment, changing a literal inside indexed declaration text, changing
an import/call/binding, or changing any source location is not a no-op.

Successful proof publishes a new immutable source generation with current
content and extraction manifests, current repository context, change lineage,
an identity delta, repair evidence, health evidence and metadata. It reuses the
already validated database snapshot and origin ledger through an explicit
`semantic_generation` binding. It never rewrites either artifact and never
changes the canonical graph or secondary-index fingerprints.

Generation schema v7 binds the source generation to:

- the semantic generation that owns its graph snapshot and origin ledger;
- streaming SHA-256 identities for the reused snapshot and origin artifact;
- current discovery, ownership and extraction identities; and
- the existing graph, index, lineage, repair and delta identities.

Before reuse, zgraphy validates current source topology, the prior generation
metadata and delta headers, extraction and content manifests, repository
context and lineage bindings, and streaming snapshot/origin artifact hashes.
This check must not deserialize the graph or origin ledger. The semantic base
is retained as a declared dependency of every live source generation. Missing
or damaged reusable artifacts force the normal repair/full-build path.

The identity delta has zero operations, equal parent and target graph/index
identities, and exact prior target counts. Replay against the parent must still
produce the target identity. A semantic no-op generation must remain queryable,
survive restart, participate in automatic retention, and compare exactly with
a cache-disabled clean rebuild of the same current source.

The CLI build result is summary-owned rather than graph-owned on this path. It
must report current discovery and cache evidence plus inherited semantic counts
without reloading the published graph merely to print JSON. The explicit
full-build API used by differential and mutation tests remains available.

## Invariants and nonclaims

All four slices must preserve:

- graph and secondary-index fingerprints;
- clean-full equivalence after one-file updates;
- exact reparsed/cache counts;
- hard resource bounds and allocation-failure safety;
- immutable generation publication and parent recovery;
- reader-safe retention and origin completeness; and
- the existing redaction and no-network boundary.

Passing focused tests or improving a diagnostic run does not earn a Graphify
performance claim. M3 remains open until the full paired current-source
ReleaseSafe receipt passes both the 5x median-latency and 0.5x median-RSS gates.

## Qualification result

The current-source paired ReleaseSafe receipt passes both gates with one warmup
and seven isolated samples. zgraphy records a 97,703,291 ns median update versus
Graphify's 547,151,584 ns (5.6001x speedup) and 14,794,752 bytes median peak RSS
versus 79,200,256 bytes (0.1868x ratio). Correctness, freshness, clean-build
equivalence, retention and origin gates are current and comparison eligible.

This earns only the bounded claim defined here. Persisted size is measured but
has no M3 superiority target, and held-out retrieval, agent-task, million-edge
and production-soak claims remain unearned.
