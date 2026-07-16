# zgraphy canonical benchmark corpus

This directory is the engine-neutral truth set used to compare zgraphy,
Graphify, lexical baselines, and later ablations. Graphify output is a baseline;
the reviewed source fixtures and canonical gold records are ground truth.

`corpus.v1.json` pins the Graphify baseline and declares every fixture,
language, capability, and ordered mutation. `gold/*.canonical.v1.json` uses the
`zgraphy.canonical-benchmark-ir.v1` contract implemented in
`src/benchmark.zig`. `fixtures/` contains the immutable source inputs.

The current corpus covers:

- Zig imports, qualified identity, and candidate-preserving ambiguity;
- a Solid TypeScript callsite through a Connect-style client and canonical
  Proto method into a Zig handler, loader, and focused test;
- a proof-carrying request-path hyperedge and feature supernode;
- orientation, explanation, change-impact, ambiguity, and freshness retrieval
  expectations; and
- ordered modify, rename, and delete outcomes requiring invalidation, stable
  identities where declared, complete stale-node pruning, and no orphaned
  secondary records.

Every evidence span includes the SHA-256 of its entire source file. The native
acceptance scenario reads each file, verifies that hash and span bounds, then
validates all entity, relation, fact, hyperedge, supernode, and retrieval-task
references. Mutation replacement payloads are hash-pinned too. A fixture edit
therefore fails closed until its expected semantics are deliberately reviewed.

Run the contract gate with:

```bash
zgraphy benchmark corpus --json
zigeffect test run --requirement req-m0-canonical-benchmark-corpus --json
```

## Pinned Graphify adapter

Graphify is an external reference runner only. Its Python runtime is installed
into the ignored `.zgraphy/` benchmark area and is never required by the
zgraphy executable:

```bash
python3.11 -m venv .zgraphy/benchmarks/graphify-0.9.17
.zgraphy/benchmarks/graphify-0.9.17/bin/python -m pip install -e ../references/graphify
zig build install -Doptimize=ReleaseSafe
benchmarks/run_graphify_reference.sh
```

The runner refuses any reference commit other than
`cb96bdaa0c367bec8d5c5aee5d7c9ebb727e9780` or package version other than
`0.9.17`. It forces Graphify's local `--code-only --no-cluster` path, removes
known model credentials from the child environment, writes raw output only to
the ignored benchmark run directory, and emits one
`zgraphy.differential-receipt.v1` JSON object per fixture.
After all three reference runs it also executes `zgraphy benchmark matrix` and
emits one `zgraphy.quality-matrix.v1` receipt. The matrix command independently
rebuilds the zgraphy and lexical results, requires explicit source, Python, and
environment SHA-256 identities, and recomputes aggregate scores from integer
counts rather than averaging fixture percentages.

The native `zgraphy benchmark graphify <fixture-id> <graph.json> --json`
adapter maps source-qualified Graphify nodes and directed relations to the
canonical gold graph. It reports synthesized compatibility structure, missing
gold IDs, unexpected node labels, unexpected relation kinds, source-line
agreement, and provenance agreement separately. Raw Graphify IDs are never
emitted because upstream IDs can contain absolute local paths.

`zgraphy benchmark zgraphy <fixture-id> [fixture-root] --json` performs the
same projection directly from zgraphy's native in-memory graph. A fixture root
may be narrower than the corpus root for ordered mutation states; canonical
source matching accepts only exact paths or directory-boundary suffixes. It
does not collapse same-named files from unrelated directories.

`zgraphy benchmark lexical <fixture-id> [fixture-root] --json` walks the same
bounded source corpus and records one source-qualified node for each file and
unique ASCII identifier. This approximates `rg` plus direct-file orientation:
it can find names across Zig, TypeScript/TSX, JavaScript, and Proto, but it has
no relationship parser. The adapter therefore projects repository containment
only and leaves every semantic relation, fact, hyperedge, and supernode
missing. Tokens from strings and comments remain visible, matching the noisy
lexical baseline rather than silently improving its precision.

The current measured quality layer projects Graphify, zgraphy, and lexical
outputs into this IR. Projection loss and unsupported records stay visible in
the fixture receipts, while the quality matrix records exact corpus, source,
Graphify, Python-environment, and Zig-toolchain identity. Its checked-in M0
baseline is under `benchmarks/baselines/`.

The current baseline is engineering evidence, not a superiority claim. It
contains no latency, peak-memory, persisted-size, update-equivalence, or
freshness result. Those dimensions are the next M0 gate and must be collected
under bounded, repeated workloads before any performance language is allowed.

## Resource and freshness baselines

Build the ReleaseSafe binary, then run the process-isolated resource and
mutation supervisors:

```bash
zig build install -Doptimize=ReleaseSafe
.zgraphy/benchmarks/graphify-0.9.17/bin/python benchmarks/run_resource_baseline.py
python3 benchmarks/run_freshness_baseline.py
```

`run_resource_baseline.py` requires Darwin or Linux `wait4`, removes known
model credentials from child environments, performs two excluded warmups and
seven retained runs per engine, validates every output through zgraphy, and
writes raw logs only below ignored `.zgraphy/benchmarks/runs/resources/`.
The native `zgraphy.resource-matrix.v1` aggregator retains all samples and
recomputes integer nearest-rank statistics. Peak RSS is reported only from the
process supervisor.

`run_freshness_baseline.py` reconstructs disposable observed and clean states
for modify, rename, and delete. Every state is rebuilt, saved, loaded, health
checked, fingerprinted, and compared. The checked receipt honestly fails the
future freshness target because path-derived IDs do not survive rename and
semantic facts are not yet present to invalidate, while still proving that a
full rebuild publishes no stale, dangling, or orphaned active records.

Checked candidate evidence lives in:

- `baselines/resource-matrix.v1.json`;
- `baselines/freshness-receipt.v1.json`; and
- `baselines/quality-matrix.v1.json`.

These receipts have empty `claims` arrays. They do not authorize “faster” or
“leaner” product language, and full-rebuild pruning is not described as
incremental or automatic self-maintenance.
