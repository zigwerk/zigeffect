# zgraphy

`zgraphy` is a local-first, Zig-native repository knowledge graph. The current
MVP walks a Zig repository, extracts files, declarations, imports, calls, and
ZigEffect project intent, then stores the graph and retrieval vectors in one
embedded NenDB-derived snapshot.

The roadmap is Zig-first, not Zig-only. TypeScript/JavaScript frontends are an
early first-class target, with proof-carrying paths through generated
Connect/Protobuf or HTTP clients and schemas into Zig handlers, services,
effects, stores, tests, requirements, and runtime causal evidence.

The target engine is self-maintaining after `init`: default agent queries check
freshness, publish safe incremental generations, prune invalidated facts and
true orphans, repair indexes, and garbage-collect owned stale data. It never
silently answers from a stale required graph dimension; failed refresh keeps the
last complete generation and returns typed stale/partial evidence.

Queries combine inspectable keyword, vector, and graph scores. The default
`feature_hash_v1` vectors are deterministic local code features, not neural
embeddings: there is no model download, API key, daemon, Docker service, or
network request.

An API key is not required for deterministic semantic extraction or the
planned Zig-to-TypeScript contract graph. Optional local neural embeddings need
a model download but no key. Any future remote semantic enrichment will be
explicitly opt-in and will declare provider, data scope, redaction, and spend
before repository content is sent anywhere.

## Build and install

```bash
zig build test
zig build test -Doptimize=ReleaseSafe
zig build install -Doptimize=ReleaseSafe --prefix "$HOME/.local"
```

The installed executable is `zgraphy`.

## Use

```bash
zgraphy init .
zgraphy build .
zgraphy status
zgraphy parity
zgraphy benchmark corpus
zgraphy benchmark lexical fullstack-orders --json
zgraphy benchmark zgraphy zig-ambiguity --json
zgraphy benchmark graphify zig-ambiguity path/to/graph.json --json
zgraphy benchmark matrix \
  --source-revision sha256:<source-digest> \
  --graphify-python 3.11.15 \
  --graphify-environment sha256:<environment-digest> \
  --json
zgraphy query "where is causal graph persistence implemented?"
zgraphy explain LocalDatabase
zgraphy path ManagedRuntime LocalDatabase --max-hops 8
```

Every command supports versioned JSON where applicable:

```bash
zgraphy build . --json
zgraphy parity --json
zgraphy benchmark corpus --json
zgraphy query "repository indexing" --limit 10 --json
```

`init` creates `.zgraphy/config.json` and `.zgraphyignore` without replacing
existing files. `build` is a bounded full rebuild in the MVP; `ingest` is an
alias. The complete snapshot is written transactionally to
`.zgraphy/nendb.jsonl`. Readers reject incomplete footers or incompatible
schema/embedder metadata.

## What is indexed

The MVP indexes:

- repository, directory, and Zig file placement;
- functions, structs, enums, unions, and error sets;
- explicit `@import` edges and uniquely resolved local file imports;
- direct calls, including uniquely resolved cross-file call candidates;
- edge provenance (`extracted`, `inferred`, or `ambiguous`) and file/line
  evidence;
- ZigEffect components, requirements, checks, commands, scenarios, and source
  roots; and
- a bounded projection of `.zigeffect/graph/causal-graph.jsonl`.

The walker applies fixed cache/dependency exclusions plus `.gitignore` and
`.zgraphyignore` exclusion rules. File, byte, node, edge, snapshot, and graph
hop limits are explicit.

## ZigEffect source bridge

ZigEffect remains the owner of runtime causal evidence; zgraphy owns repository
knowledge. Applications connect the two with a stable source reference:

```zig
const zgraphy = @import("zgraphy");

const source_ref = try zgraphy.ZigEffectBridge.sourceRefAlloc(
    allocator,
    "src/orders.zig",
    "createOrder",
);
defer allocator.free(source_ref);

try runtime.run(zgraphy.ZigEffectBridge.linkEffect(.{
    .source_ref = source_ref,
    .label = "orders.create",
}));
```

