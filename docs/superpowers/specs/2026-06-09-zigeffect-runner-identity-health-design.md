# zigeffect Runner Identity And Health Design

Date: 2026-06-09

## Purpose

Milestone 28 defines cluster participants before leases, shard ownership, and
multi-runner transport. It adds stable runner identity, startup registration,
heartbeat history, health states, in-memory health-transition persistence, and a
local inspector that can report current runner health.

## Current Context

The cluster domain currently has deterministic entity identity, local mailbox
and entity runtime behavior, durable message envelopes, and deterministic shard
routing. There is no runner participant model yet. The next milestone,
Runner Storage, owns storage contracts and file-backed persistence, so this
milestone must keep runner records local and in-memory while making the shape
ready for storage adapters.

## Requirements

- Add `RunnerId`, `RunnerAddress`, and `MachineId`.
- Add stable helper functions for machine ids, runner ids, and runner
  addresses.
- Add runner startup registration with duplicate detection.
- Add runner heartbeat records with monotonic sequence validation.
- Add health states for starting, healthy, degraded, unhealthy, and stopped.
- Add in-memory persistence for registration records, heartbeat history, and
  health transition events.
- Add a local runner health inspector that computes and persists health
  transitions from heartbeat age.
- Expose public aliases through `fx.cluster` and top-level `fx`.
- Keep file storage, lease acquisition, shard ownership, and remote health
  probes out of this milestone.

## Module Layout

Create `packages/zigeffect/src/cluster/runner.zig`.

This module owns:

- Runner identity types and hash helpers.
- Runner registration and heartbeat records.
- Runner health states and transition events.
- `LocalRunnerRegistry`, an allocator-owned in-memory registry.
- `LocalRunnerHealthInspector`, a deterministic inspector over the registry.
- Snapshot and report types used by tests and future tooling.

One module is enough for this milestone because the inspector depends directly
on registry internals and the total surface remains small. Future storage and
lease modules can import these types without depending on implementation-only
helpers.

## Public Types

`RunnerId = u64`

`MachineId = u64`

`RunnerAddress = struct { machine_id: MachineId, runner_id: RunnerId }`

`RunnerHealthState = enum { starting, healthy, degraded, unhealthy, stopped }`

`RunnerHealthReason = enum { startup_registered, heartbeat_recorded, heartbeat_late, heartbeat_expired, runner_stopped }`

`RunnerRegistration = struct { address: RunnerAddress, name: []const u8, started_at_ms: u64 }`

`RunnerHeartbeat = struct { address: RunnerAddress, sequence: u64, observed_at_ms: u64 }`

`RunnerHealthEvent = struct { address: RunnerAddress, previous_state: ?RunnerHealthState, next_state: RunnerHealthState, reason: RunnerHealthReason, at_ms: u64 }`

`RunnerHealthSnapshot = struct { address: RunnerAddress, name: []const u8, state: RunnerHealthState, started_at_ms: u64, last_heartbeat_at_ms: ?u64, last_heartbeat_sequence: ?u64, heartbeat_age_ms: ?u64, health_event_count: usize }`

`RunnerHealthReport = struct { generated_at_ms: u64, snapshots: []RunnerHealthSnapshot }`

`RunnerHealthInspectorOptions = struct { degraded_after_ms: u64 = 5_000, unhealthy_after_ms: u64 = 15_000 }`

`RunnerRegistryError = error{ DuplicateRunner, RunnerNotFound, InvalidHeartbeatSequence, InvalidHealthThresholds }`

## Identity

`machineId(machine_key)` uses FNV-1a 64 with a `zigeffect.cluster.machine.v1`
namespace. `runnerId(machine_id, runner_key)` uses FNV-1a 64 with a
`zigeffect.cluster.runner.v1` namespace and the machine id bytes. This keeps
machine identity stable while allowing multiple local runners on the same
machine.

`runnerAddress(machine_key, runner_key)` builds both ids and returns a
`RunnerAddress`.

`RunnerAddress.eql(other)` compares both machine and runner ids.

## Registration And Heartbeats

`LocalRunnerRegistry.init(allocator)` creates an empty in-memory registry.

`registerRunner(registration)` clones the runner name, stores a record in
`starting` state, and appends a `startup_registered` health event with
`previous_state = null`.

`recordHeartbeat(heartbeat)` validates that the runner exists and that heartbeat
sequence numbers increase monotonically. It appends the heartbeat record,
updates the runner to `healthy`, and records a `heartbeat_recorded` event when
the state changes.

`markStopped(address, at_ms)` moves a runner to `stopped` and records a
`runner_stopped` event. Stopped runners remain stopped during inspection.

The registry exposes borrowed snapshots while it is alive:

- `runnerCount()`
- `heartbeatCount(address)`
- `healthEventCount(address)`
- `state(address)`
- `lastHeartbeat(address)`
- `snapshot(address, now_ms)`
- `healthEvents(address)`

## Health Inspector

`LocalRunnerHealthInspector.init(options)` validates that
`degraded_after_ms <= unhealthy_after_ms`.

`inspectRunner(registry, address, now_ms)` computes health from the registry:

- `stopped` remains `stopped`.
- No heartbeat keeps a runner `starting` until `unhealthy_after_ms` after
  startup, then marks it `unhealthy`.
- A heartbeat age greater than or equal to `unhealthy_after_ms` marks the runner
  `unhealthy`.
- A heartbeat age greater than or equal to `degraded_after_ms` marks the runner
  `degraded`.
- Otherwise the runner is `healthy`.

Whenever inspection changes state, the registry records a health event with
`heartbeat_late` or `heartbeat_expired`. Repeated inspections at the same state
do not duplicate events.

`inspectAll(allocator, registry, now_ms)` updates every runner and returns an
owned `RunnerHealthReport`. The report owns the snapshot array but borrows names
from the registry, so callers must deinit the report before deiniting the
registry.

## Testing

Add `packages/zigeffect/test/runner_test.zig`.

Tests cover:

- Public exports for `runner`, ids, registration, heartbeat, health states,
  registry, inspector, and report types.
- Stable machine, runner, and address derivation.
- Duplicate runner registration.
- Startup registration persistence and inspectable startup event.
- Heartbeat persistence, monotonic sequence validation, and healthy transition.
- Inspector transitions to degraded and unhealthy based on heartbeat age.
- Stopped runners remain stopped during inspection.
- `inspectAll` returns an owned report containing current runner snapshots.

## Documentation

Update `packages/zigeffect/docs/architecture.md` to list `runner.zig` in the
cluster module inventory. Update the durable workflows and clustering roadmap
only after the full verification gate proves Milestone 28 complete.
