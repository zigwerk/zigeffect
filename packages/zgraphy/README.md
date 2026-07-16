# zgraphy

`zgraphy` is a local-first, Zig-native repository knowledge graph. The current
M2 engine walks mixed-language repositories, preserves every safe file's
placement, derives application/package/library ownership from Zig, JavaScript,
Python, Rust, Go, Proto and ZigEffect manifests, deeply extracts Zig plus
TypeScript/TSX/JavaScript structure and module relationships, and stores graph
retrieval vectors in an embedded NenDB-derived snapshot.

The roadmap is Zig-first, not Zig-only. TypeScript/JavaScript frontends are an
early first-class target, with proof-carrying paths through generated
Connect/Protobuf or HTTP clients and schemas into Zig handlers, services,
effects, stores, tests, requirements, and runtime causal evidence.

Native source parsing is supplied by the reusable `zigeffect-parser` package
through the grammar-free `zigeffect-std.Parser` contract. zgraphy consumes its
bounded TypeScript/TSX/JavaScript and Proto facts and adds repository
resolution, graph identity, retrieval, and freshness rather than owning
language runtimes.
Resolution runs against one immutable discovery inventory and understands
relative ESM/CommonJS imports, JSONC tsconfig inheritance and aliases, pnpm/npm
workspaces, package exports and entry fallbacks. Each occurrence is retained as
a module-reference node with explicit resolved, external, unresolved,
ambiguous, invalid, or exhausted evidence; dynamic imports remain deferred.
The next pass resolves explicit named, default, namespace, local-alias, star and
long-chain barrel exports to source-qualified declarations. Scoped receiver
evidence connects imported direct calls, namespace members, static class calls,
local `new` bindings, bare typed parameters, fields and constructor properties
without repository-wide name fallback. Import aliases, re-exports, class-owned
methods, calls and instantiations are materialized as inspectable graph edges.
Connect client construction and member calls now join through strict
Protobuf-ES lineage to canonical Proto operations, while registered ZigEffect
`GeneratedDriverBinding` handlers join through protoc-gen-zig lineage. The
result exposes directed `invokes_operation` and `handles_operation` proof
edges; shared spellings alone never qualify. Each complete interaction now
materializes a native typed request-path hyperedge and a proof-carrying feature
supernode. The first recipe includes the frontend callback consumer, exact
client binding, canonical operation and messages, registered Zig container and
handler, data loader, and focused test when those adjacent relations resolve
uniquely. `zgraphy explain <node> --json` returns the bounded source spans,
participants, members, completeness, and proof steps rather than a similarity
summary.

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
zgraphy doctor . --json
zgraphy parity
zgraphy schema
zgraphy schema calls_direct --json
zgraphy contracts --json
zgraphy contracts provider --json
zgraphy security --json
zgraphy security ZG-THR-015 --json
zgraphy evaluation --json
zgraphy evaluation agent_task --json
zgraphy benchmark corpus
zgraphy benchmark lexical fullstack-orders --json
zgraphy benchmark zgraphy zig-ambiguity --json
zgraphy benchmark graphify zig-ambiguity path/to/graph.json --json
zgraphy benchmark matrix \
  --source-revision sha256:<source-digest> \
  --graphify-python 3.11.15 \
  --graphify-environment sha256:<environment-digest> \
  --json
zgraphy benchmark workload mutation-pruning cold-build --json
zgraphy benchmark resources .zgraphy/benchmarks/runs/resources/resource-samples.v1.json \
  --source-revision sha256:<source-digest> \
  --graphify-python 3.11.15 \
  --graphify-environment sha256:<environment-digest> \
  --machine sha256:<machine-digest> \
  --configuration sha256:<configuration-digest> \
  --json
