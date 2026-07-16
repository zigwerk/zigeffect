# RFC: zgraphy semantic schema v2

Status: M0 contract candidate; persistence not implemented

Version: `zgraphy.semantic-contract.v2`, schema version 2

## Purpose

zgraphy needs a semantic model that can answer agent questions without turning
parser guesses, resolver decisions, runtime observations, and model suggestions
into indistinguishable graph edges. Schema v2 separates stable identity,
evidence, atomic facts, resolved relationships, derived claims, n-ary meaning,
semantic aggregates, and immutable generations.

This RFC is normative for new semantic producers. The embedded machine
contract and its validator are normative for names, relation policy, and
compatibility mappings. Snapshot v1, config v1, benchmark IR v1, and existing
CLI response schemas remain supported until separate migrations are implemented
and qualified.

## Core records

### Entity

An entity is one stable namespaced identity. Its required fields are identity,
versioned kind, canonical and display names, repository/workspace identity,
generation validity, and producer namespace. Optional placement, language,
fingerprint, searchable text, and synopsis fields are bounded properties backed
by facts and evidence.

Movable semantic entities must not use a source path as their only identity.
Qualified namespace, symbol kind, canonical signature, contract/build identity,
and repository identity participate where available. File identity remains
path-scoped within a generation; rename continuity is an evidence-backed
lineage claim rather than a fuzzy mutation of history.

### Evidence

Evidence is a durable pointer to an observation. Its variants include source
span, manifest/build record, generated contract, version-control object,
deterministic parser output, ZigEffect requirement/test receipt, bounded runtime
causal fact, model suggestion, and human confirmation. Source evidence records
repository-relative path, content digest, byte range, and line/column range.
Evidence never embeds an absolute user path, credential, or unbounded source
body.

### Fact

A fact is an immutable atomic assertion with subject, predicate, value or target
candidate, evidence, producer and version, input/generation fingerprints,
origin, epistemic status, optional calibrated confidence, alternatives,
rejection reasons, and invalidation keys. Unresolved syntax remains a fact; it
is not forced into a unique edge.

### Edge

An edge is a typed directed binary relationship backed by one or more facts and
evidence records. It carries canonical relation identity, source and target
roles, origin/status, validity/freshness, and optional calibrated confidence.
Parallel edges are retained when independent observations or relation instances
carry distinct evidence. Evidence-free edges are invalid except for an
ontology-authorized deterministic synthetic projection with a named recipe.

### Hyperedge

A hyperedge records n-ary meaning using unique typed participant roles, direct
evidence, generation validity, and optional deterministic projection edges.
Initial uses include request paths, dynamic dispatch candidate sets,
requirement proofs, event flows, data queries, and state transitions.

### Claim

A claim is a derived statement over facts and evidence. It records a
deterministic recipe or model identity, inputs, alternatives, contradictions,
expiration/invalidation conditions, epistemic status, and confidence only when
calibrated. Model claims remain hypotheses and cannot overwrite facts.

### Supernode

A supernode is a typed materialized semantic aggregate with a versioned recipe,
stable identity, typed member roles, reasons, proof paths to facts, completeness,
contradictions, unresolved candidates, bounded deterministic synopsis,
generation, and invalidation dependencies. Supernode nesting is acyclic and
membership is not inferred solely from graph density or label similarity.

### Generation

A generation is an immutable candidate or published graph state. It records
parent generation, source/config/schema/ontology/provider/resolver/recipe/
embedder fingerprints, coverage and omission summaries, diagnostics, record and
index roots, creation reason, and publication state. Only one completely
validated generation becomes active atomically.

## Provenance axes

Origin answers where evidence came from:

- source syntax;
- source comment/documentation;
- repository/package manifest;
- build system/generated contract;
- version control;
- ZigEffect requirement/test metadata;
- runtime causal observation;
- deterministic resolver/semantic recipe;
- model suggestion; and
- human confirmation.

Epistemic status answers what is known:

- observed;
- resolved;
- derived;
- hypothesis;
- ambiguous;
- contradicted; and
- rejected.

These axes are independent. A deterministic resolver produces `resolver` +
`resolved`; a model produces `model_suggestion` + `hypothesis`; source syntax
with multiple viable targets remains `source_syntax` + `ambiguous`.

