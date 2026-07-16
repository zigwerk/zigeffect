# RFC: zgraphy operational contracts v1

Status: M0 contract candidate; no external provider authority granted

Version: `zgraphy.operational-contracts.v1`, schema version 1

## Purpose

This RFC defines the operational rules that must exist before zgraphy runs
parsers, compiler indexes, converters, databases, runtime feeds, or semantic
models. The embedded machine contract is normative for provider envelopes,
extractor conformance, config-v2, graph health, diagnostics, and
migration receipts.

The current runtime uses the M1 identity-and-bounds subset of
`zgraphy.config.v2`; the broader mode, provider, freshness, retention and
linked-repository contract remains inactive until its runtime fields and
effective-config evidence are implemented. Persistence remains
`zgraphy.nendb.snapshot.v1`, alongside the M0 freshness receipt. This RFC does
not activate schema-v2 persistence, external processes, network access,
database access, models, or automatic refresh.

## Provider contract

Each provider run carries stable provider kind and implementation identity,
version, authority, declared capabilities, source generation, observation and
expiration times, content/config fingerprints, scope, redaction, bounds, and
requested-versus-terminal unit accounting.

Provider kinds distinguish source syntax, manifests, generated contracts,
compiler indexes, live databases, runtime causal evidence, document
converters, local models, and remote models. These are separate evidence tiers.
A conflicting observation becomes an explicit contradiction; it cannot
silently replace a canonical source fact.

The lifecycle is `disabled|available|checking|running|partial|complete|stale|failed|expired`.
Every requested unit terminates as `returned`, `omitted`, `zero_node`,
`hyperedge_only`, `failed`, or `content_filtered`. A complete run must
reconcile every requested unit exactly, including zero-node and hyperedge-only
successes which Graphify correctly showed can otherwise disappear from
coverage accounting.

## Authority

Repository config is capped at repository-local read authority. It cannot
grant process execution, external filesystem access, network egress, database
access, or local/remote model access. Those capabilities require an explicit
decision outside repository-controlled content.

Live database access is read-only. Remote providers additionally require
explicit egress scope, redaction, timeout, token, concurrency, retry, and spend
bounds. Ambient credentials never select a provider.

Provider envelopes, graph records, receipts, and diagnostics prohibit
credentials, tokens, secrets, connection strings, authorization headers, raw
environment values, absolute user paths, unbounded source bodies, and raw
stdout/stderr. Normalized relative references, bounded redacted details, and
content digests are the evidence boundary.

## Extractor conformance

All first-party extractors and providers emit the schema-v2 semantic fact
model. They qualify over shared dimensions:

- identity and exact source spans;
- containment and relationship direction;
- ambiguity/candidate preservation;
- mutation and clean/incremental equivalence;
- deterministic resource bounds;
- redaction and authority;
- requested-unit reconciliation; and
- interruption safety.

The cumulative profiles are discovery, structural, resolved, external, and
semantic-model. External and model providers must exercise every dimension.
Model output remains hypothesis evidence and cannot mutate canonical facts.
Partial results and unknown support are never reported as conformance passes.

## Configuration

The future `zgraphy.config.v2` contract covers repository and path policy,
providers, bounds, freshness, retention, analysis, retrieval, models, storage,
diagnostics, maturity acknowledgements, linked repositories, and output.
Precedence is compiled defaults, user, repository, environment, then CLI.

Later layers may tighten authority or resource limits. Widening authority
requires a capability decision. The six reproducible modes are structural,
semantic-local, semantic-remote, CI, agent, and benchmark. Every setting that
can change graph meaning participates in configuration fingerprints.

Config-v1 migration expands safe defaults into a separately validated v2
candidate and retains v1 for rollback. No in-place migration is permitted.

## Health and diagnostics

Health states are healthy, degraded, stale, partial, incompatible, and corrupt.
They are evaluated independently across generation, freshness, discovery,
semantics, providers, storage, indexes, self-manager, and resources. A query
must eventually declare its required dimensions, allowing a deterministic
placement lookup to remain complete while optional semantic evidence is stale.

The health schema accounts for discovered/included/omitted units, unresolved or
contradictory semantics, provider expiry, integrity, invalidation, pruning,
orphan sweep, repair, rebuild, compaction, garbage collection, and exhausted
resource bounds.

Diagnostics use stable code, severity, stage, typed status, bounded redacted
detail, relative source/provider references, generation, repair guidance, and a
safe replay command. JSON stdout is reserved for requested results; warnings
and progress use stderr.

## Migration and fallback

Migration builds a new candidate generation from snapshot-v1. Receipts bind
source/target schemas and fingerprints, strategy, state, candidate and
previous-good generations, record accounting, invariants, diagnostics,
publication, and rollback retention.

Publication is atomic and requires validated endpoints, evidence, hyperedge
participants, supernode memberships and proof paths, indexes, vectors, and
health. Failed or interrupted candidates never replace the active complete
generation. Cleanup is restricted to zgraphy-owned data, and the last verified
compatible generation remains available for rollback.

## Graphify leverage and zgraphy improvements

The contract preserves Graphify's provider registry, bounded LLM backend
configuration, per-unit semantic reconciliation, extractor fallbacks, and
read-only diagnostics. zgraphy strengthens these with capability-separated
authority, provenance tiers, hypothesis-only model output, typed independent
health dimensions, secret-free receipts, immutable generation fallback, and
one cross-provider conformance suite.

## Deferred implementation

Provider processes, parser plugins, live database qualification, semantic
models, config-v2 loading, health command execution, diagnostic emission,
snapshot-v2 migration, and automatic self-management each require separate
failing-first scenarios and evidence receipts. A contract entry alone does not
promote any of those capabilities.