zgraphy benchmark freshness .zgraphy/benchmarks/runs/freshness/freshness-transitions.v1.json --json
zgraphy query "where is causal graph persistence implemented?"
zgraphy explain LocalDatabase --json
zgraphy path ManagedRuntime LocalDatabase --max-hops 8
```

Every command supports versioned JSON where applicable:

```bash
zgraphy build . --json
zgraphy parity --json
zgraphy benchmark corpus --json
zgraphy query "repository indexing" --limit 10 --json
zgraphy explain fetchOrder --json
```

`init` creates config-v2 with one opaque persistent repository identity plus
`.zgraphyignore`, without replacing user configuration. `build` is a bounded
full rebuild in M1; `ingest` is an alias. It atomically writes the complete
snapshot, deterministic redacted content/ownership manifest, and graph-health
baseline under `.zgraphy/`. New snapshots use `zgraphy.nendb.snapshot.v2` to persist native
hyperedges and supernodes; snapshot-v1 remains a backward-readable rollback
input. Multi-generation publication and automatic refresh remain M3 work.
Readers reject incomplete footers or incompatible schema/embedder metadata.
`doctor` rebuilds current state in memory and reports
clean, stale, missing, incompatible, or corrupt evidence without mutating the
published graph.

`schema` validates and reports the content-addressed semantic contract. Passing
a relation name resolves its complete family policy, including endpoint roles,
evidence and ambiguity requirements, affected-query traversal, invalidation,
and external mappings. Snapshot-v2 now implements the hyperedge and supernode
subset while snapshot-v1 remains a readable rollback input; facts, claims and
immutable multi-generation publication are not yet claimed as fully persisted
schema-v2 records.

`contracts` validates and reports the operational boundary for provider
authority and lifecycle, shared extractor conformance, staged config-v2,
independent graph-health dimensions, redacted diagnostics, and rollback-safe
migration. Section inspection exposes policy without credentials or executable
provider configuration. The contract grants no process, network, database,
model, or out-of-repository filesystem authority.

`security` validates and reports the pinned threat catalog. Passing a threat ID
returns its severity, boundaries, assets, controls, Graphify references,
fixture evidence, milestone owner, and residual risk. Planned, deferred, and
absence-guard fixtures remain distinct from runtime-exercised evidence.

`evaluation` exposes the five explicit M0 receipt contracts: extraction,
retrieval, agent-task, performance, and resource. Retrieval, agent-task, and
performance remain visibly `schema_only`; they cannot support a measured claim
until held-out controlled receipts exist.

## What is indexed

M1 indexes:

- repository, directory, and safe mixed-language file placement;
- workspace-aware application, package, library, and nested-repository
  ownership from Zig/ZigEffect, package.json, pyproject, Cargo, Go and Buf
  manifests;
- functions, structs, enums, unions, and error sets;
- explicit `@import` edges and uniquely resolved local file imports;
- direct calls, including uniquely resolved cross-file call candidates;
- edge provenance (`extracted`, `inferred`, or `ambiguous`) and file/line
  evidence;
- ZigEffect components, requirements, checks, commands, scenarios, and source
  roots; and
- a bounded projection of `.zigeffect/graph/causal-graph.jsonl`.

The no-follow walker applies fixed cache/dependency exclusions plus root and
nested `.gitignore`/`.zgraphyignore` rules with anchored last-match negation.
Ignored, sensitive, binary, oversized, symlinked, unreadable and unsupported
inputs remain distinct terminal records with their responsible rule or policy.
Sensitive names are concealed and their content is never opened or hashed.
File, byte, depth, entry, node, edge, snapshot, and graph-hop limits are
explicit.

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

The public package exports a `RepositoryGraph` service/query effect for larger
applications and an `ApplicationInputs` root layer for its own CLI. Every
command runs through one process-level `zstd.ManagedRuntime`; its embedded
NenDB causal graph and application map are runtime-owned.

## Architecture and evidence

The product design and staged plan are checked in at:

- [`ROADMAP.md`](ROADMAP.md) — the comprehensive agent-first product roadmap,
  requirement catalogue, complete Graphify capability ledger, semantic model,
  benchmark programme, and release gates;
- [`docs/superpowers/specs/2026-07-16-zgraphy-m1-universal-discovery.md`](docs/superpowers/specs/2026-07-16-zgraphy-m1-universal-discovery.md);
- [`docs/superpowers/specs/2026-07-16-zgraphy-m1-operational-baseline.md`](docs/superpowers/specs/2026-07-16-zgraphy-m1-operational-baseline.md);
- [`../../docs/superpowers/specs/2026-07-16-zgraphy-design.md`](../../docs/superpowers/specs/2026-07-16-zgraphy-design.md)
- [`../../docs/superpowers/plans/2026-07-16-zgraphy-mvp.md`](../../docs/superpowers/plans/2026-07-16-zgraphy-mvp.md)

Graphify is pinned under `packages/references/graphify` as read-only product and
extraction reference material. NenDB is pinned under
`packages/references/nen-db`; zgraphy's reviewed Zig 0.16 adaptation records the
exact upstream commit in every snapshot and status response.

M0 is complete with an embedded, validated parity ledger at
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

M0 resource and freshness evidence is separated from quality. The standard
library-only `benchmarks/run_resource_baseline.py` supervisor uses `wait4` to
collect seven paired ReleaseSafe process samples after two warmups, then the
native resource aggregator recomputes integer p50/p95/p99 latency, CPU, peak
RSS, and persisted-byte statistics. `benchmarks/run_freshness_baseline.py`
applies modify, rename, and delete to disposable fixture copies and compares
each result with an independent clean build.

The checked freshness receipt proves full-rebuild equivalence, complete
snapshots, deletion pruning, and zero stale/dangling/orphan/vector defects. It
also records that the current path-derived identity preserves 0/2 required
symbols across rename and that semantic fact invalidation is not implemented.
Incremental update, automatic pre-query refresh, watch mode, automatic pruning,
repair, and garbage collection remain explicitly unsupported. The resource
receipt contains no performance claim.

The first schema-v2 foundation is now executable as
`src/semantic-schema.v2.json`, with strict typed validation in
`src/semantic_schema.zig` and its normative design in
`docs/schema-v2-rfc.md`. It declares eight semantic record concepts, 37 node
kinds, independent origin and epistemic-status axes, nine relation families,
96 canonical relations, every MVP and benchmark compatibility mapping, and
Graphify provenance projections. The contract is SHA-256 addressed; malformed
or incomplete registries fail closed. It deliberately does not yet implement
provider execution, schema-v2 persistence, or automatic refresh.

`src/operational-contracts.v1.json` and
`docs/operational-contracts-rfc.md` make the next foundation executable. The
contract distinguishes nine provider kinds and seven authorities, reconciles
six terminal unit outcomes, qualifies extractors over 13 shared dimensions,
defines six reproducible config modes and six health statuses across nine
independent dimensions, and requires validated atomic migration with a retained
last-good generation. It preserves Graphify's provider/reconciliation and
diagnostic strengths while preventing repository config, ambient credentials,
or partial provider output from silently widening authority or canonical truth.

`src/security-baseline.v1.json` and `docs/threat-model.md` cover 20 initial
threats across repository, filesystem, authority, parser, persistence,
provider, agent-output, causal, and export boundaries. Validation re-hashes five
pinned Graphify security files, verifies every exercised local evidence path,
and rejects broken references or false mitigation claims. High/critical gaps
remain explicitly owned by M1, M3, M5, M7, M8, M10, or M11.

Testing uses the ZigEffect Testing v2 server runner. The authoritative native
suite receipt is `.zigeffect/tests/suites/zgraphy-tests.json`; semantic
requirement receipts and replay commands are under `.zigeffect/tests/`.

## Current MVP boundary

All safe languages receive queryable placement and manifest-derived ownership.
Zig syntax enters through the compiler-owned AST, while the shared native
parser supplies exact TypeScript/TSX/JavaScript and Proto facts. Zig call
resolution and TypeScript module and symbol resolution preserve candidates and
typed ambiguity without name-only cross-file guesses. Export/barrel/default/
namespace flow, evidence-backed receiver calls, canonical Proto identities,
strict Protobuf-ES/protoc-gen-zig source lineage, and exact Connect-callsite to
ZigEffect-handler operation continuity are active. Native request-path
hyperedges, end-to-end feature supernodes, callback-versus-direct-call
semantics, exact nested Zig handler ownership, focused test coverage, semantic
snapshot round-trips, and proof-carrying explain output are also active. Deeper
Zig type/build resolution, HTTP paths, neural embeddings, ANN, incremental
watch and automatic pruning, MCP, editor installers, and visualisation remain
later slices.
