# zigeffect Local Supervision Trees Design

Date: 2026-06-09

## Context

Milestone 24 introduces Erlang-style local supervision before actor entities,
distributed runners, shard leases, and full cluster supervision exist. The
current runtime already has deterministic fibers, scoped fiber leases, reverse
order finalizers, `Exit` and `Cause` failure values, backend supervision
capability flags, and causal fiber/scope events. There is no supervisor module
or restart policy engine yet.

This milestone adds the local supervision policy layer. It does not create
green threads, restart operating-system processes, or supervise distributed
shards. Instead, it defines typed child specs and deterministic restart
decisions that later fiber, workflow worker, queue worker, entity, shard, and
runner supervisors can execute.

## Design Choice

Three approaches were considered:

1. Add `runtime/supervisor.zig` as a deterministic supervision policy engine.
2. Extend `FiberRuntime` directly with supervisor child registries.
3. Wait until the entity actor model exists and put supervision in `cluster/`.

The selected approach is option 1. `runtime/supervisor.zig` can model local
supervision without forcing current fibers or workflow scheduler workers into a
larger runtime contract too early. `FiberRuntime` and the workflow scheduler can
adopt the supervisor module in later milestones, while Milestone 24 still gives
users real child specs, strategies, restart intensity limits, shutdown ordering,
Cause evidence, and causal reporting.

## Goals

- Add local supervisor definitions under `src/runtime/supervisor.zig`.
- Support child kinds for fibers, workflow workers, queue workers, and entities.
- Support restart modes: permanent, transient, and temporary.
- Support strategies: one-for-one, one-for-all, and rest-for-one.
- Track restart counts and restart intensity windows.
- Escalate when a child exceeds the configured restart intensity.
- Provide deterministic shutdown ordering from child specs.
- Preserve child failures through `Cause(SupervisorError)` helpers.
- Add causal supervisor events for child start, restart decisions, escalation,
  and shutdown ordering.
- Export supervisor APIs through `fx.runtime` and top-level facade aliases.

## Milestone Boundary

Milestone 24 is local and deterministic. It produces restart decisions and
updates local child state, but it does not spawn background scheduler loops,
manage real async fiber execution, supervise cluster runners, or implement
dynamic distributed supervision. Milestone 51 will expand this foundation into
complete supervision trees across fibers, workflow workers, queue workers,
entities, shard workers, transport servers, and runner services.

## Public API

Create `packages/zigeffect/src/runtime/supervisor.zig`.

Core types:

```zig
pub const SupervisorId = u64;
pub const SupervisorChildId = u64;

pub const SupervisorStrategy = enum {
    one_for_one,
    one_for_all,
    rest_for_one,
};

pub const SupervisorRestartMode = enum {
    permanent,
    transient,
    temporary,
};

pub const SupervisorChildKind = enum {
    fiber,
    workflow_worker,
    queue_worker,
    entity,
};

pub const SupervisorChildStatus = enum {
    idle,
    running,
    restarting,
    stopped,
    failed,
    escalated,
};

pub const SupervisorError = error{
    ChildNotFound,
    DuplicateChild,
    ChildFailed,
    RestartIntensityExceeded,
};

pub const SupervisorCause = Cause(SupervisorError);
```

Child specs and state:

```zig
pub const SupervisorChildSpec = struct {
    id: SupervisorChildId,
    name: []const u8,
    kind: SupervisorChildKind,
    restart_mode: SupervisorRestartMode = .permanent,
    shutdown_order: u32 = 0,
};

pub const SupervisorChildExit = union(enum) {
    success,
    failure: []const u8,
    defect: []const u8,
    interrupted: u64,
};

pub const RestartIntensity = struct {
    max_restarts: usize = 3,
    within_ms: u64 = 60_000,
};

pub const SupervisorOptions = struct {
    id: SupervisorId,
    name: []const u8,
    strategy: SupervisorStrategy = .one_for_one,
    intensity: RestartIntensity = .{},
};

pub const SupervisorChildSnapshot = struct {
    spec: SupervisorChildSpec,
    status: SupervisorChildStatus,
    restart_count: usize = 0,
};
```

Decisions and plans:

