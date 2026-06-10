# zigeffect Public API Stabilization Design

Date: 2026-06-10

Milestone: 45 - Public API Review And Stabilization

## Goal

Turn the durable workflow and local cluster runtime into a coherent public
package surface with explicit contracts for names, ownership, errors, schema
versions, diagnostics, and backend adapter compatibility.

The milestone should leave a written review artifact and a compile-time API
stability test. The review artifact is the human contract. The test is the
machine guard that keeps the most important facade names and schema constants
from moving accidentally.

## Current Context

The root facade lives in `packages/zigeffect/src/zigeffect.zig`. It exposes
namespace-first access through `fx.workflow`, `fx.cluster`, `fx.storage`,
`fx.performance`, and the earlier core namespaces. It also exposes curated
top-level aliases for compatibility and direct-style examples.

The workflow facade exports durable journals, definitions, activities, engine
state, workflow contexts, durable timers, deferreds, signals, queues,
scheduling, lifecycle controls, inspection, storage compaction, and workflow
causal mapping.

The cluster facade exports actor identity, local mailbox storage, local entity
runtime, durable message storage, runner registration and health, shard routing,
runner storage, shard leases, fencing, supervision policy, observability,
runtime routing, transports, cluster workflow commands, distributed timer
wakeups, durable queue indexes, and multi-runner local cluster helpers.

Existing `architecture_test.zig` already checks the root namespace shape and
some compatibility aliases. Milestone 45 should add a narrower public API test
that focuses on the durable workflow and cluster additions, schema version
constants, public clone/deinit ownership helpers, and error-set membership.

## Selected Architecture

Add a public API review document:

- `packages/zigeffect/docs/public-api-review.md`

The document is the canonical M45 review artifact. It should include:

- a namespace and naming contract;
- stable public names for durable workflows and clustering;
- ownership and allocator rules;
- error-set and diagnostic policy;
- schema versioning rules;
- direct-style Zig guidance;
- compatibility notes for real async IO, real clustering, shard leasing,
  multi-runner transports, and full supervision trees;
- an explicit review closeout table with no unresolved naming or ownership
  issues.

Add a compile-time public API lock:

- `packages/zigeffect/test/public_api_stability_test.zig`

The test should avoid runtime setup. It should assert:

- required root namespaces exist;
- durable workflow types and functions remain available through
  `fx.workflow`;
- cluster types and functions remain available through `fx.cluster`;
- selected top-level compatibility aliases remain tied to namespace exports;
- workflow, cluster, storage, and performance schemas stay at version `1`;
- concrete domain error sets include the documented public members;
- public clone/deinit helpers remain exported for owned message and journal
  values.

Wire the focused test into:

- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/build.zig` as `zig build public-api-review`

Update docs navigation:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/architecture.md`

Update roadmap status after the full verification gate passes:

- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Naming Contract

The stable shape is namespace-first:

- `fx.workflow` for durable workflow APIs;
- `fx.cluster` for actor, runner, shard, transport, and cluster workflow APIs;
- `fx.storage` for schema catalog and SQL migration plan APIs;
- `fx.performance` for bounded resource and benchmark report APIs.

Top-level aliases remain curated compatibility conveniences for highly used
runtime, storage, workflow, and cluster symbols. New code should prefer the
namespace form when it improves readability.

## Ownership Contract

Allocator arguments are borrowed from the caller. APIs that return allocated
bytes, batches, envelopes, events, reports, or owned records must either return
a type with `deinit` or document the caller-owned slice convention next to the
function.

Durable stores own cloned records after submit/append. Read and claim methods
that return messages or workflow events return caller-owned values, and the
caller releases nested strings with the matching `deinit*` helper or batch
`deinit`.

Public ownership helpers remain part of the contract:

- `fx.workflow.cloneWorkflowEvent`
- `fx.workflow.deinitWorkflowEventStrings`
- `fx.cluster.cloneEntityAddress`
- `fx.cluster.deinitEntityAddress`
- `fx.cluster.cloneEntityEnvelope`
- `fx.cluster.deinitEntityEnvelope`
- `fx.cluster.cloneMessageEnvelope`
- `fx.cluster.deinitMessageEnvelope`

## Error And Diagnostic Contract

Domain modules expose concrete error sets for user-actionable cases. Type-erased
storage and transport vtables may return `anyerror` at the adapter boundary so
file-backed, in-memory, and future external backends can compose without losing
backend-specific failures. Concrete implementation methods should continue to
use narrower error unions where the implementation can name the failure set.

Diagnostic functions produce stable human-readable text. JSON outputs already
exist for schema catalogs, SQL plans, workflow reports, cluster command payloads,
transport messages, causal records, and performance reports. Future structured
diagnostics should add new functions instead of changing existing text
functions.

## Schema Versioning Contract

Schema names are immutable identifiers. Version constants describe the schema
format currently emitted by the package. A breaking format change requires a new
version and migration or compatibility handling for persisted records.

Milestone 45 locks the current public durable schemas at version `1`, including:

- workflow journal events, checkpoints, snapshot commits, inspect reports,
  replay reports, and list reports;
- cluster message records, replies, runner leases, transport requests,
  transport responses, workflow commands, and workflow command results;
- storage catalog and SQL migration plans;
- performance benchmark reports.

## Backend Compatibility Contract

Direct-style Zig remains the source-level API. Real async IO, real clustering,
shard leasing, multi-runner transport, and full supervision trees can add
backend implementations and capability checks, but they should not require users
to rewrite plain workflow or actor handlers into a different programming model.

Backend capability expansion should preserve these invariants:

- deterministic tests remain deterministic;
- durable records keep schema names and version constants;
- adapters expose clear ownership for returned records;
- unsupported capabilities report through typed errors and diagnostics;
- clustered backends preserve shard lease fencing and runner identity semantics.

## Verification

The milestone gate is:

```bash
(cd packages/zigeffect && zig build public-api-review)
bun run zigeffect:test
bun run zig:test
(cd packages/zigeffect && zig build examples)
zig fmt --check \
  packages/zigeffect/test/public_api_stability_test.zig \
  packages/zigeffect/test/all_test.zig \
  packages/zigeffect/build.zig
git diff --check
```

## Acceptance

The milestone is accepted when the public API review document records no
unresolved naming or ownership issues, the focused API stability test passes,
the full zigeffect suite passes, examples still build, formatting is clean, and
the roadmap marks Milestone 45 complete.
