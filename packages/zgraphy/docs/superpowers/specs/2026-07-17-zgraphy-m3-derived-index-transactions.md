# zgraphy M3.3: Selective Derived Records and Native Index Transactions

## Outcome

After M3.2 has reconstructed the current structural and resolved base graph,
zgraphy selectively reuses proof-carrying request-path hyperedges and feature
supernodes whose complete recipe inputs are unchanged. Changed, new, deleted,
or uncertain recipe inputs are recomputed or removed. Every candidate graph
also owns native relation-specific adjacency and field-aware lexical indexes
that are updated transactionally with canonical rows, validated before
publication, used by graph and keyword queries, and bound into the snapshot.

Canonical nodes, edges, hyperedges, supernodes, evidence and vectors remain the
authority. Secondary indexes and reuse are optimization layers. Missing,
incompatible, corrupt or uncertain optimization state may cost work but may
never preserve a stale record, invent a relationship, change graph meaning, or
weaken the M3.1 atomic activation barrier.

## Graphify leverage and deliberate improvements

M3.3 ports the behavior behind Graphify's incremental merge and pruning
regressions, especially:

- `tests/test_build_merge_hyperedges_and_prune.py`: preserve hyperedges owned by
  unchanged sources, replace re-extracted sources, prune deleted sources, and
  never delete a source that is simultaneously re-extracted;
- `tests/test_cache.py`: reject out-of-scope attribution, drop edges and
  hyperedges touching skipped identities, and preserve complete unchanged
  entries;
- `tests/test_incremental.py`: distinguish changed, unchanged and deleted
  source ownership; and
- `affected.py` plus `tests/test_affected_cli.py`: relation-filtered reverse and
  forward graph traversal.

zgraphy improves the contract by avoiding an untyped old-JSON/new-JSON union.
Reuse occurs only inside a complete unpublished candidate, through the same
typed `RepositoryGraph` validation entry points as a clean build. Each semantic
record has deterministic identity, local recipe-input fingerprint, direct
source evidence, live participants, and live proof edges. Candidate and clean
full fingerprints must agree.

## Two-phase candidate build

The M3.3 build has two deterministic phases:

1. Reconstruct all canonical placement, structural and resolved base records
   from validated M3.2 facts and current raw-source recipes.
2. Preview direct and reverse-transitive source invalidation from the previous
   extraction manifest and the current base graph, then materialize semantic
   aggregates by exact reuse or recomputation.

The final extraction manifest is computed after semantic materialization. Its
dependency graph may include additional evidence paths from a newly created
aggregate. Reuse decisions are safe because existing aggregate dependencies
come from the predecessor manifest, while a newly created aggregate has no
predecessor and is always computed. A final manifest or graph validation
failure aborts the candidate.

## Selective semantic aggregate reuse

The first selective recipe family is the existing exact cross-stack RPC
request path and end-to-end feature. For every current RPC interaction, zgraphy
resolves a bounded `RpcInteractionContext` containing:

- frontend invocation and exact Connect client binding;
- canonical Proto service, operation, request and response;
- registered Zig implementation container and exact handler;
- optional uniquely resolved UI consumer, data loader and focused test;
- source spans for every direct evidence input; and
- every typed proof edge required by the hyperedge and supernode.

The recipe-input fingerprint is local to that interaction. It must not include
the corpus-wide continuity result fingerprint, array position, unrelated
source, generation identifier, cache outcome or process-local statistic. It
hashes the recipe versions, canonical operation and message identities,
resolved participant IDs, observation source identities and spans, optional
adjacent participant IDs and the exact proof-edge triples.

An existing hyperedge/supernode pair is reusable only when all are true:

1. canonical kind/name and recipe versions match;
2. the prior interaction fingerprint equals the current local input
   fingerprint;
3. no prior direct-evidence source path is in the preview invalidation closure;
4. every prior participant and member exists in the current base graph;
5. every prior proof edge exists with the same direction and relation;
6. the supernode names the reusable hyperedge and its completeness remains
   valid; and
7. normal typed add/validation accepts both records in the candidate.

Reuse clones owned values into the candidate; it never aliases the previous
generation's allocator. If any condition is false, both records are rebuilt
from the current context. A predecessor interaction absent from the current
continuity result is not copied and is therefore pruned with all dependent
semantic state. Counters distinguish reused and recomputed hyperedges and
supernodes.

Changing the local fingerprint contract advances both recipe versions and the
generation recipe. An M3.2 generation remains readable rollback evidence but
receives one clean M3.3 rebuild before it can supply selective reuse.

## Native relation adjacency

NenDB's bounded structure-of-arrays topology gains derived indexes for:

- outgoing edge indices by `(node_id, relation)`;
- incoming edge indices by `(node_id, relation)`;
- all outgoing edge indices by `node_id`; and
- all incoming edge indices by `node_id`.

An edge append updates all four index views before it is visible. Partial index
failure rolls back every appended posting and the edge row. Failure to append
the owned model edge then rolls back the topology row and its index entries.
Duplicate model edges remain rejected before index mutation.

