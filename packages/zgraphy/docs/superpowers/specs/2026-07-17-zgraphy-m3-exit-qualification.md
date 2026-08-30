# zgraphy M3.9: Churn Qualification and Correctness-Bound Graphify Performance

## Outcome

M3 exits only when zgraphy's self-manager remains semantically exact and
resource-bounded through sustained mixed repository churn, and a paired
ReleaseSafe process benchmark measures the real one-file managed update path
against the strongest local incremental path exposed by pinned Graphify
0.9.17. Correctness is a prerequisite to every performance ratio and claim.

This slice replaces the misleading use of `benchmark workload
one-file-modify` as incremental evidence. That legacy command calls the
in-process repository indexer directly and does not load, invalidate, publish,
retain, or collect managed generations. It remains a low-level extraction
observation but cannot support an incremental-product claim.

## Graphify behavior retained and improved

The pinned Graphify reference provides:

- content and stat-index cache keys;
- a versioned AST-cache namespace;
- `manifest.json` new, changed, unchanged, deleted and excluded detection;
- incremental `graphify extract` when an existing graph is present;
- stale-source reconciliation against both the manifest and live graph;
- a rebuild lease, queued hook changes, shrink detection and update/watch
  regressions; and
- process benchmark helpers that report timing and memory.

The M3.9 comparison uses Graphify's manifest-gated `extract` path without
`--force`, with `--code-only`, after a complete cold setup. The pinned 0.9.17
`--no-cluster` incremental path is excluded because a controlled self-host
probe shrinks a 2,121-node graph to the six changed-file nodes instead of
merging the live graph. The clustered path preserves the complete topology and
is therefore the fastest eligible Graphify path observed; an invalid fast arm
cannot be a performance baseline. zgraphy uses `init`, an initial managed
`build`, a one-file mutation, then the normal managed `build`/freshness
transaction. Both engines receive fresh copies of the same corpus and the same
mutation for every sample.

zgraphy improves the evidence boundary by requiring clean canonical graph and
index equivalence, complete publication, stale-record absence, bounded cache
and generation growth, and exact source/tool/configuration identities before
performance is comparison-eligible.

## Product boundary

M3.9 adds two native contracts and one external supervisor:

1. `zgraphy.m3-churn-receipt.v1` proves bounded semantic and storage behavior
   over an ordered long-churn sequence.
2. `zgraphy.performance-receipt.v1` implements the previously schema-only
   evaluation contract for paired one-file process samples.
3. `benchmarks/run_m3_qualification.py` owns disposable corpus copies,
   process isolation and OS peak-RSS observation. It cannot decide whether a
   claim passed; the Zig validator recomputes every aggregate and gate.

The zgraphy engine and persisted graph remain Zig-native. Python is an
untrusted benchmark supervisor because pinned Graphify itself is Python and OS
`wait4` evidence is outside the repository graph runtime. The native CLI reads
the bounded sample document, validates it strictly and emits the authoritative
receipt.

This slice does not claim held-out retrieval quality, agent-task superiority,
million-edge query latency, production multi-repository scale, a 24-hour soak,
or general product performance leadership. Those remain M6, M7 and M11 gates.

## Deterministic long-churn contract

The native acceptance sequence contains at least 32 state transitions over a
disposable mixed Zig, TypeScript and Proto repository. It repeatedly covers:

- one-file content replacement;
- file creation;
- exact-content rename and move;
- deletion;
- live-to-excluded and excluded-to-live transitions through
  `.zgraphyignore`;
- symbolic and detached Git context changes with no source mutation;
- unchanged refreshes;
- reader-deferred then successful collection;
- checkpoint/index damage followed by immutable repair; and
- repeated automatic collection with zero grace.

Each `Transition` records only bounded, redacted evidence:

- stable ordinal and operation;
- active generation and parent identity;
- graph and native-index fingerprints for accumulated and clean builds;
- checked, reparsed, cache-hit, cache-miss and invalidation counts;
- canonical delta and pruning summaries;
- graph health and active-pointer validity;
- generation count and bytes;
- current structural-cache entry count and bytes;
- retained extraction-manifest and delta-journal bytes;
- retention status and deletion/defer counts; and
- whether the default read returned current truth.

The receipt validator requires:

- exactly the declared ordered operation schedule and at least 32 transitions;
- equal accumulated/clean graph and native-index fingerprints after every
  source-affecting transition;
