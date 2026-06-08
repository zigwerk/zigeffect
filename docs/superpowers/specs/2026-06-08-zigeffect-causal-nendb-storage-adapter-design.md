# zigeffect Causal NenDB Storage Adapter Design

Date: 2026-06-08
Branch: codex/zigeffect-causal-nendb-storage-adapter
Milestone: M4 Causal Backend Adapters

## Purpose

Add the first NenDB-specific causal storage adapter contract behind the existing
`CausalBackendKind.nendb_graph` boundary.

The previous branch added `CausalGraphHistoryBackendState`: a dependency-free,
scan-based graph-history backend that proves the agent-facing query vocabulary.
This branch should make that lane more concrete by translating causal events
into NenDB-shaped graph writes without making `zigeffect` depend directly on an
unstable upstream package shape.

The adapter should let local agents and future dev harnesses prove:

- every stored causal event becomes a graph node write;
- parent relationships become graph edge writes;
- event metadata is encoded deterministically and redaction-safe;
- graph writes fail closed before the backend records partial local history;
- query behavior remains available through adapter-owned history even if the
  storage writer is only a sink.

## Upstream Context

Current upstream observations on 2026-06-08:

- NenDB latest npm package is `@nenco/nendb@0.2.1-beta`.
- The upstream repository is `https://github.com/Nen-Co/nen-db`.
- The upstream README presents NenDB as an embedded-first AI-native graph
  database and lists server/client distribution paths.
- The Zig repository exposes a `nendb` module and APIs such as
  `Database.insert_node`, `Database.insert_edge`, `EmbeddedDB.addNode`,
  `EmbeddedDB.addEdge`, and graph lookup/filter helpers.
- The upstream README targets Zig `0.15.1`, while this repo currently verifies
  with Zig `0.16.0`.
- The upstream repo does not currently provide a `build.zig.zon` package
  manifest in the cloned main branch.
- The upstream build file opportunistically imports sibling `nen-core`,
  `nen-io`, `nen-json`, and `nen-net` repositories when present.

Those facts make a direct package dependency risky for this branch. A stable
adapter contract is more useful now than pinning `zigeffect` to a dependency
shape that may not be fetchable or compatible in the current build.

## Goals

- Add `CausalNendbStorageBackendState` behind `CausalBackendKind.nendb_graph`.
- Add a small `CausalNendbGraphWriter` sink interface that models the NenDB
  writes zigeffect needs:
  - insert or upsert a causal event node;
  - insert or upsert a causal parent edge when `parent_id` exists;
  - optional flush hook for future WAL-backed adapters.
- Add deterministic event-to-node and event-to-edge mapping helpers.
- Preserve a queryable local history with the same methods as
  `CausalGraphHistoryBackendState`.
- Fail closed:
  - no local history append if the writer rejects the write;
  - no local history append if the local max-event ceiling is already full;
  - backend failure counters and `CausalStore.backendFailureCount()` remain
    observable.
- Keep the branch dependency-free and tests fake the writer.
- Add a focused build gate:
  `zig build causal-nendb-storage-backend`.
- Update docs so agents understand the difference between:
  - scan-only graph history;
  - NenDB storage adapter contract;
  - a future direct upstream `nendb.EmbeddedDB` wrapper.

## Non-Goals

- No CockroachDB, RoachGraph, D1, R2, or SQL history adapter.
- No direct upstream `nen-db` package dependency in this branch.
- No vendored copy of NenDB source.
- No HTTP client, Docker-managed server, or external process lifecycle.
- No schema migration framework.
- No cross-process locking, WAL tuning, or performance benchmarking.
- No agent workbench UI.
- No replay or snapshot forking.

## Considered Approaches

### Option A: Directly Add Upstream NenDB As A Zig Dependency

This is attractive because the adapter would be literal immediately. It is not
the right first integration because upstream currently lacks a package manifest
and references Zig `0.15.1` while the local package runs on Zig `0.16.0`.
The upstream build also expects optional sibling repositories. Pulling that into
the core package now would make zigeffect's verification hostage to external
layout churn.

### Option B: Shell Out To NenDB Server Or Use The npm/Python Client

This could exercise a real NenDB distribution, but it would add external
process lifecycle, network/HTTP behavior, and non-Zig runtime dependencies to a
package that currently verifies as a deterministic Zig library. It would also
be wrong for Cloudflare Worker request-path code and awkward for local package
tests.

### Option C: Add A NenDB-Shaped Writer Interface

Define a small writer contract that receives a deterministic node write plus an
optional parent-edge write. The writer can be backed by a fake in tests, a real
`nendb.EmbeddedDB` wrapper later, or another local graph storage engine if the
upstream package shape changes.

