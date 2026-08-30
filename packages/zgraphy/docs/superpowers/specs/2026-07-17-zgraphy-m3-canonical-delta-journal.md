# zgraphy M3.4: Canonical Delta Journal, Tombstones, and Recovery

## Outcome

Every newly published immutable generation owns two independently validated
representations of the same repository meaning:

1. a complete NenDB snapshot that remains the primary read checkpoint; and
2. a bounded canonical delta journal that either creates the first checkpoint
   from an empty graph or transforms the exact parent graph into the target.

The journal contains full typed upserts, explicit record-family tombstones,
parent and target identities, a deterministic operation order, a commit footer,
and a digest over every preceding byte. Candidate publication replays the
journal and requires graph and secondary-index fingerprints equal to the full
snapshot before the active pointer can move.

This slice makes graph changes durable and replayable. It does not yet claim
that generation snapshots are stored only as deltas, that all build work is
incremental, or that retained generations have been compacted or garbage
collected.

## Graphify leverage and deliberate improvements

M3.4 ports the behavior represented by these pinned Graphify contracts:

- `detect.py::detect_incremental` and `tests/test_incremental.py` distinguish
  changed, unchanged, deleted, and excluded-but-still-present sources;
- `build.py::build_merge` and
  `tests/test_build_merge_hyperedges_and_prune.py` preserve unchanged records,
  replace changed sources, prune genuine deletion, carry valid hyperedges, and
  enforce that replacement wins when a path is both re-extracted and listed
  for pruning;
- `cache.py::save_semantic_cache` checkpoints complete content-addressed units
  and drops entries outside the current source inventory; and
- manifest and watch regressions treat path normalization, mixed batches,
  shrinkage, and interrupted work as correctness boundaries.

The pinned Graphify implementation does not persist an atomic canonical graph
delta capable of reconstructing and validating the target graph. zgraphy adds
that proof while retaining its existing immutable full checkpoint and sole
active-pointer commit. The reference checkout remains read-only.

## Authority and publication statechart

The full target snapshot is the normal query authority. The journal is an
independent update proof and recovery representation. Publication follows one
statechart:

1. validate current discovery, ownership, semantic records, freshness, and
   native indexes;
2. canonicalize row order without changing graph meaning or vectors;
3. load the current active checkpoint when one exists;
4. compute a complete previous-to-target delta and source-change evidence;
5. atomically write the target snapshot, manifests, delta journal, health, and
   metadata inside a new immutable generation directory;
6. reload the target snapshot and strictly decode the journal;
7. replay the journal against its declared parent and require exact target
   graph and secondary-index fingerprints;
8. validate metadata, counts, paths, digests, freshness, and zero-orphan
   invariants; and
9. atomically rename the active pointer only after every check passes.

A truncated, reordered, duplicated, oversized, incompatible, digest-mismatched,
or semantically invalid journal cannot activate. A process exit before step 9
leaves the previous active generation unchanged.

## Canonical records and equality

The journal covers every currently persisted canonical family:

- node plus its exact fixed-width vector;
- directed typed edge with provenance and source location;
- request-path hyperedge with interaction fingerprint, participants, and
  source evidence; and
- feature supernode with completeness, members, evidence, and proof steps.

Record equality includes every field that participates in the graph
fingerprint. An unchanged record emits no operation. A changed record emits a
tombstone for the previous value and an upsert for the new value, even when its
stable identity is unchanged. This prevents stale source spans, provenance,
search text, vectors, members, evidence, or proofs from surviving an update.

Before persistence, records are rebuilt into deterministic canonical order:

- nodes by stable node ID;
- edges by endpoints, relation, provenance, source path, and source line;
- hyperedges by stable hyperedge ID; and
- supernodes by stable supernode ID.

Replay canonicalizes the merged target using the same order. Secondary-index
fingerprints are therefore exact across a cold checkpoint, accumulated deltas,
and a cache-disabled clean build rather than depending on allocator or append
history.

## Journal protocol

`zgraphy.canonical-delta.v1` is newline-delimited JSON with exactly one header,
zero or more operations, and one complete footer. The final newline is
required. Every operation has a contiguous sequence number.

The header binds:

- repository identity;
- checkpoint or delta mode;
- parent and target generation identity;
- parent graph and index fingerprints when a parent exists;
- target graph and index fingerprints;
- canonical ordering recipe; and
- configured record and byte limits.

Operations occur in one deterministic dependency-safe order:

1. supernode tombstones;
2. hyperedge tombstones;
3. edge tombstones;
4. node tombstones;
5. node upserts;
6. edge upserts;
7. hyperedge upserts; and
8. supernode upserts.

