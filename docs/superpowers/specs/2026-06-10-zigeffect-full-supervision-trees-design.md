# zigeffect Full Supervision Trees Design

Date: 2026-06-10

Milestone: 51 - Full Supervision Trees

Roadmap: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Goal

Provide Erlang-style supervision as a first-class zigeffect runtime feature
across local runtime children, workflow workers, activities, queue workers,
cluster entities, shard workers, transport servers, runner services, and
distributed runner drain paths.

## Context

Earlier milestones added a deterministic local `Supervisor` and then used it
inside cluster entity processing. That gave the project permanent, transient,
and temporary restart modes, three local restart strategies, restart intensity
windows, causal events, and shard release after entity escalation.

M51 turns that foundation into a complete supervision tree surface:

- Child specs cover every runtime and cluster worker kind named by the roadmap.
- A dynamic strategy supports runtime child attach, stop, and removal.
- Decisions are recorded in bounded supervisor history for inspection.
- A `SupervisorTree` groups supervisors into parent-child relationships and
  reports escalation across the tree.
- Cluster supervision reports cover shard worker failures, transport failures,
  runner service failures, and runner drains.
- Distributed cleanup is explicit: shard worker escalation releases local shard
  ownership, and runner drain releases and reassigns stored shard leases.

## Runtime Model

The supervision runtime remains deterministic and single-process. It supervises
logical zigeffect children rather than spawning OS processes directly. Real
async I/O, transports, queue loops, and runner processes call into the
supervisor APIs when their logical children exit or fail.

This keeps the core portable across Cloudflare Workers, Bun tooling, local Zig
tests, and future containerized runtimes while still giving the API Erlang-style
restart, escalation, tree, and inspection behavior.

## Supervisor Contract

### Child Kinds

`SupervisorChildKind` gains the full child vocabulary:

- `fiber`
- `activity`
- `workflow_worker`
- `queue_worker`
- `entity`
- `shard`
- `shard_worker`
- `runner`
- `runner_service`
- `transport_server`

Existing tags remain valid. The new tags let callers describe workflow
activities, shard loops, transport listeners, and runner services using the
same supervision API as fibers and entities.

### Strategies

`SupervisorStrategy` supports:

- `one_for_one`: restart or stop only the exited child.
- `one_for_all`: restart or stop every restartable child under the supervisor.
- `rest_for_one`: restart or stop the exited child and every child registered
  after it.
- `dynamic`: restart or stop only the exited child, while allowing children to
  be added, stopped, and removed during runtime.

Dynamic supervision is intentionally deterministic: child order, restart
counts, decision history, and inspection output are stable for a given sequence
of operations.

### Restart Modes

The existing restart modes remain:

- `permanent`: restart after success, failure, defect, or interruption.
- `transient`: restart after failure, defect, or interruption; stop after
  success.
- `temporary`: stop after every exit.

### Intensity And Escalation

Restart intensity remains supervisor-wide. Before applying a decision, the
supervisor counts how many affected children would restart. If applying that
restart set would exceed `max_restarts` inside `within_ms`, all affected
children are marked `escalated` and the decision is recorded with
`escalated = true`.

Escalation stays local to the supervisor, while the tree inspection aggregates
escalated children and decisions across parent and child supervisors.

## Inspection Model

Every supervisor keeps a bounded recent decision history. Inspection returns:

- Supervisor id, name, strategy, and restart window.
- Child snapshots with id, name, kind, status, restart count, and registration
  order.
- Recent decision records with timestamp, exited child, strategy, exit kind,
  restart count, stop count, affected count, and escalation state.
- Counts for running, stopped, failed, escalated, and dynamic children.
- Shutdown ordering evidence using the same order as `shutdownPlan`.

Text and JSON formatters expose inspection in stable schemas suitable for CLIs,
tests, and diagnostics.

## Supervision Tree Model

`SupervisorTree` is a deterministic aggregate over several `Supervisor`
instances. It provides:

- Root and child supervisor registration.
- Parent-child supervisor links.
- Child registration on any supervisor node.
- Child exit reporting on any supervisor node.
- Tree inspection with node summaries, child summaries, decisions, and
  aggregate escalation counts.

