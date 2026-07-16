# zgraphy M2.6: Native Request-path Meaning

## Outcome

zgraphy turns the exact cross-stack interaction proved in M2.5 into native,
queryable semantic records:

- a request-path hyperedge with unique typed participants and direct source
  evidence;
- a feature supernode with typed membership, an explicit completeness state,
  deterministic synopsis and proof steps that name existing graph relations;
- deterministic binary projections for ordinary traversal; and
- a backward-readable NenDB snapshot that persists these records without
  rewriting an existing v1 snapshot in place.

The semantic records are produced only after the TypeScript invocation and Zig
handler resolve to the same canonical Proto operation. They never recover a
contract by comparing names, labels, embeddings or graph proximity.

## Inputs and authority

The sole contract join authority is `rpc_continuity.Result.interactions`.
M2.6 may enrich an interaction with evidence already proved by its observations
and with exact graph relations produced by deterministic language resolvers.
It may not independently search for a same-named operation or handler.

The initial recipe consumes:

1. the exact frontend callable and generated-client binding recorded by the
   frontend RPC observation;
2. the canonical operation plus request and response message identities from
   the Proto resolver snapshot bound to that interaction;
3. the exact Zig implementation container and handler recorded by the backend
   RPC observation; and
4. optional one-hop, already-resolved graph evidence for a UI callback
   consumer, backend data loader and focused test.

Optional adjacent members are included only through an exact edge with source
evidence. Their absence makes the feature aggregate partial; it does not cause
name-based recovery.

## Native records

### Source evidence

Every semantic record carries bounded direct evidence. A source-evidence item
contains a typed evidence role, repository-relative path and exact byte plus
line/column span. It contains no source body, absolute path or credential.

### Request-path hyperedge

A request-path hyperedge has:

- a stable record ID;
- kind `request_path`;
- canonical operation identity;
- recipe `rpc-request-path-v1`;
- a non-empty interaction fingerprint;
- unique participant roles and unique node IDs;
- direct source evidence; and
- generation-local validity through the containing repository graph.

Mandatory roles are:

- `frontend_callsite`;
- `client_binding`;
- `canonical_operation`;
- `request_message`;
- `response_message`;
- `implementation_container`; and
- `backend_handler`.

Optional roles in this slice are `ui_consumer`, `data_loader` and
`focused_test`. A participant must reference a live node. Duplicate roles,
duplicate nodes, missing mandatory roles, invalid spans, evidence-free records
and ID collisions fail closed.

### Feature supernode

The first supernode recipe is `end-to-end-feature-v1`. Its stable identity is
derived from the input request-path hyperedge, not from community detection.
It records:

- kind `feature`;
- canonical operation and bounded display name;
- typed members with deterministic reasons;
- direct evidence inherited from the request path;
- an input hyperedge ID;
- proof steps whose endpoints and relations must exist in the binary graph;
- completeness (`contract_path` or `end_to_end_feature`);
- a deterministic bounded synopsis; and
- the recipe version.

`end_to_end_feature` requires the UI consumer, frontend callable, operation,
backend handler, data loader and focused test. A contract-complete interaction
without all optional adjacent evidence remains `contract_path` and is still a
valid request path.

## Binary projections and missing semantic relations

M2.6 retains the M2.5 `invokes_operation` and `handles_operation` projections.
It also emits only source-grounded relations needed to expose the complete
path:

- frontend callable `calls` its exact generated-client binding;
- client binding `generated_from` the canonical Proto service;
- a function passed as a callback is `passes_callback`, not mislabeled as a
  direct call;
- a containing Zig declaration `declares` its nested handler; and
- a Zig test `covers` a uniquely resolved handler it invokes.

The benchmark-v1 adapter may project `passes_callback` to its older `calls`
bucket, but the native ontology retains the more precise relation.

## Persistence compatibility

`zgraphy.nendb.snapshot.v1` remains a supported rollback/read input and the
published migration source identifier. New complete saves use
`zgraphy.nendb.snapshot.v2` and add `hyperedge` and `supernode` records plus
footer counts. Loading v1 yields an empty semantic-record set. Loading v2
requires every participant, member and proof endpoint to validate before the
graph is returned.

Saving is atomic through an exclusive temporary slot and rename. An incomplete,
unknown, over-bound or dangling semantic snapshot is rejected. M3 will place
this format inside immutable multi-generation publication; M2.6 does not claim
transactional generations or automatic refresh.

## Agent query behavior

`zgraphy explain <node> --json` reports matching request paths and feature
aggregates alongside ordinary degree information. Output is bounded and
proof-carrying: participants resolve to concrete nodes, evidence carries exact
source locations and supernode proof steps name existing relations.

The first supported questions are:

- which backend handler implements this frontend call;
- which canonical operation and messages cross the boundary; and
- which UI consumer, loader and test are part of the same proved feature.

## Determinism and limits

Record order is independent of discovery order. Participants, evidence,
members and proof steps are canonicalized before stable IDs and fingerprints
are computed. All record counts and nested arrays are bounded by graph options.
Adding one record beyond a configured bound returns a typed limit error and
does not partially publish the record.

## Differential and acceptance gates

On the source-hashed `fullstack-orders` fixture, zgraphy must produce exactly
one resolved request-path hyperedge and one end-to-end feature supernode. The
native differential adapter must match:

- 16/16 canonical entities;
- 22/22 canonical relations;
- 2/2 canonical facts;
- 1/1 request-path hyperedge; and
- 1/1 feature supernode.

The lookalike local client and unregistered Zig service produce no interaction,
hyperedge or supernode. Forward and reverse corpus ingestion produce identical
semantic fingerprints. Save/load preserves all nodes, edges, vectors,
hyperedges, supernodes and the complete graph fingerprint.

Graphify remains measured from its pinned 0.9.17 output. Its absence of the
canonical Proto operation, complete interaction, native fact, hyperedge and
supernode is reported as a measured semantic-quality gap; no new performance,
memory or storage superiority claim is made without a fresh controlled run.

## Deferred work

This slice does not implement HTTP request paths, arbitrary callback shapes,
schema compatibility impact, build-target/application/API-surface recipes,
immutable generations, incremental invalidation, automatic pre-query refresh,
watch mode, model claims, ANN or visualisation. M3 owns freshness and pruning;
later M2/M4 slices broaden the meaning recipes.
