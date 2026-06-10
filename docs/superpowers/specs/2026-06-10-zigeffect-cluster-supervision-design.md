# zigeffect Cluster Supervision Design

Date: 2026-06-10

Milestone: 39 - Cluster Supervision

Roadmap: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Goal

Make cluster execution supervised across shard-owned entity and workflow handler
failures. A recoverable handler failure should restart locally through the
existing deterministic supervisor. A failure that exceeds the configured
restart policy should escalate by releasing shard ownership so another runner
can acquire the shard and continue from durable message storage.

## Context

The runtime already has a deterministic local `Supervisor` in
`src/runtime/supervisor.zig`, and `LocalEntityRuntime` already uses it for
entity handler failures. The cluster runtime currently sees those handler
failures only as returned errors from `processShard`, so it cannot produce a
cluster supervision report, count workflow worker failures, or release a shard
when local recovery has escalated.

M39 should reuse the existing supervisor semantics rather than create a second
supervision model. The cluster layer should add shard, workflow-worker, and
runner reporting around local restart decisions.

## Scope

In scope:

- Cluster supervision types and reports.
- Public shard, entity, workflow worker, and runner supervision exports.
- Supervised shard processing that records local restarts and escalations.
- Shard release when entity or workflow worker recovery escalates.
- Runner-level restart policy state for deterministic local runner loops.
- Tests proving local restart and shard migration behavior.

Out of scope:

- Real networked supervision trees.
- Async process monitors.
- Distributed parent/child supervisor hierarchies.
- Cross-node restart orchestration beyond shard release and reacquisition.

Those capabilities belong to the later full supervision tree milestone.

## Design

### Cluster Supervision Module

Add `src/cluster/supervision.zig` as the cluster supervision boundary. It will
define:

- `ClusterSupervisionPolicy`
- `ClusterRunnerRestartPolicy`
- `ClusterRunnerRestartState`
- `ClusterRunnerRestartDecision`
- `ClusterSupervisionReport`

`ClusterSupervisionPolicy` controls whether shard ownership is released when a
local entity escalates. It also carries the workflow entity type name used to
classify workflow worker failures without adding an import cycle from
`cluster/runtime.zig` to `cluster/workflow_engine.zig`.

`ClusterRunnerRestartState` is a small deterministic restart-intensity tracker
for runner loops. It records failure timestamps, prunes them by policy window,
and reports whether a runner restart is still allowed or whether escalation is
required.

### Supervisor Child Kinds

Extend `SupervisorChildKind` with `runner` and `shard`. Existing values remain
stable. This lets cluster code report runner and shard supervision through the
same vocabulary as fibers, workflow workers, queue workers, and entities.

### Entity Supervisor Decisions

`LocalEntityRuntime` should expose the most recent supervisor decision for an
entity. It already computes this decision in `handleEntityFailure`; M39 stores
it on the entity instance and provides a read API. Cluster supervision can then
distinguish local restarts from escalations without guessing from status alone.

### Supervised Cluster Processing

Add supervised processing methods alongside existing methods:

- `ClusterRuntime.processShardSupervised`
- `ClusterRuntime.processOwnedShardsSupervised`
- `LocalClusterRunner.tickSupervised`

Existing `processShard`, `processOwnedShards`, and `tick` keep their current
error-return behavior for compatibility.

The supervised path processes durable messages like the existing path. When a
handler succeeds, it replies and acknowledges exactly as before. When a handler
fails:

- The local entity runtime has already applied its supervisor policy.
- The durable message remains unacknowledged and retryable.
- The report records an entity failure.
- If the local supervisor restarted the entity, the report records an entity
  restart and processing continues to the next message.
- If the entity escalated, the report records an escalation.
- If configured, the runtime releases the shard and stops scanning that shard.

Because claimed messages still count as unprocessed in message storage, another
runner can later acquire the released shard, claim the message again, and finish
it. This preserves at-least-once delivery.

### Workflow Worker Supervision

Workflow executions are cluster entities. The supervised path classifies a
handler failure as a workflow worker failure when the entity type name matches
the workflow entity type configured in `ClusterSupervisionPolicy`. It records
workflow worker restarts when the local supervisor restarts the workflow entity.

### Runner-Level Restart Policy

`LocalClusterRunnerOptions` gains a `runner_restart_policy`, and
`LocalClusterRunner` owns a `ClusterRunnerRestartState`. `tickSupervised`
returns runner restart/escalation counts in its report. The policy state is
deterministic and local; it is meant to govern the local runner loop until later
runtime milestones add real async process management.

## Public API

The cluster namespace exports:

- `cluster.supervision`
- `ClusterSupervisionPolicy`
- `ClusterRunnerRestartPolicy`
- `ClusterRunnerRestartState`
- `ClusterRunnerRestartDecision`
- `ClusterSupervisionReport`

The top-level facade mirrors these exports through `src/zigeffect.zig`.

## Error Handling

The unsupervised methods preserve existing behavior and keep returning handler
errors. The supervised methods treat handler failures as supervision events when
the local entity runtime has a decision for the entity. Storage, lease, stale
fence, and malformed infrastructure errors still return errors because they are
outside entity handler recovery.

Shard release during escalation returns errors if lease release fails. The
message is left durable either way; no supervised failure path acknowledges a
message that did not successfully run.

## Testing

Add `test/cluster_supervision_test.zig` and import it from `test/all_test.zig`.

Coverage:

- Public cluster supervision exports.
- Runner restart state allows failures within intensity and escalates after the
  configured budget.
- Supervised cluster processing records local entity restart and leaves the
  shard owned.
- Supervised cluster processing releases a shard on entity escalation.
- A second runner can acquire the released shard and finish the retryable
  message.
- Workflow entity handler failures are counted as workflow worker failures and
  restarts.

## Acceptance

M39 is complete when tests prove:

- Recoverable entity failures restart locally under the existing supervisor.
- Escalated entity failures release shard ownership.
- Durable messages survive escalation and can be completed by another runner.
- Workflow execution entity failures are reported as workflow worker failures.
- Runner-level restart policy state is deterministic and exported.