This is the recommended slice. It gives agents a real adapter boundary and
proves event mapping/failure semantics now, while preserving a clean place for
direct NenDB integration once package compatibility is stable.

## Public API

Create:

```text
packages/zigeffect/src/services/causal_nendb_storage_backend.zig
```

Expose through `packages/zigeffect/src/zigeffect.zig`:

```zig
pub const CausalNendbGraphWriter = causal_nendb_storage_backend.CausalNendbGraphWriter;
pub const CausalNendbNode = causal_nendb_storage_backend.CausalNendbNode;
pub const CausalNendbEdge = causal_nendb_storage_backend.CausalNendbEdge;
pub const CausalNendbWrite = causal_nendb_storage_backend.CausalNendbWrite;
pub const CausalNendbStorageBackendOptions = causal_nendb_storage_backend.CausalNendbStorageBackendOptions;
pub const CausalNendbStorageBackendError = causal_nendb_storage_backend.CausalNendbStorageBackendError;
pub const CausalNendbStorageBackendState = causal_nendb_storage_backend.CausalNendbStorageBackendState;
```

Core structs:

```zig
pub const CausalNendbNode = struct {
    id: u64,
    label: []const u8,
    kind: u8,
    properties: []const u8,
};

pub const CausalNendbEdge = struct {
    from: u64,
    to: u64,
    label: []const u8,
    label_id: u16,
    properties: []const u8,
};

pub const CausalNendbWrite = struct {
    node: CausalNendbNode,
    parent_edge: ?CausalNendbEdge = null,
};

pub const CausalNendbGraphWriter = struct {
    state: ?*anyopaque = null,
    write: *const fn (?*anyopaque, CausalNendbWrite) anyerror!void,
    flush: ?*const fn (?*anyopaque) anyerror!void = null,
};
```

Backend state:

```zig
pub const CausalNendbStorageBackendState = struct {
    allocator: std.mem.Allocator,
    writer: CausalNendbGraphWriter,
    events: std.ArrayList(causal.CausalEvent) = .empty,
    max_events: ?usize = null,
    written_event_count: u64 = 0,
    failed_event_count: u64 = 0,
    flushed_count: u64 = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        writer: CausalNendbGraphWriter,
        options: CausalNendbStorageBackendOptions,
    ) CausalNendbStorageBackendState;

    pub fn deinit(self: *CausalNendbStorageBackendState) void;
    pub fn backend(self: *CausalNendbStorageBackendState) causal_backend.CausalBackend;
    pub fn eventCount(self: *const CausalNendbStorageBackendState) usize;
    pub fn writtenEventCount(self: *const CausalNendbStorageBackendState) u64;
    pub fn failedEventCount(self: *const CausalNendbStorageBackendState) u64;
    pub fn flushedCount(self: *const CausalNendbStorageBackendState) u64;
    pub fn flush(self: *CausalNendbStorageBackendState) anyerror!void;
    pub fn snapshot(self: *const CausalNendbStorageBackendState, allocator: std.mem.Allocator) std.mem.Allocator.Error!causal.CausalSnapshot;
    pub fn cause(self: *const CausalNendbStorageBackendState, allocator: std.mem.Allocator, event_id: u64) std.mem.Allocator.Error!causal.CausalLineage;
    pub fn lineage(self: *const CausalNendbStorageBackendState, allocator: std.mem.Allocator, event_id: u64) std.mem.Allocator.Error!causal.CausalLineage;
    pub fn eventsByKind(self: *const CausalNendbStorageBackendState, allocator: std.mem.Allocator, kind: causal.CausalEventKind) std.mem.Allocator.Error!causal.CausalSnapshot;
    pub fn eventsByRun(self: *const CausalNendbStorageBackendState, allocator: std.mem.Allocator, run_id: u64) std.mem.Allocator.Error!causal.CausalSnapshot;
    pub fn eventsByScope(self: *const CausalNendbStorageBackendState, allocator: std.mem.Allocator, scope_id: u64) std.mem.Allocator.Error!causal.CausalSnapshot;
    pub fn eventsByFiber(self: *const CausalNendbStorageBackendState, allocator: std.mem.Allocator, fiber_id: u64) std.mem.Allocator.Error!causal.CausalSnapshot;
};
```

Errors:

```zig
pub const CausalNendbStorageBackendError = error{
    CausalNendbStorageBackendFull,
    CausalNendbWriterRejected,
};
```

## Event Mapping

Node mapping:

- `node.id`: causal event id.
- `node.label`: `causal_event`.
- `node.kind`: stable compact hash of `@tagName(event.kind)`.
- `node.properties`: deterministic JSON object containing:
  - `schema`
  - `schema_version`
  - `event_taxonomy_version`
  - `event_id`
  - `kind`
  - `run_id`
  - `parent_id`
  - `fiber_id`
  - `scope_id`
  - `trace_id`
  - `span_id`
  - `label`
  - `type_name`
  - `status`
  - `redacted_detail`

Parent-edge mapping:

- No edge when `event.parent_id == null`.
- `edge.from`: `event.parent_id.?`.
- `edge.to`: `event.id`.
- `edge.label`: `causal_parent`.
- `edge.label_id`: stable compact hash of `causal_parent`.
- `edge.properties`: deterministic JSON object containing:
  - `schema`
  - `schema_version`
  - `from_event_id`
  - `to_event_id`
  - `kind`
  - `run_id`

The mapping intentionally keeps strings sanitized by `CausalStore`. The adapter
must not re-read raw caller payloads or bypass store redaction/truncation.

## Write Semantics

The backend callback receives an already assigned, sanitized event from
`CausalStore`.

Per event:

1. Check `max_events` before allocating or calling the writer.
2. Ensure local history has append capacity.
3. Clone the event strings for local history.
4. Format the NenDB node/edge write.
5. Call `writer.write`.
6. If the writer fails, free the cloned event and return an error.
7. If the writer succeeds, append the cloned event with no further allocation.
8. Increment `written_event_count`.

This ordering preserves fail-closed local history: a failed writer cannot leave
the zigeffect adapter claiming it has a queryable event that the NenDB writer
rejected.

The writer contract itself must be documented as fail-closed. Test fakes will
prove no partial writes on failure. A future real `nendb.EmbeddedDB` wrapper may
need to batch node and edge writes or preflight edge dependencies to preserve
the same semantics.

## Query Semantics

`CausalNendbStorageBackendState` keeps the same local query vocabulary as
`CausalGraphHistoryBackendState`:

- `snapshot`
- `cause`
- `lineage`
- `eventsByKind`
- `eventsByRun`
- `eventsByScope`
- `eventsByFiber`

The writer is storage output. These query helpers read adapter-owned local
history so agents can query immediately without depending on a specific NenDB
query API shape. Future direct NenDB-backed query acceleration can replace the
local scan path after the storage dependency is stable.

## Test Strategy

Add `packages/zigeffect/test/causal_nendb_storage_backend_test.zig`.

Use a fake writer with:

- owned `writes: std.ArrayList(CausalNendbWriteRecord)`;
- configurable `fail_after` or `fail_next`;
- no partial append on configured failure;
- optional flush counter.

Tests:

1. Standard conformance trace writes three NenDB nodes and two parent edges,
   with backend kind `.nendb_graph`.
2. Node properties preserve redaction and truncation markers and omit the raw
   secret from the standard fixture.
3. Event kind and edge label ids are stable across repeated mapping calls.
4. Cause and lineage queries still work after the core store has dropped
   ancestors through retention.
5. Filter queries by run, scope, and fiber match the graph-history backend
   behavior.
6. Writer failure is fail-closed:
   - fake writer records no partial write;
   - backend local `eventCount()` does not advance;
   - `failedEventCount()` increments;
   - `CausalStore.backendFailureCount()` increments;
   - the core store still retains its event.
7. `max_events = 0` fails before the writer is called.
8. `flush()` invokes the optional writer flush hook and increments
   `flushedCount()`.

Add direct build step:

```text
zig build causal-nendb-storage-backend
```

The package `test` step should depend on it.

## Documentation Updates

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Docs should say:

- `CausalNendbStorageBackendState` is the concrete NenDB storage adapter
  contract for causal events.
- It is dependency-free in this branch because upstream NenDB's Zig package
  shape is not yet stable enough for a direct package dependency.
- It maps causal events into NenDB-shaped node and parent-edge writes.
- Its local query methods are scan-based and immediate.
- A future direct upstream wrapper should target `nendb.EmbeddedDB.addNode`,
  `addEdge`, `flush`, and graph query helpers once the package can be pinned
  cleanly.

## Acceptance Criteria

- The branch adds design, plan, tests, implementation, docs, and roadmap
  updates.
- The adapter returns `CausalBackendKind.nendb_graph`.
- NenDB write mapping is deterministic, redaction-safe, and covered by tests.
- Writer failures fail closed before local history advances.
- Max-event ceilings fail before writer calls.
- Query helpers remain available over adapter-owned history.
- `zig build causal-nendb-storage-backend` passes.
- Full zigeffect and repo verification passes before merge.