- branch-only and unchanged transitions to reparse zero files;
- one-file transitions to stay within their declared reparsing bound;
- zero dangling endpoints/participants, invalid proofs, true orphans, unowned
  indexes/vectors, stale source identities or incomplete snapshots;
- active generation and parent recovery artifacts to remain present;
- generation count, generation bytes, cache entries, cache bytes, manifest
  bytes and journal bytes to stay within explicit finite budgets;
- automatic GC to delete eligible history during the run;
- a reader-deferred collection to delete nothing and later converge;
- the final graph, indexes and origin ledger to equal a clean build; and
- no absolute repository path, source body, token, credential or raw process
  output in the receipt.

Budgets are inputs bound into the receipt and are derived from the configured
retention count plus fixed safety overhead. A test may use a small deterministic
fixture, but cannot set a budget from the observed maximum after the run.

## Paired one-file performance contract

### Corpus

The M3 qualification corpus is a content-addressed, locally materialised
self-host corpus containing zgraphy's source, tests, build/manifest contracts
and the canonical mixed TypeScript/Proto/Zig fixture. Generated state,
`zig-out`, caches, receipts, references and secrets are excluded. The exact
relative-path/content manifest is hashed and written into the sample identity.

The one-file mutation changes a fixed source file by a deterministic
semantics-preserving comment. It changes content and mtime while preserving the
expected public graph meaning outside that file. A second clean corpus with the
mutation already applied supplies zgraphy's canonical full-build equivalence
oracle.

### Sampling

- Darwin and Linux `wait4` are the initial qualified supervisors.
- The zgraphy binary must be ReleaseSafe.
- Graphify must be exactly version 0.9.17 at commit
  `cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780`.
- Remote/model credentials are removed from the environment and both arms are
  local code-only operations.
- Every arm gets two unrecorded warmups and at least seven retained samples.
- Every retained sample begins from a fresh corpus/state copy, performs its own
  cold setup outside the measured interval, applies the same mutation, then
  measures one process.
- Arm order alternates by repetition to reduce thermal/order bias.
- Timeouts, non-zero exits, incomplete output, mixed identities or missing
  resource evidence fail the run.

### Correctness gate

Every zgraphy sample must prove:

- one complete activated successor generation;
- exactly one reparsed source unit for the selected mutation and at least one
  cache hit;
- clean graph, index and origin validation;
- incremental and clean-full graph/index fingerprints equal;
- no stale pre-mutation entity for a changed identity;
- the default query/status path reads the new active generation; and
- retention remains healthy and bounded.

Every Graphify sample must prove:

- a complete parseable directed graph after the incremental extract;
- manifest recognition of the changed file;
- changed-source nodes are replaced rather than duplicated;
- no deleted/excluded stale source is carried into the measured fixture; and
- the shared supported projection does not regress from that arm's cold setup.

The sample document carries engine-specific correctness observations plus one
canonical correctness digest. The native validator rejects all samples if any
correctness flag, digest, count, or engine pair is incomplete. Counts do not
need to be equal across engines because their semantic schemas differ.

### Metrics and targets

Retained integer samples include wall latency, user/system CPU, peak RSS,
complete owned persisted bytes, node/relation counts and process exit state.
The Zig receipt recomputes min, p50, p95, p99 and max for each engine.

Ratios use integer basis points to avoid floating-point or formatting drift:

- speedup = `Graphify p50 latency / zgraphy p50 latency`;
- RSS ratio = `zgraphy p50 peak RSS / Graphify p50 peak RSS`;
- persisted ratio = `zgraphy p50 owned bytes / Graphify p50 owned bytes`.

The M3 target is at least 5x median one-file speedup (50,000 speedup basis
points) and no more than 50% of Graphify's median peak RSS (5,000 ratio basis
points). Persisted size is reported and must satisfy the churn/storage budget,
but M3 does not invent a relative persisted-size superiority threshold.

If correctness and identity pass but either performance target misses, the
receipt remains valid and comparison-eligible with `performance_gate_passed =
false`, no superiority claim, and an explicit measured deficit. Benchmarks
must never be tuned by dropping unfavorable retained samples.

## Receipt identity and claim policy

The performance receipt binds:

- workload ID and corpus digest;
- zgraphy source revision;
- machine, OS, architecture and target;
- Zig, Python, Graphify and supervisor versions;
- ReleaseSafe optimization mode;
- adapter and provider versions;
- exact command/configuration digest;
- sampling counts;
- quality/resource/correctness digests; and
- every retained raw integer sample.