```zig
pub const SupervisorDecision = struct {
    supervisor_id: SupervisorId,
    child_id: SupervisorChildId,
    strategy: SupervisorStrategy,
    exit: SupervisorChildExit,
    restarted_children: usize = 0,
    stopped_children: usize = 0,
    escalated: bool = false,

    pub fn cause(self: SupervisorDecision) ?SupervisorCause;
};

pub const SupervisorShutdownPlan = struct {
    allocator: Allocator,
    children: []SupervisorChildSnapshot,

    pub fn deinit(self: *SupervisorShutdownPlan) void;
};
```

Supervisor:

```zig
pub const Supervisor = struct {
    pub fn init(allocator: Allocator, options: SupervisorOptions) Supervisor;
    pub fn deinit(self: *Supervisor) void;

    pub fn attachCausalStore(self: *Supervisor, store: *CausalStore, run_id: u64) void;
    pub fn addChild(self: *Supervisor, spec: SupervisorChildSpec) Allocator.Error!void;
    pub fn startAll(self: *Supervisor, now_ms: u64) Allocator.Error!void;
    pub fn reportChildExit(
        self: *Supervisor,
        child_id: SupervisorChildId,
        exit: SupervisorChildExit,
        now_ms: u64,
    ) (Allocator.Error || SupervisorError)!SupervisorDecision;
    pub fn childStatus(self: *const Supervisor, child_id: SupervisorChildId) SupervisorError!SupervisorChildStatus;
    pub fn childRestartCount(self: *const Supervisor, child_id: SupervisorChildId) SupervisorError!usize;
    pub fn shutdownPlan(self: *Supervisor, allocator: Allocator) Allocator.Error!SupervisorShutdownPlan;
};
```

## Runtime Behavior

`addChild` rejects duplicate child ids and stores specs in registration order.
`startAll` marks all children running and records `supervisor_child_started`
events when a causal store is attached.

`reportChildExit` applies restart mode first:

- `permanent` restarts after success, failure, defect, or interruption.
- `transient` restarts after failure, defect, or interruption, but stops after
  success.
- `temporary` never restarts.

If the restart mode allows restart, the supervisor applies the configured
strategy:

- `one_for_one`: restart only the exited child.
- `one_for_all`: restart every restartable child.
- `rest_for_one`: restart the exited child and restartable children registered
  after it.

Restart intensity is checked before any restart. The supervisor keeps restart
timestamps inside the configured window. If the current restart would exceed
`max_restarts`, the affected children become `escalated`, the decision has
`escalated = true`, and the decision cause is
`error.RestartIntensityExceeded`.

If a child is not restarted, it becomes `stopped` on success or `failed` on
failure, defect, or interruption. A non-escalated failed/stopped decision has
`error.ChildFailed` as its cause when the exit is failure-like.

`shutdownPlan` returns children sorted by descending `shutdown_order`; children
with the same order are returned in reverse registration order. This mirrors the
existing scope finalizer shape and gives later runtime code a deterministic
shutdown sequence.

## Causal Reporting

Add these causal event kinds in `services/causal.zig`:

- `supervisor_child_started`
- `supervisor_restart_decided`
- `supervisor_escalated`
- `supervisor_shutdown_ordered`

They are structural finding-evidence events and not sampleable. The supervisor
records:

- child start: `label = child.name`, `type_name = child kind`,
  `status = "running"`.
- restart decision: `label = child.name`, `status = "restart"` or `"stop"`,
  detail with `strategy`, `restart_mode`, and affected counts.
- escalation: `label = child.name`, `status = "escalated"`,
  detail with restart intensity values.
- shutdown order: one event per ordered child with `status = "ordered"` and
  detail containing the order index.

## Testing Strategy

Add `packages/zigeffect/test/supervisor_test.zig` and import it from
`packages/zigeffect/test/all_test.zig`.

Tests cover:

- Public exports through `fx.runtime` and top-level facade aliases.
- Child specs for fiber, workflow worker, queue worker, and entity kinds.
- One-for-one restart affects only the failed child.
- One-for-all restarts every restartable child.
- Rest-for-one restarts the failed child and children registered after it.
- Permanent, transient, and temporary restart mode behavior.
- Restart intensity escalation and `Cause(SupervisorError)` formatting.
- Shutdown ordering by explicit order and reverse registration tie-break.
- Causal events for child start, restart decision, escalation, and shutdown
  ordering.

Verification commands:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/services/causal.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/supervisor_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/runtime packages/zigeffect/src/services/causal.zig packages/zigeffect/test/supervisor_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```