Graphify compatibility labels are projections only: directly observed or
resolved source records map to `EXTRACTED`; deterministic derived records map to
`INFERRED`; viable unresolved alternatives map to `AMBIGUOUS`. Native records
retain both axes and never round-trip through the lossy label internally.

## Relationship ontology

Canonical relation names live in the `zgraphy` namespace. Extensions use a
validated reverse-DNS namespace and cannot redefine a canonical name. Every
relation belongs to one immutable family policy and declares endpoint kind
classes, source/target roles, and external mappings. The resolved definition
contains:

- schema version and canonical name;
- endpoint kind classes and participant roles;
- directed semantics and reverse traversal policy;
- parallel-instance policy;
- permitted origins and epistemic statuses;
- evidence, source-span, confidence, and ambiguity policy;
- affected-query forward/reverse traversal and default cost;
- optional hyperedge projection;
- invalidation dependencies; and
- Graphify/compiler/LSP/SCIP/Proto/OpenAPI/provider mappings.

The initial families are placement/ownership, dependency/visibility,
type/composition, execution/dispatch, API/UI/contract, data/configuration,
documentation/rationale, requirement/test/causal, and graph/change lineage.
The embedded registry contains every initial relation named by the roadmap.

## Compatibility

Every current MVP relation and canonical benchmark relation has exactly one v2
mapping. A mapping records source schema, source name, target canonical name,
and whether endpoints reverse. Conversion that lacks a mapping fails with a
typed diagnostic; it never falls back to a same-spelled relation.

Notable mappings include:

- MVP `calls` to `calls_direct`;
- MVP `dispatches_to` to the evidence-preserving dispatch candidate relation;
- canonical `calls` to `calls_direct`;
- canonical `invokes_contract` to `invokes_operation`;
- canonical `implements_contract` to `handles_operation`;
- MVP component/scenario `source_root` to `source_root_of` with explicit
  compatibility orientation; and
- ambiguity candidates to a candidate-set hyperedge projection rather than a
  fabricated unique dispatch edge.

## Migration and rollback

Schema v2 is introduced through a new generation and store schema, never by
rewriting snapshot v1 in place.

1. Read and validate the complete v1 snapshot.
2. Project v1 records through checked compatibility mappings.
3. Create explicit synthetic evidence only where the ontology allows a named
   deterministic recipe.
4. Rebuild facts, indexes, vectors, hyperedges, and supernodes under their
   declared versions.
5. Validate endpoints, evidence, participants, memberships, proof paths,
   acyclicity, completeness, bounds, and redaction.
6. Atomically publish the candidate generation.
7. Retain the last compatible v1 snapshot and prior generation until rollback
   policy permits collection.

An interrupted, incompatible, incomplete, or unhealthy migration leaves the
active generation untouched. Downgrade reads the retained v1 store; no lossy
reverse projection is silently applied.

## Invalidation

A record is invalidated when any declared dependency changes: source content or
placement, manifest/build/generated contract, Git state, config/mode, schema,
ontology, identity, producer/provider, grammar/parser, resolver, semantic
recipe, evidence generation, embedder/vector, linked repository generation, or
ZigEffect receipt/causal cursor. Invalidation closes over dependent facts,
edges, hyperedges, claims, supernodes, and indexes before publication.

The old generation remains immutable. Repair creates another candidate
generation. Query-time freshness must later compare the requested dimensions
with the active generation before returning evidence.

## Security and bounds

All identifiers, names, roles, paths, mappings, evidence references, arrays,
and diagnostic details are bounded. Repository content cannot register an
extension namespace or widen process/network/model authority. Unknown schema
versions, relation families, mappings, origins, statuses, or record kinds fail
closed. Diagnostics contain normalized relative references and repair hints,
not raw source, credentials, environment values, or terminal output.

## Deferred implementation

This RFC does not claim schema-v2 persistence, incremental generation updates,
automatic freshness, provider execution, TypeScript/Zig cross-contract
resolution, hyperedge/supernode materialization, or migration qualification.
Those capabilities must implement this contract and pass their own evidence
gates.