The only claim M3.9 may emit is the scoped statement that the identified
zgraphy ReleaseSafe one-file managed update met both declared targets against
the identified Graphify build on the identified machine and corpus. It cannot
be generalized to other corpora, machines, workloads or future versions.

The global evaluation claim policy remains `baseline_only` while retrieval and
fixed-agent evaluations are schema-only. M3.9 promotes only the performance
definition to an active scoped baseline.

## CLI surface

The native surface becomes:

```text
zgraphy benchmark churn <observations.json> --json
zgraphy benchmark performance <samples.json> \
  --source-revision <sha256> \
  --machine <sha256> \
  --configuration <sha256> \
  --correctness <sha256> \
  --quality <sha256> \
  --resources <sha256> \
  --graphify-python <version> \
  --graphify-environment <sha256> \
  [--warmups N] [--repetitions N] --json
```

Human output reports both targets, measured ratios and claim status. JSON is
the authoritative versioned receipt. The supervisor writes raw samples under
`.zgraphy/benchmarks/runs/m3-qualification/`; no benchmark output becomes an
active repository graph input.

## Failure and safety semantics

- Sample and observation files have independent byte/count bounds.
- Unknown fields, duplicate sample keys, noncanonical order, zero/overflowing
  metrics, impossible quantiles and inconsistent aggregates fail closed.
- Ratios use checked integer arithmetic and reject overflow.
- Paths in receipts are corpus-relative identities only; absolute roots and
  usernames are rejected by the supervisor and native acceptance scenario.
- The supervisor never follows corpus symlinks and excludes generated/runtime
  state from copies and size accounting.
- No network call or API key is required or permitted.
- Raw stdout/stderr is retained only as bounded local diagnostics and is not
  copied into native receipts or the semantic graph.
- A benchmark failure never mutates the checked-in baseline automatically.

## Acceptance gates

Profile-driven implementation repairs are governed by
`2026-07-17-zgraphy-m3-performance-repair.md`. Lazy bounded NenDB columns,
prepared parser-result reuse and indexed origin validation may remove redundant
work, but must preserve every correctness, identity, churn and claim invariant
in this specification.

The required `m3-exit-qualification` Testing v2 scenario must prove:

1. malformed, duplicated, incomplete, mixed-identity and correctness-failed
   churn/performance inputs are rejected;
2. quantiles and integer ratios are recomputed rather than trusted;
3. claims appear only when both 5x latency and 0.5x RSS targets pass;
4. a valid target miss remains honest, comparison-eligible evidence with no
   claim;
5. at least 32 actual managed transitions cover every operation family;
6. every accumulated graph/index equals a clean build and remains healthy;
7. one-file and branch-only reparsing bounds hold;
8. GC bounds generation/cache/journal growth and converges after reader
   deferral;
9. repair publishes a healthy immutable successor without losing the previous
   fallback;
10. the final query is current and source/provider origin truth remains exact;
11. receipt encoding is bounded and contains no absolute root, source body or
    secret fixture marker;
12. a ReleaseSafe external run produces a complete paired receipt, or its
    target miss remains explicitly unpromoted; and
13. all prior M3 scenarios, Debug/ReleaseSafe suites, Testing v2 migration and
    project agent gates remain green on current source.

## M3 exit and nonclaims

M3 closes when the deterministic churn gate passes and a current-source paired
receipt satisfies the two declared Graphify targets. If the functional gates
pass but a target misses, M3.9 is implemented but M3 remains open while the
measured bottleneck is profiled and repaired.

Even after M3 closes, the result is a scoped one-file update claim, not a claim
that zgraphy is universally faster, leaner, more accurate, or more useful to
agents. Those broader claims require the later held-out retrieval, agent-task,
scale and production-hardening milestones.

## Qualification result

M3 is closed by the current-source paired ReleaseSafe receipt. With one warmup
and seven samples, zgraphy records a 97,703,291 ns median managed one-file update
and 14,794,752-byte median peak RSS; pinned Graphify 0.9.17 records 547,151,584
ns and 79,200,256 bytes. The recomputed comparison is a 5.6001x latency speedup
and 0.1868x RSS ratio, passing both declared gates.

The deterministic qualification and complete Debug/ReleaseSafe Testing v2
suites pass 43/43 with no pending tests, leaks or logged errors. The final agent
check passes with zero forbidden source-policy findings. The scoped claim and
all later-milestone nonclaims remain exactly as defined above.
