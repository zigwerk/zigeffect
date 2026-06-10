# zigeffect Cluster Observability And Causal Queries Design

Date: 2026-06-10

Milestone: 40 - Cluster Observability And Causal Queries

Roadmap: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Goal

Make cluster behavior inspectable through the same causal, metrics, tracing, and
DOT-reporting posture used by the core runtime. A cluster failure report should
identify the runner, shard, durable message, and cause without requiring a
developer to inspect every store manually.

## Context

`CausalStore` already supports structural events, snapshots, lineage/cause
queries, and DOT rendering. `LocalShardLeaseManager` already emits causal events
for lease acquisition, refresh, release, conflicts, handoff, and recovery when
attached to a causal store. `Metrics` and `Tracing` services are deterministic
in-memory services suitable for testable local cluster reporting.

The missing M40 layer is cluster-specific: runner/message/entity event kinds,
query reports over cluster causal events, cluster-shaped DOT rendering,
store-derived metrics, and trace context propagation through durable messages.

## Scope

In scope:

- Cluster causal event taxonomy for runner, shard, message, lease, entity, and
  trace propagation evidence.
- Runtime recording hooks for message and entity lifecycle events.
- A cluster observability module with query reports, DOT rendering, metrics
  collection, trace helpers, and failure report formatting.
- Durable trace context fields on cluster messages.
- Tests proving failure reports include runner, shard, message, and cause.

Out of scope:

- OpenTelemetry export for cluster reports.
- Network-wide trace sampling.
- External metrics sinks.
- Browser or dashboard UI.

Those belong to later real deployment and observability hardening milestones.

## Design

### Causal Event Taxonomy

Extend `CausalEventKind` with cluster event kinds:

- `cluster_runner_registered`
- `cluster_runner_heartbeat`
- `cluster_message_submitted`
- `cluster_message_claimed`
- `cluster_message_acked`
- `cluster_message_replied`
- `cluster_entity_registered`
- `cluster_entity_processed`
- `cluster_entity_failed`
- `cluster_trace_propagated`

Existing shard lease event kinds remain the lease and shard ownership source of
truth. The taxonomy marks these new events as structural finding evidence.

### Durable Trace Context

Add optional `trace_id` and `span_id` fields to `MessageEnvelope`. Clone,
diagnostic, JSON formatting, and JSON parsing paths preserve these fields.

Message submission APIs keep the current simple methods and add traced
variants:

- `ClusterEntityRef.tellWithTrace`
- `ClusterEntityRef.askWithTrace`
- `LocalClusterRouter.routeTellWithTrace`
- `LocalClusterRouter.routeAskWithTrace`

The existing untraced methods pass no trace context.

### Cluster Observability Module

Create `src/cluster/observability.zig`. It defines:

- `ClusterTraceContext`
- `ClusterCausalRecorder`
- `ClusterCausalReport`
- `ClusterQueryReport`
- `ClusterMetricsSnapshot`
- `ClusterFailureReport`

`ClusterCausalRecorder` wraps a `CausalStore` pointer and run id. It records
runner, message, entity, and trace propagation events with consistent labels
and redacted detail fields.

`ClusterCausalReport` is a filtered snapshot of cluster events. It includes
event counts by runner, shard, message, entity, and failure status.

`ClusterQueryReport` combines durable stores with causal evidence. It reads
runner leases from `RunnerStorage`, messages from `MessageStorage` by shard, and
events from `CausalStore`.

`ClusterMetricsSnapshot` is a compact value object used by tests and users. It
contains lease count, mailbox lag, retry count, migration count, and failure
count. It can also write gauges and counters into `Metrics`.

`ClusterFailureReport` is the user-facing failure summary. It stores runner,
shard, message id, attempt, entity address, cause, and redacted detail.

### Runtime Recording Hooks

`ClusterRuntime` gains an optional `ClusterCausalRecorder`. It records:

- entity registration
- message submission
- message claim
- reply storage
- ack
- handler failure
- trace propagation when a submitted message carries trace context

`LocalClusterRunner.attachCausalStore` attaches the same store to the runner's
lease manager and cluster runtime so shard lease and message/entity events share
a run id.

### DOT Rendering

`formatClusterCausalDot` renders only cluster events into a deterministic DOT
graph named `zigeffect_cluster`. It includes runner, shard, message, and entity
labels when present in event detail. It uses the same escaping and redaction
posture as the existing causal DOT renderer.

### Metrics

`collectClusterMetrics` reads:

- active leases from `RunnerStorage`
- unprocessed messages by shard from `MessageStorage`
- retry counts from message attempts
- migration counts from causal shard recovery and shard release events
- failure counts from cluster entity failure events

`recordClusterMetrics` writes deterministic names into `Metrics`, including:

- `cluster.leases.active`
- `cluster.mailbox.lag`
- `cluster.messages.retries`
- `cluster.shards.migrations`
- `cluster.failures`

### Failure Report

`formatClusterFailureReport` produces a concise textual report. It must include:

- runner machine and runner id
- shard id
- message id and attempt
- entity type and id
- cause
- redacted detail

The report is intentionally text because the package already has DOT and JSON
causal renderers for richer formats.

## Public API

The cluster namespace exports:

- `cluster.observability`
- `ClusterTraceContext`
- `ClusterCausalRecorder`
- `ClusterCausalReport`
- `ClusterQueryReport`
- `ClusterMetricsSnapshot`
- `ClusterFailureReport`
- `formatClusterCausalDot`
- `collectClusterMetrics`
- `recordClusterMetrics`
- `formatClusterFailureReport`

The top-level facade mirrors these exports through `src/zigeffect.zig`.

## Error Handling

Observability must not acknowledge, claim, or mutate durable workflow state. Its
store reads can return storage errors. Runtime recording errors propagate from
paths that already return errors, preserving allocator and backend failure
visibility.

Failure report formatting owns its allocated output and redacts sensitive
detail through causal-store redaction when events pass through `CausalStore`.
Callers passing already-redacted detail keep control over the exact content.

## Testing

Add `test/cluster_observability_test.zig` and import it from
`test/all_test.zig`.

Coverage:

- Public observability exports.
- Causal taxonomy includes runner, message, entity, and trace propagation
  events.
- Message envelope trace context clones and round-trips through file JSON.
- Runtime message submission and supervised failure record causal events.
- Cluster causal query reports count runner, shard, message, entity, and
  failure evidence.
- Cluster DOT output contains cluster graph metadata and parent edges.
- Metrics collection records lease, lag, retry, migration, and failure values.
- Failure report identifies runner, shard, message, and cause.

## Acceptance

M40 is complete when:

- Cluster runtime events are available in `CausalStore`.
- Trace context survives durable message storage.
- Query, DOT, metrics, and failure report APIs are exported and tested.
- The failure report names the runner, shard, message, entity, and cause.