The tree delegates restart decisions to each node's own `Supervisor`, so
strategy behavior stays in one implementation. The tree owns supervisor
lifecycle and report memory.

## Cluster Supervision Model

Cluster supervision extends the existing `ClusterSupervisionReport` with
runner, shard, and transport decisions:

- `shard_worker_failures`
- `shard_worker_restarts`
- `shard_worker_escalations`
- `transport_failures`
- `transport_restarts`
- `transport_escalations`
- `runner_service_failures`
- `runner_service_restarts`
- `runner_service_escalations`
- `runner_drains`
- `runner_drain_releases`
- `runner_drain_reassignments`

The report keeps additive aggregation so runner ticks and controllers can merge
local and distributed decisions.

### Shard Worker Failure

`ClusterRuntime.superviseShardWorkerExit` records a shard worker failure under a
small restart state. A restartable failure increments
`shard_worker_restarts`. An escalation increments `shard_worker_escalations`
and, when policy enables release, releases the shard so another runner can
claim it.

### Transport Failure

`superviseTransportFailure` accepts a `ClusterTransportFailureReport`, restart
state, restart policy, and time. It records a transport failure, classifies
whether restart is allowed, and reports escalation after the configured
intensity budget.

Transport implementations keep owning network details. Supervision receives a
sanitized failure report and produces the restart decision.

### Runner Service Failure

`LocalClusterRunner.tickSupervised` wraps lease refresh, shard loading, and
owned-shard processing. If the runner service loop itself fails before a normal
cluster report is available, it records the failure in runner restart state and
returns a report with restart or escalation counts.

### Runner Drain

`RealClusterController.superviseRunnerDrain` wraps `drainRunner` and converts
distributed cleanup into a supervision report. It records one runner drain,
released shard count, reassigned shard count, and runner service restart
decision data when a drain is triggered by a runner service failure.

## Causal Events

Existing supervisor causal events remain the source of truth for local runtime
decisions:

- `supervisor_child_started`
- `supervisor_restart_decided`
- `supervisor_escalated`
- `supervisor_shutdown_ordered`

M51 records causal events for dynamic child stop/removal and inspection-triggered
shutdown ordering through the same store when one is attached. Cluster
supervision reports are deterministic data structures; callers can record them
through existing cluster observability and causal helpers.

## Public API

Runtime exports:

- `SupervisorDecisionRecord`
- `SupervisorInspectionReport`
- `formatSupervisorInspectionText`
- `formatSupervisorInspectionJson`
- `SupervisorTree`
- `SupervisorTreeOptions`
- `SupervisorTreeNodeOptions`
- `SupervisorTreeInspectionReport`
- `formatSupervisorTreeInspectionText`
- `formatSupervisorTreeInspectionJson`

Cluster exports:

- `ClusterServiceRestartState`
- `ClusterServiceRestartDecision`
- `ClusterServiceRestartPolicy`
- `superviseTransportFailure`
- `superviseShardWorkerFailure`
- `ClusterSupervisionReport` with the extended counters
- `RealClusterController.superviseRunnerDrain`
- `ClusterRuntime.superviseShardWorkerExit`

Top-level `zigeffect` mirrors the public runtime and cluster exports.

## Testing

Runtime tests cover:

- Full child kind exports.
- Dynamic strategy restart, stop, and child removal.
- Inspection report child counts, decision history, shutdown order, and JSON
  formatter fields.
- Supervisor tree parent-child links, node inspection, and aggregate escalation
  counts.

Cluster tests cover:

- Transport failure restart and escalation reports.
- Shard worker restart followed by escalation and shard release.
- Runner service failure reporting through supervised runner tick.
- Runner drain supervision releasing and reassigning shard leases.

## Acceptance

M51 is complete when:

- Local child failure, repeated failure escalation, shard worker failure,
  transport failure, and runner drain all produce explicit supervision
  decisions.
- Permanent, transient, temporary, one-for-one, one-for-all, rest-for-one, and
  dynamic behavior are covered by tests.
- Supervisor inspection explains restart decisions, escalation causes, affected
  children, and cleanup ordering.
- Distributed supervision behavior releases shard ownership on shard worker
  escalation and reports runner drain cleanup counts.
- The full zigeffect verification gate passes.
