# zgraphy M3.1: Automatic Freshness and Immutable Generations

## Outcome

Every graph-reading CLI command crosses a local freshness barrier before it
answers. An unchanged repository reuses the active graph without reparsing
source. A changed, deleted, renamed, newly included or newly excluded input
causes zgraphy to build a clean candidate, validate every graph and semantic
invariant, publish an immutable content-addressed generation, and atomically
activate it. A refresh failure returns an error; it never silently answers from
the known-stale generation.

This is the correctness-first M3 slice. Refresh rebuilds the complete graph
after a changed manifest, so removed facts, nodes, edges, vectors, hyperedges
and supernodes disappear by construction. File-to-fact invalidation and
incremental closure rebuilding are deferred to M3.2 and must preserve the same
generation and freshness contracts.

## Freshness authority

The discovery and ownership manifest digests are the local deterministic
freshness authority. The barrier scans and hashes bounded repository inputs and
re-evaluates bounded ownership manifests. It does not invoke language parsers
when both digests match the active generation.

An active generation is stale when either digest differs, when no active
generation exists, or when its pointer, metadata, snapshot or health evidence
is incomplete, incompatible or corrupt. Missing/corrupt active state triggers
a clean candidate rebuild only when the repository and config remain readable;
otherwise the read fails closed.

## Single-writer publication

All candidate construction and activation occurs while holding an advisory
exclusive lock on `.zgraphy/update.lock`. The lock is released by the operating
system if the process exits and never relies on deleting a sentinel. Lock
acquisition is bounded and non-blocking for this slice: a competing updater
returns a typed busy result instead of waiting indefinitely.

The active generation pointer is the sole read authority. Legacy config-v2
artifact paths continue to be published for backward compatibility and M1
diagnostics, but graph readers pin only the immutable path named by the active
pointer.

## Generation identity and layout

A generation ID is `g-` plus a SHA-256 digest of:

- repository identity;
- discovery and ownership manifest digests;
- complete graph fingerprint;
- snapshot schema and embedder identity; and
- freshness recipe version.

The layout is:

```text
.zgraphy/
  update.lock
  active-generation.json
  generations/g-<digest>/
    nendb.jsonl
    content-manifest.json
    graph-health.json
    generation.json
```

All paths are repository-relative, derived from validated fixed-format IDs and
bounded before use. `generation.json` is written last inside the candidate and
declares complete record counts, graph fingerprint, manifest digests, parent
generation and pruning accounting. The candidate snapshot is loaded and its
health/fingerprint are revalidated before the active pointer may move.

## Activation and interruption

Activation is one exclusive temporary write plus atomic rename of
`active-generation.json`. A process interruption before that rename leaves the
previous pointer and generation queryable. A reader copies the active pointer
before loading and therefore remains pinned to that complete immutable
generation even if another process activates a successor.

Candidate staging without activation is a supported internal/public operation
for recovery and deterministic interruption testing. Rebuilding the same
source produces the same generation ID and safely reuses or replaces only that
candidate's deterministic files before activation.

## Automatic pruning and accounting

Before activation, zgraphy compares the previous live graph with the candidate
and records counts for removed nodes, edges, vectors, hyperedges and
supernodes. The candidate must have:

- zero dangling edge endpoints;
- zero missing or unowned vectors;
- zero dangling hyperedge participants;
- zero dangling supernode members or input hyperedges;
- zero invalid proof steps; and
- zero true orphans under the existing protected-isolation rules.

Deletion, rename, exclusion and recipe invalidation therefore cannot leave an
old identity reachable through the active pointer. The prior immutable
generation remains available as rollback evidence in M3.1; bounded retention,
tombstones, compaction and generation garbage collection are M3.3 work.

## CLI behavior

`build` and `ingest` force a locked clean candidate build and activation.
`status`, `query`, `explain` and `path` call the automatic barrier, then report
the pinned generation and refresh outcome in JSON. `doctor` remains read-only:
it diagnoses current versus active state without repairing it.

The refresh outcome is one of:

- `current`: digests matched and no source was reparsed;
- `refreshed`: a candidate was validated and activated; or
- `staged`: a complete candidate was intentionally left inactive.

## Acceptance gates

The deterministic fullstack fixture must prove:

1. initial build publishes one complete semantic generation;
2. an unchanged managed read keeps the generation ID and reports zero reparsed
   files;
3. a mixed edit/delete/rename refresh changes the generation, removes every
   superseded path identity, removes invalidated request-path and feature
   records, and leaves a clean graph;
4. the old immutable snapshot remains complete and queryable;
5. a staged successor does not move the active pointer;
6. the next automatic read activates the deterministic staged generation and
   restores valid semantic records; and
7. every publication and refresh receipt is bounded, source-body-free and
   free of absolute paths.

## Deferred work

M3.1 does not claim per-file parse reuse after a changed manifest, incremental
invalidation closure, rename lineage/tombstones, background watch, waiting lock
queues, multi-reader stress qualification, branch/worktree identity, bounded
generation retention, compaction, garbage collection or performance
superiority. These optimizations must not weaken the fail-closed barrier or
immutable activation protocol delivered here.
