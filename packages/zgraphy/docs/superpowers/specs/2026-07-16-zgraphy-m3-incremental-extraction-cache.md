# zgraphy M3.2: Content-Addressed Extraction Cache and Invalidation Closure

## Outcome

After the M3.1 freshness barrier detects a changed repository, zgraphy rebuilds
a complete candidate graph without reparsing unchanged Zig, TypeScript,
JavaScript, TSX, JSX or Proto files. Each cacheable source unit resolves to an
immutable structural-fact entry keyed by its normalized repository-relative
path, content digest, language mode, parser contract and parser recipe. A cache
hit is accepted only after the entry identity, parser identity, source size,
fact bounds and structural fingerprint validate.

The optimization does not turn cached output into graph authority. zgraphy
still reconstructs the complete parser corpus, reruns deterministic resolvers
and higher-order recipes, validates graph health and semantic proofs, writes a
complete immutable candidate generation and atomically activates only that
validated candidate. Cache absence or corruption therefore costs work but can
never cause stale or partial graph truth.

## Graphify leverage and deliberate improvements

The implementation preserves the useful contracts in Graphify's `cache.py`,
`detect_incremental`, manifest handling and update/watch regressions:

- content and path participate in cache identity;
- extractor versions invalidate stale structural output;
- cache files are written atomically;
- changed, deleted and renamed paths are distinguished;
- mixed change batches cannot preserve removed source facts; and
- failed cache reads fall back to extraction.

zgraphy strengthens those contracts by making parser schema, parser recipe,
language mode and source limits explicit; validating the structural
fingerprint after decoding; storing no absolute paths or source bodies in the
generation manifest; binding the extraction-manifest digest into generation
identity; and retaining M3.1's full candidate reload and semantic validation
before activation.

## Cache key and layout

The extraction-cache recipe is versioned independently from the graph recipe.
For each cacheable source, the key is SHA-256 over length-delimited values:

1. extraction-cache schema and recipe;
2. normalized repository-relative path;
3. discovery content digest;
4. language mode;
5. structural parser schema, parser ID and parser version; and
6. result-affecting parser bounds.

The path is:

```text
.zgraphy/cache/extraction/<recipe>/<first-two-hex>/<64-hex>.json
```

The cache entry contains typed structural facts and fingerprints, not source
bodies, graph nodes, derived edges, model claims or credentials. The key and
entry header must agree. A temporary file is exclusively created in the same
directory and renamed atomically. Existing immutable entries may be reused
only after validation; a malformed, oversized, truncated, mismatched or
incompatible entry is a miss and is atomically replaced after successful
parsing.

## Ownership and memory

Decoded results become ordinary owned parser results. Zig and Proto resolver
corpora gain explicit ownership-transfer entry points matching the existing
TypeScript symbol corpus. One owner deinitializes each result. Cache codecs
exclude allocator state, recompute summary and structural fingerprint
invariants, and bound both encoded and decoded bytes.

The cache directory is acceleration state owned by zgraphy. It is never
scanned as repository content. Orphan cache entries caused by an interrupted
candidate are harmless and are deferred to bounded M3 retention/GC work.

## Extraction manifest

Every generation adds an immutable `extraction-manifest.json`. Its canonical
units are sorted by path and contain only:

- relative path and language mode;
- content digest and cache identity;
- parser schema/ID/version and structural fingerprint; and
- sorted repository-relative semantic dependency paths.

The manifest has deterministic counts and a canonical digest independent of
whether this process observed a cache hit or miss. The active pointer and
generation metadata name the manifest and its digest, and generation identity
includes that digest. Candidate validation reparses the bounded manifest,
recomputes its digest and rejects duplicate paths, invalid identities,
unsorted units/dependencies, absolute paths, unknown parser recipes or
inconsistent counts.

Cache hit/miss/reparse statistics are execution evidence and do not
participate in generation identity.

zgraphy's own managed CLI runtime writes operational causal evidence beneath
`.zgraphy/runtime/causal`, while target-application evidence remains at
`.zigeffect/graph/causal-graph.jsonl`. The namespaces may not overlap. Without
that boundary, a build would import its own runtime startup and command events,
making an unchanged repository graph and generation identity change on every
CLI invocation.

## Invalidation closure

Directly invalidated units are the sorted union of:

- a path absent from either predecessor or candidate manifest;
- a path whose content/cache identity changed; and
- a path whose parser recipe or structural fingerprint changed.

The dependency index is derived from source-qualified graph evidence. For an
edge emitted by source path `S`, any repository source path on the opposite
endpoint becomes a dependency of `S`. Hyperedge and supernode evidence adds
dependencies between their source-qualified participants and proof inputs.
The predecessor and candidate dependency indexes are unioned before computing
a deterministic reverse transitive closure, so a removed old edge cannot hide
its former dependants and a newly introduced edge is immediately represented.

Direct invalidation and closure membership are distinct from parsing:
unchanged files in the closure reuse validated structural facts while their
derived relationships are recomputed. This slice still reruns the bounded
global deterministic resolver/materializer pass over cached facts. Selective
derived-record transactions and watch scheduling remain later M3 work; M3.2
must not claim that global resolution work has been eliminated.

## Generation and failure behavior

M3.2 advances the generation recipe and active-pointer contract. An M3.1
generation is readable as rollback evidence but is rebuilt once before it can
become an M3.2 active generation because it has no extraction manifest.

Failure rules are:

- missing entry: parse and atomically populate;
- corrupt/incompatible entry: count a rejected entry, parse and replace;
- parser failure: abort the candidate and retain the active generation;
- manifest validation failure: reject the candidate;
- graph or proof validation failure: reject the candidate;
- interruption before active-pointer rename: retain the prior active graph;
- cache write failure: abort rather than publishing an unrepeatable candidate.

No read command may silently fall back to a known-stale generation.

## Acceptance gates

The deterministic fullstack fixture must prove:

1. a cold build parses every cacheable source and writes one validated entry
   per unit;
2. an explicit clean warm rebuild reconstructs the same graph fingerprint with
   zero reparsed files and all cache hits;
3. changing one TypeScript file reparses exactly that file, reuses every
   unchanged cacheable unit and reports a bounded dependency closure containing
   the changed source and affected cross-stack participants;
4. deletion and rename remove predecessor units and stale semantic records
   while preserving valid cache hits for unrelated files;
5. one deliberately corrupt cache entry is rejected, reparsed and repaired
   without accepting malformed facts;
6. a clean cache-disabled/full parse and the accumulated cached build have
   equal canonical graph fingerprints, request paths and supernodes;
7. extraction-manifest identity and pointer paths are relative, bounded and
   source-body-free; and
8. staging/interruption leaves the previous active generation and its
   extraction manifest complete and queryable; and
9. zgraphy runtime telemetry is isolated from imported application causal
   evidence, so an unchanged CLI rebuild retains the active generation.

## Claim boundary

M3.2 earns per-file structural parse reuse and dependency-closure evidence. It
does not yet earn background watch, queued writer coalescing, selective
derived-record persistence, rename lineage, tombstones, cache/generation GC,
branch/worktree reconciliation, ANN indexes, one-file performance superiority
or bounded long-running churn. Those remain explicit M3/M6/M11 gates.