`hasEdge`, `hasOutgoingRelation`, bounded shortest-path traversal, hybrid graph
score propagation and future affected traversal use these indexes rather than
scanning the complete edge array. Direction and relation filters stay explicit;
the undirected shortest-path API visits both incoming and outgoing incident
lists without changing its existing semantics.

## Field-aware lexical postings

Each node transaction indexes normalized tokenizer terms from three separate
fields:

- `label` — highest weight;
- repository-relative `path` — medium weight; and
- `search_text` — semantic text weight.

A posting contains token hash, node row, field and bounded term frequency.
Terms are aggregated per field before insertion, so repeated text cannot create
unbounded duplicate rows. Posting insertion is all-or-nothing for a node; node
rollback removes every owned posting. Query-time scoring uses postings and
field weights, while the existing exact local vector column remains a separate
score. ANN and neural embeddings remain M6/M10 work.

The tokenizer and token hash remain deterministic and network-free. Hash
collisions have the same bounded false-match risk as the prior scan-based
keyword implementation and remain visible as a future term-dictionary upgrade;
they do not become semantic graph edges.

## Index invariants and fingerprint

`RepositoryGraph.validateSecondaryIndexes` proves:

- every live edge occurs exactly once in each required outgoing/incoming
  relation and incident list;
- every adjacency posting names a live edge with matching endpoint and label;
- every lexical posting names a live node and a valid field;
- each node's label/path/search terms and frequencies exactly equal its
  postings;
- no index entry is unowned, duplicated or outside configured bounds; and
- index counters equal recomputed canonical counts.

A deterministic secondary-index fingerprint sorts keys and postings before
hashing schema, counts and values. Hash-map iteration order, allocation
addresses and capacity never participate.

## Snapshot and generation contract

Snapshot v3 continues to store canonical rows as JSONL for inspectability. Its
header declares the secondary-index schema. The complete footer binds index
statistics and fingerprint. On load, zgraphy reconstructs indexes
transactionally while reading canonical rows, validates them, recomputes the
fingerprint and compares the footer. Snapshot v1 and v2 remain readable; their
indexes are rebuilt and validated but no absent historical digest is invented.

This is a deliberate derived-index persistence model: canonical rows are
durable and index integrity is durable evidence, while postings are rebuilt on
load. Persisted compact posting/adjacency columns, copy-on-write row deltas and
memory-mapped query structures remain later M3/M11 storage work.

Generation identity advances because snapshot schema, semantic recipe and
index contract changed. Candidate publication validates semantic records,
secondary indexes, snapshot reload, graph fingerprint and index fingerprint
before the sole active-pointer rename. Index corruption cannot activate.

## Query behavior

Hybrid retrieval preserves separate keyword, vector and graph contribution
fields. Keyword scoring uses the field-aware postings. Graph propagation uses
native incident adjacency. Vector scoring remains an exact bounded scan until
the M6 ANN gate. A query term appearing only in a node path must retrieve that
node with non-zero keyword contribution.

The public path result and hop/exhaustion behavior remain unchanged. Indexed
and scan-reference traversal must return the same deterministic shortest path.

## Acceptance gates

The deterministic M3.3 scenario must prove:

1. a cold fullstack build recomputes the request-path hyperedge and feature
   supernode and publishes valid non-empty adjacency and lexical indexes;
2. a warm explicit build reparses zero sources, reuses both semantic records,
   recomputes none, preserves their IDs, and keeps the same graph fingerprint
   and generation;
3. changing a source outside the semantic evidence set reparses only that file
   and still reuses both semantic records;
4. changing a direct proof/evidence source reparses only that file and
   recomputes both semantic records while preserving clean-full semantics;
5. removal of an interaction source leaves no old hyperedge, supernode,
   participant, proof, adjacency or lexical posting;
6. relation-specific outgoing and incoming adjacency return the exact canonical
   operation edge and bounded shortest path remains identical;
7. a path-only term is retrieved with non-zero keyword score;
8. snapshot-v3 reload rebuilds equal index statistics/fingerprint and rejects a
   mismatched declared index digest;
9. a cache-disabled clean build and the accumulated selective build have equal
   canonical graph and secondary-index fingerprints; and
10. staged/interrupted publication cannot expose partially updated canonical or
    index state.

Debug, ReleaseSafe, Testing v2 completeness, static safety, Graphify-derived
regression checks and current-source requirement evidence are mandatory.

## Claim boundary

M3.3 earns selective reuse for the exact RPC request-path/feature recipe and
native in-memory relation/lexical indexes with transactional maintenance and
digest-verified reconstruction. It does not claim selective reuse for every
future recipe, base node/edge delta persistence, persisted posting columns,
background watch, branch/worktree reconciliation, rename lineage, tombstones,
cache/generation GC, ANN, query-cache invalidation, or one-file performance
superiority. Those remain explicit M3/M6/M11 gates.
