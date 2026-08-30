# zgraphy M3.7: Bounded Watch and Update Coordination

## Outcome

`zgraphy watch` continuously reduces query-time freshness work without becoming
a second ingestion implementation. It observes bounded local repository state,
debounces and coalesces change bursts, requests the existing `ensureFresh`
transaction, preserves requests that collide with another updater, drains
changes that arrive during a build, and stops cleanly without moving the active
pointer to an incomplete generation.

The pre-query freshness barrier remains authoritative. Watch and future Git
hooks are optional accelerators over the same update engine, so a stopped,
crashed, delayed, or unsupported watcher can increase latency but cannot make a
stale graph appear current to a default query.

## Graphify behavior retained and improved

The pinned Graphify watcher establishes useful regression contracts in
`graphify/watch.py` and `tests/test_watch.py`:

- events are filtered before expensive work and coalesced by a debounce window;
- one operating-system-owned rebuild lock prevents concurrent writers;
- lock contenders queue changes instead of silently dropping them (regression
  #1059);
- a lock holder drains requests both before and after its rebuild so late
  arrivals receive another pass;
- pending paths are deduplicated, malformed/blank entries do not poison valid
  work, and drain loops are bounded;
- explicit deletion and rebuilt-source evidence distinguish legitimate graph
  shrink from unexplained loss;
- persisted excludes and watched-root identity survive update invocations; and
- ignored paths, output directories, hidden noise, worktrees, symlinks, and
  mixed batches do not accidentally replace unrelated graph state.

zgraphy improves this contract by using no Python interpreter or optional
`watchdog` package, by never merging graph JSON as a separate watch path, and by
letting generation validation, origin-owned sweep, canonical deltas, repair,
and atomic activation remain the sole publication implementation.

## Product boundary

M3.7 provides:

- a typed, inspectable update-coordinator statechart;
- a bounded in-memory debounce/coalescing machine;
- a bounded, checksummed, repository-bound pending-request artifact under
  `.zgraphy/runtime/watch/`;
- a native polling adapter with configurable interval and debounce;
- a `zgraphy watch` foreground process with signal-aware draining and bounded
  test cycles;
- an explicit update request API reusable by later Git/editor hooks; and
- status/doctor summaries for watcher state, queue health, refresh attempts,
  contention, failures, and last successful generation.

It does not install a daemon, launch at login, modify Git hooks, use a remote
service, promise kernel event APIs on every platform, or perform retention and
garbage collection. Those require separate authority or later M3 slices.

## One update engine

The watcher never calls discovery, parsers, resolvers, NenDB persistence, or
activation as independent stages. Its only mutation boundary is
`Operations.ensureFresh` (or a public wrapper that preserves exactly that
contract). Consequently:

- unchanged observations return `current` with zero reparses;
- deterministic changes publish the same generation as a query-triggered
  refresh;
- origin/provider carry and sweep remain identical;
- damaged active generations use M3.6 repair escalation;
- lease contention cannot create a second writer; and
- failure leaves the prior complete pointer unchanged.

## Typed statechart

The public definition uses `zigeffect_std`'s typed statechart API and the stable
machine identity `zgraphy.watch-coordinator`.

States:

`idle -> debouncing -> waiting_for_lease -> refreshing -> draining -> idle`

Terminal/drain states:

`idle|debouncing|waiting_for_lease|refreshing|draining -> stopping -> stopped`

Failure transitions enter `retaining_last_good`, record a bounded typed cause,
retain or requeue the triggering observation, and return to `debouncing` or
`idle` according to retry policy. No failure transition publishes.

Events include observed change, debounce elapsed, lease acquired/contended,
refresh succeeded/failed, late request drained, retry due, stop requested, and
drain complete. Commands describe effects (`persist_request`,
`attempt_refresh`, `drain_requests`, `record_failure`, `stop`) but the pure
machine does not perform I/O.

Every accepted transition increments a monotonic coordinator sequence. Refresh
requests carry the sequence/fence that selected them. The underlying update
lease and atomic candidate validation remain the publication fence; an older
coordinator decision cannot bypass them.

## Observation and debounce

The portable adapter performs a bounded no-follow metadata walk and computes a
transient stat fingerprint from normalized relative path, kind, size, and
modification identity plus repository context. It excludes zgraphy's owned
runtime/output subtree so publishing a generation cannot trigger an update
loop. A changed metadata fingerprint is a hint, never proof of semantic
freshness: after debounce the watcher calls `ensureFresh`, which performs the
authoritative content and repository-context comparison.

The observer is bounded by repository config limits. Poll interval, debounce,
maximum pending requests, maximum path bytes, maximum drain passes, retry
backoff, and optional maximum cycles are explicit validated options. Defaults
favor agent development latency without busy-spinning. Tests use logical time;
no acceptance assertion depends on wall-clock scheduling.

Events arriving inside the debounce window reset its deadline and deduplicate
against the current batch. Events arriving while a refresh is active enter the
pending artifact and force a drain pass after the refresh. A full-corpus
freshness check subsumes all queued path hints but still drains their durable
request records so they cannot leak into later cycles.

## Durable pending requests

`.zgraphy/runtime/watch/pending.json` is zgraphy-owned, repository-bound,
versioned, checksummed, path-redacted where discovery policy requires it, and
written atomically. It stores bounded request identities and normalized path
hints, not source bodies. Duplicate requests merge deterministically.

The queue protocol is mark-safe:

1. a contender atomically records its request before reporting contention;
2. a lease holder drains and validates the current artifact before refresh;
3. drained work remains represented in the coordinator until refresh success;
4. after refresh, the holder drains again for late arrivals;
5. success acknowledges only the batch covered by that refresh; and
6. failure re-persists the batch before returning to an idle/retry state.

Malformed, incompatible, oversized, repository-mismatched, or digest-corrupt
artifacts fail closed with a diagnostic. They are never interpreted as an empty
queue. The active graph remains queryable through the pre-query barrier.

## Cancellation and process lifecycle

The CLI process owns ZigEffect lifecycle and signal services. SIGINT/SIGTERM
sets an async-signal-safe latch. The loop stops accepting new observations,
persists any unacknowledged batch, lets an already-completed immutable
publication stand, records `stopping -> stopped`, and exits. Because
`ensureFresh` is synchronous and atomically activates only after validation,
M3.7 cancellation occurs between bounded phases; preemptive parser/build
cancellation remains a later optimization.

`--max-cycles` is a deterministic test/automation bound, not a production
freshness timeout. A process killed without graceful drain can leave only the
last active complete generation and zgraphy-owned temporary/pending artifacts;
the next watcher or query repairs/drains them.

## Status and diagnostics

Watch JSON is versioned and reports only bounded, redacted data:

- statechart identity/version and current state;
- poll/debounce/retry bounds;
- observations, coalesced events, refresh attempts, successful/current
  refreshes, contention, retries, and failures;
- pending count and pending artifact fingerprint;
- initial, last observed, and last successful generation identities;
- last refresh trigger/status and repair action; and
- cancellation/drain outcome.

`status` and `doctor` report pending-queue health without claiming that a
watcher process is currently alive unless a separately validated live lease
proves it. No PID, absolute path, source body, credential, or raw error text is
persisted.

## Acceptance gates

The deterministic M3.7 scenario must prove:

1. the typed coordinator definition validates and every reachable nonterminal
   state has a bounded progress/cancellation path;
2. rapid duplicate Zig/TypeScript/Proto/document observations coalesce into one
   refresh after logical debounce;
3. a mixed edit/create/delete/rename batch publishes exactly the same graph,
   index, origin, and generation semantics as direct `ensureFresh` plus a clean
   build;
4. zgraphy runtime/output writes and ignored paths do not cause a refresh loop;
5. a nonblocking lease collision persists the request rather than dropping it;
6. the eventual lease holder drains preexisting and late-arriving requests in
   deterministic order, with a bounded maximum number of passes;
7. an event arriving during refresh causes a second pass and is acknowledged
   only after that pass succeeds;
8. refresh failure or stop request retains the prior active generation and a
   recoverable pending request;
9. corrupt, oversized, incompatible, path-traversing, or repository-mismatched
   pending artifacts fail closed and surface a repair hint;
10. watch output, pending artifacts, status, doctor, and causal evidence contain
    no absolute path, source body, token, or secret fixture value;
11. bounded churn respects queue, path, poll, retry, drain, memory, and
    generation-publication limits with no pending fibers; and
12. every M3.1-M3.6 scenario remains green and a subsequent default query is
    `current`, proving watch is an accelerator over the same barrier.

## Claim boundary

M3.7 earns a portable local foreground watcher, deterministic coalescing,
lossless bounded update coordination under lease contention, and graceful
between-phase cancellation. It does not earn kernel-event latency on every
platform, daemon installation, Git-hook mutation, preemptive cancellation
inside synchronous extraction, cross-process attach/wait deadlines, generation
retention, compaction, garbage collection, or one-file performance
superiority.
