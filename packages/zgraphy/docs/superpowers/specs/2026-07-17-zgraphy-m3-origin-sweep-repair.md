# zgraphy M3.6: Origin-Owned Sweep and Automatic Repair

## Outcome

zgraphy publishes an active graph only when every canonical record has exactly
one live, validated origin owner and every retained reference is valid. A
structural refresh preserves unchanged document, compiler, model, runtime,
historical, and user-owned contributions, replaces explicitly refreshed
contributions, and removes only records whose owner, dependency, or typed proof
is no longer valid. Degree-zero records with live ownership remain legitimate;
unowned rows and broken references never become an active generation.

When a complete generation becomes unreadable or its derived indexes no longer
match canonical rows, the pre-query freshness barrier attempts the smallest
safe repair. Repair constructs and validates a new immutable generation while
the last-good active pointer remains unchanged. A repaired generation is never
written over the damaged generation and a failed repair never turns a corrupt
or stale condition into a healthy report.

## Graphify leverage and deliberate improvements

M3.6 carries forward the behavior proven by Graphify regressions #1574, #1571,
and #1796:

- hyperedges and other contributions from unchanged files survive an update;
- re-extracted source contributions replace their old contribution;
- genuine deletion removes source-owned nodes, edges, and hyperedges;
- changed-and-pruned input is treated as replacement, not deletion; and
- path normalization cannot leave root-less or symlink-root ghost records.

Graphify implements those rules by comparing `source_file` strings while
merging mutable JSON. zgraphy improves the boundary by:

- assigning every active node, edge, hyperedge, supernode, vector, and derived
  index row to a typed origin owner;
- separating provider identity and dependency freshness from edge confidence;
- carrying only records whose owner and dependencies still validate;
- preserving legitimate isolated and externally registered identities;
- applying mark, reference validation, and sweep inside an unpublished
  candidate;
- rebuilding all vectors and secondary indexes from the surviving canonical
  rows;
- binding an origin ledger and sweep report into immutable generation identity;
  and
- repairing through a typed escalation plan and a new generation rather than
  mutating or silently shrinking the active database.

## Origin ownership contract

`zgraphy.origin-ledger.v1` is a bounded, canonical generation artifact. It has
three concepts:

1. An owner records one origin tier, provider identity, provider fingerprint,
   provider freshness, authority class, and sorted content dependencies.
2. A record reference names one canonical graph record: node ID, edge triple,
   hyperedge ID, or supernode ID.
3. An ownership entry assigns one record reference to exactly one owner.

The initial origin tiers are:

- `source_syntax`;
- `source_documentation`;
- `manifest`;
- `build_contract`;
- `version_control`;
- `zigeffect_metadata`;
- `compiler_index`;
- `runtime_causal`;
- `resolver_recipe`;
- `model_suggestion`;
- `human_confirmation`; and
- `historical_lineage`.

Origin is orthogonal to `Provenance`. `Provenance.extracted`, `inferred`, and
`ambiguous` continue to describe how a relationship was established. Origin
describes who owns its lifecycle and what can invalidate it.

Provider IDs are bounded opaque identifiers, never credential-bearing URLs.
Provider fingerprints are SHA-256 identities over version/config/model inputs
that are already safe to persist. Dependencies contain normalized relative
paths and exact content digests only. Absolute paths, source bodies, API keys,
provider responses, and causal payloads are forbidden.

The native indexer assigns deterministic owners to source, manifest, build,
ZigEffect, and resolver records. Future document, compiler, runtime, and model
providers submit an explicit `OriginOverlay` through the public operations
boundary. An overlay contains a complete graph closure for validation plus an
explicit set of records it owns; closure records may reference existing source
identities but cannot steal their ownership.

## Carry-forward and replacement rules

The candidate begins with the newly built deterministic source graph and its
native ownership entries. It then reconciles previous origin owners and any
explicitly refreshed overlays:

- a prior owner not refreshed in this update is carried only when its provider
  fingerprint remains compatible, its freshness state permits active use, and
  every dependency still has the same current digest;
- an explicitly refreshed owner replaces all prior records owned by the same
  provider identity before new records are added;
- replacement wins when an input is also present in the prune set;
- a deleted, excluded, changed, expired, incompatible, or explicitly removed
  dependency invalidates only records owned through that dependency;
- multiple supporting owners may justify equivalent facts in future schema-v2
  storage, but one physical v1 graph record has exactly one lifecycle owner;
  conflicting duplicate ownership fails closed in this slice;
- stale provider output is not served as active graph truth. Its last complete
  generation remains available to retention/history policy, while the new
  active ledger records the typed sweep reason; and
- no prior record is copied merely because its ID is absent from the new source
  graph.

## Mark, validate, and sweep

Pruning runs entirely inside the unpublished candidate:

1. Canonicalize native and overlay record references.
2. Mark owners whose identity, authority, freshness, bounds, and dependencies
   validate against the current content manifest.
3. Mark every record assigned to a live owner, including degree-zero source
   nodes, registered external identities, ambiguity candidates, historical
   lineage records, and human pins.
4. Re-evaluate edges, hyperedge participants/evidence, supernode members/input
   hyperedges/proof steps, vectors, and index ownership in dependency order.
5. Sweep unmarked or invalid records in supernode, hyperedge, edge, then node
   order so no surviving row can reference a removed row.
6. Reconstruct vectors, relation adjacency, lexical postings, and index
   fingerprints from the surviving nodes and edges.
7. Validate exact origin coverage, graph health, semantic records, secondary
   indexes, canonical fingerprint, and clean-build equivalence where the same
   providers are available.