Within a phase, identities are strictly increasing. The footer binds total and
per-family tombstone/upsert counts, target canonical counts, `complete: true`,
and a SHA-256 identity over the exact header and operation lines. The generation
metadata and active pointer bind the journal path, schema, digest, summary, and
parent identity. Absolute paths, source bodies, raw terminal data, credentials,
and wall-clock timestamps are forbidden.

## Tombstone provenance

Every removal is explicit and carries one deterministic cause:

- `replaced` — the same included source path has changed or the canonical
  record under it changed;
- `deleted` — the predecessor source path is absent from both current discovery
  and the filesystem;
- `excluded` — the source remains present but is now ignored, mandatory-
  excluded, sensitive, binary, oversized, unreadable, unsupported, or beneath
  an excluded directory;
- `dependency_invalidated` — the source itself remains included but a declared
  predecessor/current invalidation closure removed dependent meaning; or
- `reconciled_absent` — no narrower source cause is provable for a synthetic or
  aggregate record.

Tombstone cause is evidence, not replay authority. Replay always removes the
exact canonical identity. Replacement wins over deletion because a current
included path is classified before absence. Hyperedge and supernode causes are
derived only from their direct evidence/member paths; no repository-wide
guessing is permitted.

## Replay and recovery

Replay never mutates the parent graph. It verifies the declared parent graph
and index fingerprints, records tombstone identities in bounded sets, copies
only surviving parent records, applies typed upserts through normal
`RepositoryGraph` validation, canonicalizes the result, and verifies target
graph/index fingerprints and all footer counts.

Recovery has two safe lanes:

- If the full target snapshot is healthy, it remains queryable even if the
  auxiliary journal is later damaged. Doctor reports degraded delta evidence
  and recommends rebuilding the owned generation artifact.
- If the target snapshot is unreadable but its parent checkpoint and complete
  journal are healthy, zgraphy may reconstruct the exact target in memory and
  serve it only after all target identities and health checks pass.

If neither representation validates, the generation is unusable and the
existing automatic refresh path must build and atomically activate a clean
successor or return a typed failure. Recovery never rewrites the active pointer
or an immutable generation during a read.

## Bounds and failure behavior

Journal bytes are capped independently of snapshot bytes. Operation counts may
not exceed the configured graph capacities or declared footer totals. Nested
participant, evidence, member, and proof arrays remain subject to existing
semantic graph limits. Integer overflow, duplicate identities, invalid enum
values, bad spans, missing endpoints, invalid proofs, path traversal, unknown
records, unsupported schema versions, and incomplete input fail closed.

All journal writes use exclusive temporary files plus rename. Temporary files
are not recovery inputs. No process, model, network, credential, or external
database authority is introduced.

## Acceptance gates

The deterministic M3.4 scenario must prove:

1. a cold build writes a complete checkpoint journal whose replay from an empty
   graph equals its full snapshot and declared native-index fingerprint;
2. an unchanged explicit build creates no new generation or journal;
3. a one-source semantic edit writes a bounded successor delta containing only
   exact changed-record tombstones/upserts plus required derived closure;
4. replay of the successor against its parent equals both the published target
   and a cache-disabled clean build for graph and index fingerprints;
5. genuine deletion and ignore/exclusion produce distinct tombstone causes,
   while changed/re-extracted paths are replacement rather than deletion;
6. removed nodes, edges, vectors, hyperedges, supernodes, lexical postings, and
   adjacency leave no dangling or orphaned state;
7. duplicate, reordered, truncated, unknown, oversized, parent-mismatched,
   target-mismatched, and digest-corrupt journals are rejected;
8. corruption before activation cannot move the active pointer;
9. a healthy full snapshot safely carries reads when its journal is damaged,
   and a healthy parent plus journal reconstructs an intentionally damaged
   target snapshot exactly; and
10. journal and metadata contain no absolute repository path, source body,
    secret fixture value, or timestamp nondeterminism.

Debug, ReleaseSafe, complete Testing v2 receipts, current-source requirement
evidence, static safety, migration checks, and applicable pinned Graphify
regressions are mandatory.

## Claim boundary

M3.4 earns canonical row delta persistence, explicit graph-record tombstones,
strict replay equivalence, candidate journal validation, and validated
checkpoint-or-replay recovery. It does not yet earn selective mutation of
persisted NenDB columns, retained rename identity, origin-tier mark/sweep,
branch/worktree lineage, background watch, automatic artifact repair, bounded
generation retention, compaction, garbage collection, or one-file performance
superiority. `incremental_update` therefore remains unsupported until the base
store applies deltas without reconstructing a complete target checkpoint.
