# zigeffect Causal Deep Runtime Internals Implementation Plan

Date: 2026-06-09
Branch: `codex/zigeffect-causal-deep-runtime-internals`
Design: `docs/superpowers/specs/2026-06-09-zigeffect-causal-deep-runtime-internals-design.md`

## Scope

Implement additive deep runtime causal facts without changing the public v1
artifact schema name or taxonomy version. The branch enriches current
`CausalEvent` records and makes every existing projection preserve the new
fields.

## Files

- Update `packages/zigeffect/src/services/causal.zig`
- Update `packages/zigeffect/src/services/causal_jsonl_backend.zig`
- Update `packages/zigeffect/src/services/causal_otel_backend.zig`
- Update `packages/zigeffect/src/services/causal_graph_history_backend.zig`
- Update `packages/zigeffect/src/services/causal_async_stream_backend.zig`
- Update `packages/zigeffect/src/services/causal_nendb_storage_backend.zig`
- Update `packages/zigeffect/src/core/scope.zig`
- Update `packages/zigeffect/src/runtime/fiber.zig`
- Update `packages/zigeffect/src/layer/graph.zig`
- Update focused causal tests under `packages/zigeffect/test/`
- Add docs under `docs/superpowers/`

## TDD Plan

1. Add failing tests for the additive `CausalEvent` fields:
   - store snapshots preserve all optional ids and `service_key`;
   - JSON export contains the fields while schema stays `zigeffect.causal.v1`;
   - redaction/truncation applies to `service_key`.
2. Add failing backend projection tests:
   - JSONL includes the fields;
   - OTEL attributes include them;
   - NenDB node properties include them;
   - graph-history/async-stream clone paths preserve `service_key`.
3. Add failing runtime tests:
   - layer graph events carry `layer_id`;
   - service events carry `service_key`;
   - acquired/finalized resources share `resource_id`;
   - failed finalizers retain resource id and acquisition linkage;
   - repeated joins emit one `fiber_joined`.
4. Implement only enough runtime and projection code to satisfy those tests.

## Implementation Steps

1. Extend `CausalEvent`.
   - Add optional ids and `service_key`.
   - Update store clone/redaction/deinit helpers.
   - Update snapshot/lineage/cause behavior naturally through cloning.

2. Preserve fields in exports.
   - Add JSON fields in deterministic order after current scope/fiber/trace
     identifiers.
   - Add JSONL fields with the same names.
   - Add DOT tooltip values and an optional `cause` edge.

3. Preserve fields in backends.
   - Add clone/deinit support for `service_key` in graph-history,
     async-stream, NenDB, and test conformance helpers.
   - Add OTEL attributes:
     `zigeffect.causal.layer_id`,
     `zigeffect.causal.service_key`,
     `zigeffect.causal.resource_id`,
     `zigeffect.causal.cause_event_id`,
     `zigeffect.causal.schedule_id`.
   - Add NenDB node JSON properties for the same fields.

4. Add runtime identity generators.
   - Add `nextLayerId`, `nextResourceId`, and `nextScheduleId` to
     `CausalStore`.
   - Use layer ids in layer graph startup/validation.
   - Use resource ids at finalizer registration time.
   - Leave schedule ids nullable until a schedule lifecycle branch can assign
     stable identities.

5. Enrich scope/resource emission.
   - Store resource id and acquisition event id on finalizer metadata.
   - Emit acquisition with `resource_id`.
   - Emit finalization with the same `resource_id` and acquisition parent.
   - Prefer resource id in leak detection.

6. Enrich fiber emission.
   - Add a joined-recorded guard to fiber state.
   - Record `fiber_joined` exactly once per fiber.
   - Preserve existing fork/start/interrupt event order.

7. Enrich layer/service emission.
   - Allocate deterministic layer ids before validation/build emission.
   - Attach `layer_id` to layer events and service events.
   - Attach `service_key` to service requirement/provider/replacement events.

8. Verify.
   - `cd packages/zigeffect`
   - `zig build test`
   - `zig build examples`
   - `zig build causal-unified-spine-contract`
   - `zig build causal-production-hardening-backlog`
   - `zig build causal-schema-governance`
   - `cd ../..`
   - `bun run zig:test`
   - `bun run check`
   - `git diff --check`
   - `git diff --cached --check`

## Commit Plan

1. Commit design and implementation plan.
2. Commit tests and implementation.

## Follow-On Branch

After this branch, the next best branch is the relationship index and bounded
agent query boundary. It should consume the new ids and produce typed
relationship slices without changing source-event authority.
