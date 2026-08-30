# zgraphy M4.1: Typed Semantic Recipe Registry and Materialisation Boundary

## Context

M2 established native request-path hyperedges and proof-carrying feature
supernodes. M3 made those records persistent, selectively reusable, origin
owned, transactionally prunable and clean-build equivalent. Their semantic
contract is nevertheless split across string literals and kind-specific code in
`indexer.zig`, while `model.zig` validates only the one current shape. Adding
workspace, application, package, API, test, requirement, persistence and
workflow meaning on that foundation would multiply hard-coded branches and make
recipe compatibility difficult to inspect or validate.

M4.1 introduces one typed registry and one deterministic publication boundary
for the two already-earned recipes. It deliberately preserves current graph
semantics and stable identities. New semantic kinds follow in later M4 slices
only after this boundary is proven.

## Decision

Add `src/semantic_recipes.zig` as the public authority for registered derived
meaning. A canonical, compile-time registry defines each recipe's stable name,
version, output record class, semantic kind, optional upstream recipe,
required participant/member roles, required direct-evidence roles, permitted
completeness states and proof policy.

The first registry contains exactly:

1. `rpc-request-path-v2`, producing a `request_path` hyperedge; and
2. `end-to-end-feature-v2`, producing a `feature` supernode from the registered
   request-path recipe.

Names remain byte-for-byte identical because they participate in existing
stable IDs, interaction fingerprints, persistence and delta equality.

## Alternatives considered

- Keeping literals in `indexer.zig` is the smallest immediate edit, but it does
  not provide the inspectable or extensible contract M4 needs.
- Making `model.zig` own the registry would couple generic graph storage to
  every materialisation recipe and creates an import-cycle pressure between the
  model and recipe engine.
- Replacing recipe strings with enum ordinals in persisted snapshots would make
  storage smaller, but introduces a schema migration without adding meaning and
  risks unstable IDs.

The selected boundary keeps the graph model generic, retains stable persisted
names, and lets store/candidate validation require registry conformance above
the model's structural checks.

## Registry contract

`RecipeId` is a closed typed identifier for native first-party recipes.
`Definition` contains:

- stable name and integer version;
- output class (`hyperedge` or `supernode`);
- exact model kind;
- optional upstream `RecipeId`;
- required and optional semantic roles;
- required direct-evidence roles;
- allowed completeness states for supernodes;
- proof policy (`none` or `all_steps_are_live_edges`); and
- a bounded synopsis policy for derived text.

The registry is in canonical dependency order. `validateRegistry` rejects empty
or oversized names, duplicate IDs or names, zero versions, mismatched name
suffixes, forward/missing dependencies, duplicate roles, impossible output
contracts and dependency cycles. `findById` and `findByName` fail closed rather
than treating unknown persisted recipes as native truth. A deterministic
registry fingerprint binds the full contract, not enum ordinals or memory
layout.

## Graph validation

`validateGraph` runs after generic model validation and proves:

- every native hyperedge and supernode names a registered recipe;
- record class and semantic kind match the definition;
- all required roles and direct-evidence roles are present exactly once;
- every role is permitted for the recipe;
- a supernode's input hyperedge uses its declared upstream recipe;
- completeness is permitted and completeness-specific roles are present;
- every proof step resolves to a live canonical edge when required; and
- no recipe output claims evidence or members that its definition cannot
  explain.

Unknown recipes are rejected for the native store in M4.1. Provider extension
namespaces and version negotiation remain a later operational-contract slice;
silently accepting an extension now would weaken truth.

Store save/load and generation candidate validation call this registry gate in
addition to existing model, secondary-index, origin and fingerprint checks. An
old snapshot containing the two current names remains readable with identical
IDs and bytes.

## Deterministic materialisation

The request-path assembly code continues to resolve source facts in
`indexer.zig`; that is parser/resolver work, not generic recipe work. It submits
one bounded `RequestPathInput` containing canonical identity, fingerprint,
participants, direct evidence, feature name/synopsis, members, completeness and
proof steps to the recipe engine.

`materializeRequestPath`:

1. validates the input against both registered definitions;
2. compares the predecessor record only through the registered recipe contract,
   exact canonical inputs, live nodes/edges and invalidation evidence;
3. reuses or publishes the hyperedge;
4. reuses or publishes the dependent feature supernode; and
5. returns both IDs and explicit reused/recomputed outcomes.

The operation is deterministic for canonical input. It performs no parsing,
I/O, model calls, network access or hidden graph scans beyond bounded record and
proof validation. On error, normal graph ownership and candidate publication
prevent partial active state.

## Invalidation and compatibility

The current exact reuse rules remain unchanged: canonical name, recipe,
fingerprint, participants, evidence, completeness, members and proofs must
match; evidence in the invalidation closure prevents reuse; every participant,
member, input hyperedge and proof edge must remain live. Missing or unsupported
input recomputes or omits meaning exactly as it does today.

This slice must preserve:

- existing request-path and feature stable IDs;
- graph, index, origin and clean-build fingerprints;
- snapshot-v1/v2/v3 readability and current snapshot bytes for equal input;
- M3 selective-reuse counters and behavior; and
- Graphify differential and performance evidence without broadening its claim.

## Failure and resource semantics

All registry collections are compile-time bounded. Materialisation accepts
caller-owned bounded slices already governed by graph limits and copies through
the audited model ownership boundary. Unknown recipes, class/kind mismatches,
missing roles/evidence, invalid upstreams, unsupported completeness, dead proof
steps and invalid registry definitions return typed errors. Source text,
absolute paths and secrets never enter registry diagnostics.

## Acceptance evidence

The required `m4-semantic-recipe-registry` Testing v2 scenario proves:

1. the canonical registry is unique, dependency ordered and has a stable
   fingerprint;
2. unknown or class/kind/upstream/role/evidence-invalid records fail closed;
3. the fullstack request path and feature validate through the registry;
4. moving publication from `indexer.zig` preserves exact IDs, graph/index
   fingerprints, evidence, proof steps, completeness and synopsis;
5. a no-change predecessor reuses both records, a proof-source change
   recomputes them, and deletion prunes them;
6. save/load and generation-candidate validation reject unregistered meaning;
7. Debug and ReleaseSafe Testing v2 receipts have zero pending tests, leaks or
   logged errors; and
8. the project agent check remains clean.

## Nonclaims

M4.1 does not yet add new supernode kinds, generic provider recipes, first-class
contradiction records, community detection, synopsis generation, recipe CLI
inspection, held-out precision measurement or an agent-task improvement claim.
It creates the trusted boundary those later M4 slices require.
