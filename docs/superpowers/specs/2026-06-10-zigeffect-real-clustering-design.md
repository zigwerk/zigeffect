# zigeffect Real Clustering Design

Date: 2026-06-10

Milestone: 50 - Real Clustering

## Goal

Graduate the local multi-runner model into an explicit distributed cluster
control plane. The control plane must admit runners, discover runner health,
compute shard placement, apply rebalancing and drain actions through durable
lease storage, recover node-down shards, report split-brain evidence, and expose
cluster inspection output without bypassing the existing durable message,
lease, and workflow paths.

## Existing Foundation

The cluster package already provides:

- Stable runner identity through `RunnerAddress`, `machineId`, `runnerId`, and
  `runnerAddress`.
- `LocalRunnerRegistry` with startup registration, heartbeat history, state
  transitions, and `LocalRunnerHealthInspector`.
- `RunnerStorage` with in-memory and file-backed lease stores.
- `LocalShardLeaseManager` with acquire, refresh, release, recovery, audit, and
  forced stale release.
- `LocalClusterRunner`, which owns a lease manager, runtime, router, and local
  entity runtime.
- `balancedShardPlan` for fixed-index local shard assignment.
- `ClusterTransport` production modes for durable ingress across a byte
  protocol boundary.
- Cluster observability reports for leases, lag, failures, and causal events.

M50 should compose these pieces into a real cluster controller instead of
rewriting the runner, message storage, or workflow command path.

## New Module

Create `packages/zigeffect/src/cluster/real_cluster.zig`.

Export it from:

- `fx.cluster.real_cluster`
- `fx.cluster.RealClusterController`
- top-level `fx.RealClusterController`

The module owns cluster membership, placement, rebalance, drain, recovery,
split-brain, and admin inspection types.

## Public Types

Add:

```zig
pub const ClusterMembershipState = enum {
    joining,
    active,
    draining,
    leaving,
    down,
    rejected,
};

pub const ClusterAdmissionDecision = enum {
    admitted,
    already_member,
    rejected,
};

pub const ClusterMember = struct {
    address: RunnerAddress,
    name: []const u8,
    state: ClusterMembershipState,
    started_at_ms: u64,
    last_seen_at_ms: ?u64 = null,
};

pub const ClusterMembershipReport = struct {
    allocator: Allocator,
    generated_at_ms: u64,
    members: []ClusterMember,
    active: usize = 0,
    draining: usize = 0,
    down: usize = 0,
};
```

`ClusterMember.name` is owned by the report and freed by `deinit`.

Add placement and rebalance types:

```zig
pub const ClusterPlacementStrategy = enum {
    balanced,
};

pub const ClusterShardPlacement = struct {
    shard_id: ShardId,
    owner: RunnerAddress,
};

pub const ClusterPlacementPlan = struct {
    allocator: Allocator,
    strategy: ClusterPlacementStrategy,
    placements: []ClusterShardPlacement,
};

pub const ClusterRebalanceActionKind = enum {
    acquire,
    release,
    handoff,
};

pub const ClusterRebalanceAction = struct {
    kind: ClusterRebalanceActionKind,
    shard_id: ShardId,
    from: ?RunnerAddress = null,
    to: ?RunnerAddress = null,
};

pub const ClusterRebalancePlan = struct {
    allocator: Allocator,
    actions: []ClusterRebalanceAction,
    current_placements: usize = 0,
    desired_placements: usize = 0,
};
```

Add drain, recovery, split-brain, and inspection types:

```zig
pub const ClusterDrainPlan = struct {
    runner: RunnerAddress,
    released: usize,
    reassigned: usize,
};

pub const ClusterNodeDownRecoveryPlan = struct {
    dead_runner: RunnerAddress,
    recovered_by: RunnerAddress,
    released: usize,
    reassigned: usize,
};

pub const ClusterSplitBrainFinding = struct {
    shard_id: ShardId,
    local_owner: RunnerAddress,
    storage_owner: ?RunnerAddress = null,
    local_epoch: runner_storage.ShardLeaseEpoch,
    storage_epoch: ?runner_storage.ShardLeaseEpoch = null,
};

pub const ClusterSplitBrainReport = struct {
    allocator: Allocator,
    findings: []ClusterSplitBrainFinding,
};

pub const ClusterInspectionReport = struct {
    allocator: Allocator,
    generated_at_ms: u64,
    members: ClusterMembershipReport,
    leases: RunnerLeaseBatch,
    metrics: ClusterMetricsSnapshot,
    recent_rebalance_actions: usize = 0,
    recent_failures: usize = 0,
};
```

Each report owns its allocated arrays and provides `deinit`.

## Controller

`RealClusterController` is a deterministic control-plane facade:

```zig
pub const RealClusterControllerOptions = struct {
    shard_count: ShardCount,
    lease_ttl_ms: RunnerLeaseTtlMs,
    placement_strategy: ClusterPlacementStrategy = .balanced,
    health_options: RunnerHealthInspectorOptions = .{},
};

pub const RealClusterController = struct {
    allocator: Allocator,
    runner_storage: RunnerStorage,
    message_storage: MessageStorage,
    registry: *LocalRunnerRegistry,
    inspector: LocalRunnerHealthInspector,
    options: RealClusterControllerOptions,
    recent_rebalance_actions: usize = 0,
    recent_failures: usize = 0,
};
```

