# zgraphy M3.8: Reader-Safe Retention, Compaction, and Garbage Collection

## Outcome

zgraphy bounds its owned generations and structural extraction cache without
weakening the immutable publication model. Every automatic or manual garbage
collection pass first constructs a complete deterministic mark/validate/sweep
plan, proves that the active graph and all protected recovery/history inputs are
marked, then deletes only unmarked artifacts below `.zgraphy/` while holding the
single-writer lease and an exclusive generation-reader lease.

The active generation remains queryable throughout update churn. If another
process is reading a generation, automatic collection is deferred rather than
blocking the query or racing deletion. The next build, watch refresh, query, or
manual collection retries the same idempotent plan.

## Graphify behavior retained and improved

The pinned Graphify cache implementation and `tests/test_cache.py` establish
important regressions:

- extractor-dependent structural cache entries are recipe/version namespaced;
- stale structural recipe namespaces are never served and are eventually
  removed;
- semantic cache namespaces are independent from structural cache namespaces;
- pruning uses the complete live-key set, not only the changed-file subset;
- deleted or changed files leave unreferenced cache entries that are pruned;
- live unchanged entries survive pruning;
- plain and deep semantic namespaces are swept independently against the same
  live set; and
- temporary and unrelated files are not mistaken for cache entries.

zgraphy improves this boundary by deriving liveness from validated immutable
generation manifests rather than a mutable run-local set, preserving keys used
by every retained generation, checking repository and recipe identity, and
coordinating deletion with concurrent readers. Structural and future semantic
provider namespaces remain independently owned and swept; M3.8 does not invent
semantic-provider entries before M10.

## Product boundary

M3.8 provides:

- configurable automatic generation retention and grace period;
- a repository-bound, checksummed user generation-pin artifact;
- active/fallback/replacement/recent/pinned generation marking;
- exact structural cache liveness from all retained extraction manifests;
- bounded deletion of unretained generations, their journals/tombstones, stale
  structural recipe namespaces, and unreferenced canonical cache entries;
- a shared generation-reader lease and nonblocking exclusive GC lease;
- deterministic manual dry-run and explicit `--apply` CLI behavior;
- an atomic redacted latest-GC receipt and status/doctor summaries; and
- crash-safe idempotent retries after partial deletion.

It does not delete user-authored source, follow symlinks, compact the active
NenDB checkpoint in place, truncate an active delta journal, expire future
provider observations, or claim production long-churn/performance superiority.
Every generation already contains a complete canonical checkpoint; M3.8
compacts history by retiring whole unneeded immutable generations and their
bound journals only after their retention obligations expire.

## Retention policy

Repository config-v2 gains backward-compatible defaulted fields:

- `automatic_gc`, default `true`;
- `retention_generations`, default `8`, minimum `2`, maximum `128`; and
- `retention_grace_ms`, default five minutes, with a validated finite maximum.

Missing fields in an existing config-v2 file receive the safe defaults. A grace
of zero is permitted for deterministic tests and explicit local policy. Fixed
engine bounds cap direct generation entries, cache entries, pins, plan actions,
and receipt bytes independently of repository source limits.

The mark set includes:

1. the exact active generation;
2. its direct parent as last-known-good delta fallback;
3. its repair/replacement generation when distinct;
4. the newest complete valid generations up to the configured recent bound;
5. every valid user pin;
6. the direct parent and replacement dependency of every retained generation;
   and
7. any future migration/job reference once that subsystem exists.

Pins may exceed the recent bound but are independently bounded. A pin can name
only a complete, repository-bound generation currently present under the owned
generation root. Pin updates are atomic and take the update lease, so a pin
cannot race a sweep.

There are no resumable model/provider jobs or rollback migrations in M3.8.
Their empty reference sets are explicit in the receipt rather than silently
assumed; later subsystems must add their references to the same mark API before
they can persist owned artifacts.

## Mark and validation protocol

Planning is read-only and deterministic:

1. acquire the update lease so generation publication and pin changes cannot
   change the inventory;
2. read and strictly validate the active pointer;
3. enumerate only direct children of `.zgraphy/generations` without following
   symlinks and within the scan bound;
4. parse complete generation metadata with exact repository, generation,
   schema, parent, replacement, and extraction-manifest bindings;
5. read and validate the pin artifact;
6. compute the protected generation closure and prove the active generation is
   present and marked;
7. read every retained extraction manifest and mark every canonical cache key;
8. enumerate canonical cache entries and recognized old structural recipe
   namespaces without following symlinks;
9. classify every possible action with a typed reason and grace eligibility;
10. sort actions canonically and hash the complete plan; and
11. reject the entire plan if any protected metadata, pin, manifest, bound, or
    identity is corrupt, missing, incompatible, or ambiguous.

Planning never treats corruption as an empty live set. Unknown files, unknown
cache namespaces, malformed non-generation directory names, symlinks, and
special entries are ignored and reported as preserved; they are not deletion
targets.

## Reader and writer coordination

`.zgraphy/runtime/generation-readers.lock` is the process-shared lease:

- query/status/doctor readers acquire a shared lock before reading the active
  pointer and hold it until all referenced generation artifacts are loaded into
  owned memory;