On the next `zgraphy build`, the safe causal projection becomes a
`causal_event` node with an `observed_at` edge to that exact source symbol. Raw
payloads and terminal output are not imported.

The public package also exports a `RepositoryGraph` service layer and query
effect so a larger ZigEffect app can compose zgraphy retrieval into its own one
process-level `zstd.ManagedRuntime`.

## Architecture and evidence

The product design and staged plan are checked in at:

- [`ROADMAP.md`](ROADMAP.md) — the comprehensive agent-first product roadmap,
  requirement catalogue, complete Graphify capability ledger, semantic model,
  benchmark programme, and release gates;
- [`../../docs/superpowers/specs/2026-07-16-zgraphy-design.md`](../../docs/superpowers/specs/2026-07-16-zgraphy-design.md)
- [`../../docs/superpowers/plans/2026-07-16-zgraphy-mvp.md`](../../docs/superpowers/plans/2026-07-16-zgraphy-mvp.md)

Graphify is pinned under `packages/references/graphify` as read-only product and
extraction reference material. NenDB is pinned under
`packages/references/nen-db`; zgraphy's reviewed Zig 0.16 adaptation records the
exact upstream commit in every snapshot and status response.

M0 execution has begun with an embedded, validated parity ledger at
`src/graphify-parity.v1.json`. `zgraphy parity --json` reports all 17 reviewed
Graphify capability families, their roadmap disposition, requirement,
milestone, reference modules/tests, and intended zgraphy improvement.

The second M0 slice adds the engine-neutral
`zgraphy.canonical-benchmark-ir.v1` contract and three source-grounded gold
fixtures under `benchmarks/`: Zig ambiguity, a TypeScript/Proto/Zig request
path, and modify/rename/delete pruning. Gold facts, relations, hyperedges,
supernodes, and retrieval tasks carry evidence spans whose source SHA-256 is
validated. `zgraphy benchmark corpus --json` exposes the corpus manifest and
summary without claiming performance superiority.

The pinned Graphify adapter now projects raw reference `graph.json` into
bounded canonical differential receipts while reporting missing, unexpected,
synthesized, evidence, and provenance outcomes separately. It never emits
Graphify's absolute-path-derived raw IDs. The reproducible local-only reference
runner is `benchmarks/run_graphify_reference.sh`; its ignored Python environment
is development evidence infrastructure, not a runtime dependency of zgraphy.

The native `zgraphy benchmark zgraphy <fixture-id> [fixture-root] --json`
adapter builds a bounded in-memory repository graph and projects it through the
same canonical receipt. It retains zgraphy-only directory, external-module, and
unresolved records as unexpected output, so internal implementation detail
cannot disappear from comparative precision metrics.

`zgraphy benchmark lexical <fixture-id> [fixture-root] --json` is the bounded
`rg`-class orientation floor. It indexes source-qualified files and unique
identifier tokens across Zig, TypeScript, TSX, JavaScript, and Proto. It emits
no calls, contracts, implementations, facts, hyperedges, or supernodes; only
canonical repository containment is projected for fair file orientation.

`zgraphy benchmark matrix` consumes the three pinned Graphify run outputs and
rebuilds the native and lexical projections in one process. Its
`zgraphy.quality-matrix.v1` receipt preserves all nine fixture/engine scores,
recomputes weighted aggregate counts, and records the canonical corpus digest,
zgraphy source revision, Zig target/toolchain, Graphify commit, Python version,
and Python environment digest. The receipt is deliberately
`baseline_only`, contains an empty `claims` array, and excludes latency,
memory, persisted size, and freshness until their M0 gate is implemented.
`benchmarks/run_graphify_reference.sh` now emits this matrix after the three
individual differential receipts.

Testing uses the ZigEffect Testing v2 server runner. The authoritative native
suite receipt is `.zigeffect/tests/suites/zgraphy-tests.json`; semantic
requirement receipts and replay commands are under `.zigeffect/tests/`.

## Current MVP boundary

Only Zig and ZigEffect intent/causal metadata are parsed today. Neural
embeddings, ANN, tree-sitter grammars for other languages, incremental watch
mode, visualisation, MCP, and editor installers are intentionally deferred.