Construction validates:

- `shard_count > 0`
- `lease_ttl_ms > 0`
- valid runner health thresholds

## Membership Protocol

`admitRunner` calls `LocalRunnerRegistry.registerRunner`. A duplicate runner
returns `ClusterAdmissionDecision.already_member`. A newly admitted runner starts
as `joining`.

`recordHeartbeat` delegates to `LocalRunnerRegistry.recordHeartbeat` and
promotes a member to `active` when the registry reports `.healthy`.

`membershipReport` inspects all registered runners and maps:

- `starting` to `joining`
- `healthy` and `degraded` to `active`
- `unhealthy` to `down`
- `stopped` to `leaving`

Drain-specific state is stored by controller operations in the returned reports
and exposed through `ClusterDrainPlan`.

## Runner Discovery And Admission

`discoverRunners` returns `ClusterMembershipReport` from the registry and
health inspector. The report is sorted by machine id and runner id so shard
placement remains deterministic.

Admission is explicit: unregistered runners are never selected for placement.
The controller treats only active members as shard owners.

## Shard Placement

`placementPlan` computes desired owners for every shard using active members.
For balanced placement:

```text
owner_index = shard_id % active_member_count
```

Active members are sorted by `(machine_id, runner_id)`. A plan with zero active
members returns `error.NoActiveClusterMembers`.

## Rebalancing

`rebalancePlan` compares durable leases in `RunnerStorage` with the desired
placement plan:

- no lease for desired shard -> `acquire`
- lease owned by inactive or wrong runner -> `handoff`
- lease for a shard outside the configured shard count -> `release`

`applyRebalancePlan` mutates `RunnerStorage` only:

- `acquire` calls `RunnerStorage.acquire` for the desired owner.
- `handoff` releases the current owner then acquires the desired owner.
- `release` releases the current owner.

After direct storage changes, a runner must call the new
`syncOwnedLeasesFromStorage` on its lease manager, or `syncOwnedShards` on
`LocalClusterRunner`, before processing assigned shards. This keeps controller
state durable while preserving runner-local ownership caches.

## Rolling Restart And Graceful Drain

`drainRunner`:

1. Marks the runner stopped in `LocalRunnerRegistry`.
2. Builds a placement plan from remaining active members.
3. Releases leases owned by the drained runner.
4. Acquires replacement leases for desired owners.
5. Returns `ClusterDrainPlan`.

The controller does not drop messages. Messages remain in `MessageStorage` and
are processed after the replacement runner syncs leases and loads owned shards.

## Node-Down Recovery

`recoverNodeDown`:

1. Inspects the target runner.
2. Requires state `unhealthy` or `stopped`; otherwise returns
   `error.RunnerStillAlive`.
3. Releases all leases owned by the dead runner.
4. Reassigns those shards according to active placement.
5. Returns `ClusterNodeDownRecoveryPlan`.

The recovery path uses the same durable storage semantics as `LocalClusterRunner`
recovery, but operates at the cluster control-plane level.

## Split-Brain Scenarios

`detectSplitBrain` accepts local lease snapshots from one or more runners and
compares each local owner/epoch with durable `RunnerStorage`.

A finding is produced when:

- storage has no lease for a locally owned shard;
- storage owner differs from local owner;
- storage epoch differs from local epoch.

This makes split-brain evidence explicit even when storage has already fenced
stale writes.

## Administration And Inspection

`inspectCluster` returns:

- membership report;
- current durable leases;
- cluster metrics from `collectClusterMetrics`;
- recent rebalance action count;
- recent failure count.

Add formatters:

- `formatClusterInspectionText`
- `formatClusterInspectionJson`

Add a lightweight tool:

- `packages/zigeffect/tools/cluster_inspect.zig`
- build step `zig build cluster-inspect`

The tool should print an empty deterministic inspection report when run with
`--help` or no storage arguments. Real storage wiring can pass file-backed
directories in later operational packaging without changing the report schema.

## Tests

Create `packages/zigeffect/test/real_cluster_test.zig` and add it to
`all_test.zig`.

Coverage:

- public exports;
- runner admission and discovery;
- balanced placement with active members;
- rebalance plan and apply for add-runner flow;
- graceful drain reassigns leases and keeps message correctness after a runner
  syncs owned shards;
- node-down recovery refuses live runners and reassigns unhealthy runner leases;
- split-brain detection reports stale local owners and epochs;
- inspection text and JSON include membership, placement/lease counts, lag,
  rebalance actions, and failures;
- `zig build cluster-inspect -- --help` runs.

## Completion Definition

Milestone 50 is complete when the real cluster controller can admit runners,
discover active members, compute deterministic placement, apply rebalance and
drain plans through durable lease storage, recover node-down shards, surface
split-brain findings, and produce inspection reports. The full release gate must
pass before moving to full supervision trees.