- update construction continues under `.zgraphy/update.lock` and does not
  mutate an active generation;
- GC holds the update lease, then attempts the reader lock exclusively and
  nonblockingly immediately before sweep;
- contention returns `deferred_readers`, deletes nothing, and retains the plan
  for a later retry; and
- the exclusive lock is held through every deletion and latest-receipt write.

Lock order is always update lease then reader lease for destructive work.
Readers never acquire the update lease while holding the reader lease. This
prevents deadlock and closes the pointer-read/generation-delete race.

## Sweep and crash semantics

Only actions from a validated plan may be applied. Generation actions target
exact direct children matching canonical `g-<sha256>` identities. Cache actions
target exact current-recipe shard paths matching `<64-lower-hex>.json`.
Recognized obsolete structural recipe directories are deleted as whole owned
namespaces. No action may contain an absolute path, `..`, a path separator in an
identity, or a target outside the fixed owned roots.

The sweep is idempotent. Missing targets count as already absent. A crash can
leave a prefix of sorted actions applied, but cannot alter the active pointer or
retained artifacts. The next plan recomputes liveness from durable state and
finishes safely. Per-action failures are counted, never hidden as success, and
make the report degraded while preserving unrelated actions and the active
graph.

Cache entries and generation directories become eligible only after the grace
period according to their owned metadata modification time. Canonical temporary
files are preserved during normal cache pruning; cleanup of abandoned atomic
temporaries requires its own exact-age/ownership rule and is not inferred from
an arbitrary `.tmp` suffix.

Deleting a generation retires its complete checkpoint, metadata, origin and
lineage evidence, indexes, delta journal, and tombstones together. Active or
retained journals are never rewritten. Receipt counters expose generations,
journals, tombstones, cache entries, namespaces, and failed/deferred actions.

## Automatic and manual execution

After a new active pointer is durable, the same update transaction attempts an
automatic applied plan when enabled. An unchanged pre-query refresh also
attempts collection, allowing deferred reader contention and newly elapsed
grace periods to converge without a daemon. Collection failure occurs after a
valid active graph exists and therefore degrades the retention summary without
rolling back or misreporting graph freshness.

`zgraphy gc` is dry-run by default. `zgraphy gc --apply` uses the same planner,
locks, validator, and sweeper as automatic collection. `zgraphy pin` and
`zgraphy unpin` update only the bounded repository pin artifact. JSON output is
versioned, bounded, source-body-free, and deterministic apart from explicit
observation time and applied/deferred outcome.

## Status and diagnostics

The atomic latest receipt under `.zgraphy/runtime/gc/` includes:

- repository identity, policy and mode;
- active generation and plan fingerprint;
- scanned, valid, retained, pinned, candidate, grace-deferred, applied,
  already-absent, failed, and reader-deferred counts;
- generation, journal/tombstone, cache-entry, and obsolete-namespace counts;
- preserved unknown/symlink/special counts;
- empty current migration/resumable-job reference counts; and
- typed status and repair guidance without absolute paths or raw source.

`status` reports the current refresh attempt's retention summary. `doctor`
validates the latest receipt binding and marks self-management degraded for a
corrupt receipt, failed sweep, exceeded bound, or persistent reader deferral;
missing evidence before the first complete generation remains partial.

## Acceptance gates

The deterministic M3.8 scenario must prove:

1. config-v2 files missing retention fields load safe defaults and invalid
   bounds fail closed;
2. a series of edit/create/delete/rename generations automatically converges
   to the configured recent bound plus explicitly classified dependencies and
   pins;
3. active, direct fallback parent, repair replacement, recent and pinned
   generations survive while eligible unmarked generations are removed;
4. a pin update racing policy is serialized and a corrupt/mismatched pin file
   prevents every deletion;
5. all cache keys referenced by every retained manifest survive, while an
   eligible canonical orphan is removed;
6. Graphify-derived changed/deleted/full-live-set and recipe-version cache
   regressions pass, while unrelated files and arbitrary temporaries survive;
7. a shared reader causes an applied pass to return `deferred_readers` with zero
   deletions, then succeeds after release;
8. malformed active/protected metadata, a missing retained manifest, traversal,
   symlink, oversized inventory, or out-of-bound plan fails closed;
9. manual GC is dry-run by default, changes no filesystem state, and `--apply`
   applies the exact same plan fingerprint when state is unchanged;
10. interruption after any action prefix is idempotently recoverable and never
    removes the active pointer target;
11. status, doctor, latest receipt, pins, and causal evidence contain no source
    bodies, absolute paths, tokens, or secret fixture values;
12. a post-GC default query is current, its graph/index/origin meaning equals a
    clean rebuild, and parent-delta recovery remains available; and
13. all M3.1-M3.7 scenarios remain green with complete Testing v2 evidence and
    no pending fibers or causal findings.

## Claim boundary

M3.8 earns bounded reader-safe automatic generation and structural-cache
garbage collection, immutable-history compaction, user pins, deterministic
manual dry-run/apply, and diagnostics. It does not earn a daemon, Git-hook
installation, provider-cache expiry before those providers exist, in-place
NenDB page compaction, active-journal rewriting, multi-repository retention,
or release-corpus performance superiority. Those claims remain gated by later
milestones and long-running benchmark evidence.