An active node is not an orphan merely because it has degree zero. It is a true
orphan only when it lacks a live owner and all protected/reference/retention
bases in the roadmap definition. In v1, exact ownership coverage makes an
unowned active node a publication error; the sweep removes it only when it came
from a prior or optional overlay. An unowned record emitted by the current
native build or explicitly refreshed provider fails closed because silently
deleting current producer output would hide a producer bug.

The sweep report records counts by record kind, origin tier, and reason. Initial
reasons are `owner_replaced`, `dependency_changed`, `dependency_deleted`,
`dependency_excluded`, `provider_stale`, `provider_incompatible`,
`dangling_reference`, `invalid_proof`, `unowned_prior_record`, and
`reconciled_absent`. Vectors and secondary-index rows are reported as derived
pruning owned by their surviving node/edge set.

## Generation integration

Generation schema v6 owns `origin-ledger.json` and `repair-report.json` in
addition to the M3.5 artifacts. The active pointer and generation metadata bind:

- origin schema, artifact path, input fingerprint, final fingerprint, owner and
  record summaries, and sweep summary;
- repair schema, artifact path, plan fingerprint, action summary, source
  generation, and completion state; and
- a `replaces_generation` identity separate from the canonical delta parent.

`parent_generation` continues to mean that the canonical delta can replay from
that exact graph. `replaces_generation` names the active generation that caused
repair or clean reconstruction even when its graph cannot safely serve as a
delta parent. This distinction prevents a clean repair from reusing and
overwriting the damaged generation directory.

Candidate validation independently reads the origin ledger, recomputes every
owner and record identity, proves exact graph coverage, replays the canonical
delta, validates the repair report, and checks all artifact paths before the
sole active-pointer rename.

## Automatic repair escalation

`zgraphy.repair-report.v1` records an inspectable bounded plan and the actions
actually completed. The initial automatic ladder is:

1. `rebuild_secondary_indexes`: canonical node/edge rows decode and match the
   graph fingerprint but indexed footer evidence is missing or mismatched;
2. `rebuild_checkpoint`: the active snapshot cannot serve, but exact
   parent-plus-journal replay reconstructs the active graph;
3. `replay_extraction_cache`: source manifests are readable and validated
   content-addressed structural facts can build a successor without parsing
   unchanged files;
4. `widen_invalidation`: a dependency closure is uncertain, so source parsing
   expands to the owning package/application boundary; and
5. `clean_rebuild`: active graph, journal, cache, schema, identity, or invariant
   evidence cannot support a narrower repair.

The first implementation may terminate at the first applicable safe action and
must record unsupported wider actions rather than claim them. A successful
index/checkpoint repair publishes a distinct successor and should require zero
source reparses when its extraction manifest remains valid. A clean rebuild may
reparse bounded repository inputs, but it must retain the old pointer until the
new candidate is complete.

Candidate rejection is an invariant rather than a mutating repair: a corrupt
staged candidate is abandoned and the active generation remains byte-for-byte
unchanged. Repeated repair failure returns a typed unhealthy state and exact
replay command. Repair never edits generation artifacts in place, deletes
diagnostics, writes outside `.zgraphy`, or consults network/ambient credentials.

## Status and doctor

Build/status expose bounded origin owner/record counts, carried/replaced/swept
counts, sweep reasons, and repair action/result. Doctor independently validates
the active origin and repair artifacts and reports the `providers`, `semantics`,
`indexes`, and `self_manager` dimensions separately. A graph reconstructed from
parent plus delta is `degraded` until an immutable repaired checkpoint is
published; it is never silently reported as a healthy full snapshot.

## Acceptance gates

The deterministic M3.6 scenario must prove:

1. every native source graph record has exactly one canonical origin owner;
2. an unchanged document/compiler/model/runtime overlay survives a structural
   one-file update while old source-owned rows are replaced;
3. a genuinely deleted or content-changed dependency removes only its owned
   overlay closure and records the exact sweep reason;
4. refreshed contribution replacement wins over simultaneous prune intent;
5. degree-zero source nodes, registered external identities, ambiguity
   candidates, historical lineage records, and explicit human pins survive;
6. unowned current output, conflicting ownership, dangling endpoints,
   incomplete hyperedges, invalid supernode proof, malformed dependency paths,
   and corrupt origin fingerprints block candidate activation;
7. vectors and native indexes are rebuilt exactly from surviving canonical rows
   and accumulated output equals a clean build with the same live overlays;
8. an index-footer or checkpoint failure publishes a distinct zero-parse repair
   successor while retaining the damaged generation immutably;
9. corrupt snapshot-plus-journal evidence escalates to a distinct clean rebuild
   without moving the pointer until the candidate validates;
10. a corrupt staged candidate leaves the prior active generation unchanged;
11. status, doctor, metadata, origin, and repair artifacts are bounded,
    digest-bound, and contain no absolute path, source body, token, or secret;
    and
12. all prior M3 generation, cache, index, delta, lineage, interruption, and
    clean-equivalence scenarios remain green.

## Claim boundary

M3.6 earns exact active-record origin ownership, provider-safe carry-forward,
transactional mark/validate/sweep, and the bounded repair actions exercised by
the acceptance scenario. It does not claim background watch, provider network
refresh, TTL scheduling, persisted column-level mutation, modified-content
rename inference, older-ancestor search beyond validated parent recovery,
bounded generation/cache retention, compaction, garbage collection, or
one-file performance superiority. Those remain later M3 and M11 gates.
