# zigeffect Durable Workflows And Clustering Roadmap

> **For agentic workers:** This is the execution spine for a long-running goal.
> Work milestone by milestone. Do not skip ahead when a milestone has unverified
> acceptance criteria. When a milestone is large enough to need implementation,
> create the focused spec in `docs/superpowers/specs/` and the focused plan in
> `docs/superpowers/plans/`, then execute that slice before returning here.

Date: 2026-06-07

## Purpose

Bring durable workflows and Erlang-style clustering into `zigeffect` as first
class Zig runtime capabilities. The system should start as a local durable
workflow engine, then grow into a cluster runtime that can move work across
runner processes without losing the workflow state, actor mailbox state, or
causal evidence.

Nothing is deferred. Work is sequenced. Capabilities that cannot be built first
are still assigned concrete milestones later in this roadmap.

## Target End State

The finished system should provide:

- durable workflow definitions with typed payload, success, and failure;
- activity execution with retry, idempotency, timeout, and compensation;
- append-only workflow journals with replay after crash;
- durable timers, deferreds, external signals, and durable queues;
- workflow polling, resume, interrupt, cancellation, and inspection APIs;
- causal artifacts that explain every durable runtime decision;
- local entity actors with mailbox, supervision, and lifecycle semantics;
- shard ids, entity ids, runner ids, runner registration, leases, and
  heartbeats;
- sharded message storage with at-least-once delivery and idempotent replies;
- shard rebalancing and recovery after runner failure;
- cluster workflow execution using the same workflow journal contract;
- deterministic, crash, property, and end-to-end verification suites.

## Current Baseline

`zigeffect` already has the pieces that make this credible:

- direct-style `Effect(Success, Failure, Env)` wrappers around normal Zig
  functions;
- `Runtime`, `FiberRuntime`, `Scope`, `Exit`, and `Cause`;
- deterministic fibers with fork, join, interrupt, and scoped leases;
- deterministic `Deferred`, `Queue`, and `Semaphore`;
- `Schedule` retry and repeat policies;
- `Layer` and `LayerGraph` service startup;
- `Clock`, config, logging, metrics, tracing, and testing services;
- `CausalStore` with structured runtime events and JSON/DOT/text tooling;
- `BackendCapabilities`, currently deterministic only.

The current runtime cannot suspend, interrupt blocking IO, supervise real async
work, or run in parallel. The roadmap treats the deterministic runtime as the
compatibility suite and then expands the backend model without weakening the
existing semantics.

## Milestone 0 Baseline Inventory

The current public facade already exposes the modules that durable workflows
and clustering should build on:

- `fx.core`: `Cause`, `CauseTree`, `Exit`, `FinalizerExit`, `Scope`, and
  `Context`.
- `fx.dependency`: `ServiceSet`, `DependencyReport`, requirement validation,
  static requirement checks, and `ServiceEnv`.
- `fx.effect`: direct-style `Effect`, resource acquisition, `Schedule`, and
  `ScheduleProgram`.
- `fx.runtime`: `Runtime`, `Fiber`, `FiberRuntime`, `BackendCapabilities`,
  deterministic backend marker, `Deferred`, `Queue`, `Semaphore`, and
  wait-state enums.
- `fx.layer`: `Layer`, `LayerWithError`, graph runtime types, and
  `layerGraph`.
- `fx.services`: `Clock`, `Logger`, `Config`, `Metrics`, `Tracing`,
  `MemoryFileSystem`, `CausalStore`, causal backends, causal schema constants,
  causal taxonomy helpers, and causal report/JSON/DOT formatters.
- `fx.testing`: `TestEnv`, test services, fixture registry, runtime helpers,
  and assertion/report helpers for dependencies, causes, schedules, fibers, and
  queues.

The current backend capability contract is intentionally narrow:

- `BackendKind` has only `deterministic`.
- `can_suspend` is `false`.
- `can_interrupt_blocking_io` is `false`.
- `can_supervise` is `false`.
- `can_parallel` is `false`.

The future public facade names are reserved conceptually but not exported until
their owning milestones add real modules and architecture tests:

- `fx.workflow`: local durable workflow definitions, activity definitions,
  workflow engine, journal stores, durable timers, durable deferreds, durable
  queues, signals, lifecycle controls, inspectors, and replay helpers.
- `fx.cluster`: entity identity, actor references, message envelopes, shard ids,
  runner identity, runner storage, message storage, shard leasing,
  multi-runner runtime, transports, cluster workflow integration, and
  supervision surfaces.

## Design Invariants

- The append-only journal is the source of durable truth, not in-memory fibers.
- Replay must be deterministic and side-effect safe.
- Activities are the side-effect boundary.
- Workflow code is direct-style Zig where possible.
- All durable APIs use `Context`, `Scope`, `Exit`, `Cause`, `Schedule`, and
  `CausalStore`; no parallel runtime result language is introduced.
- Every durable operation has a stable event name, schema version, and causal
  event mapping.
- Local execution and clustered execution share the same journal format.
- Cluster ownership is leased and recoverable; no runner owns durable state by
  memory alone.
- Every milestone ends with tests and a docs update.

## Execution Protocol

- [x] Start from Milestone 0 and proceed in order.
- [x] For each implementation milestone, write a focused design spec first.
- [x] For each focused spec, write a focused implementation plan.
- [x] Use test-driven development for code changes.
- [x] Run the milestone acceptance commands before marking it complete.
- [x] Update this roadmap after each completed milestone.
- [x] Keep public API changes in the `src/zigeffect.zig` facade explicit.

## Milestone 0: Baseline Audit And Capability Inventory

Goal: lock the known starting point before durable runtime work begins.

Deliverables:

- [x] Inventory `Effect`, `Runtime`, `FiberRuntime`, coordination primitives,
  `Schedule`, `LayerGraph`, `Clock`, and `CausalStore`.
- [x] Document current backend capabilities and unsupported behaviors.
- [x] Identify the public facade names that future workflow and cluster modules
  will expose.
- [x] Add a roadmap pointer to `packages/zigeffect/docs/roadmap.md`.

Acceptance:

- [x] `bun run zigeffect:test` passes.
- [x] `cd packages/zigeffect && zig build examples` passes.
- [x] The roadmap names the exact current limitations and starting modules.

## Milestone 0.5: Durable Core Prerequisites

Goal: add the minimum core vocabulary durable workflows and clustering need
without pulling workflow behavior into the deep core.

Deliverables:

- [x] Add a small `Codec` or serialization contract for durable payloads,
  activity results, typed failures, messages, snapshots, and journal events.
- [x] Add an `IdGenerator` service for workflow ids, activity ids, timer ids,
  deferred ids, queue ids, runner ids, shard ids, and message ids.
- [x] Define a controlled suspension outcome or runtime decision vocabulary so
  durable workflow code can say "waiting" without pretending the effect has
  succeeded or failed.
- [x] Add cancellation/interruption context that workflows, activities, timers,
  deferreds, queues, and compensation can observe cooperatively.
- [x] Expand `BackendCapabilities` enough to distinguish deterministic,
  durable-local, async-local, and cluster-capable execution.
- [x] Add causal taxonomy extension points for workflow and cluster events.

Acceptance:

- [x] Core prerequisite docs explain which pieces are deep core and which remain
  in the workflow layer.
- [x] Existing deterministic runtime behavior remains unchanged.
- [x] `bun run zigeffect:test` passes.

## Milestone 1: Durable Runtime Domain Layout

Goal: create the module boundaries before behavior lands.

Deliverables:

- [x] Add `src/workflow/` for local durable workflow types and engine code.
- [x] Add `src/cluster/` for actor, sharding, runner, and storage contracts.
- [x] Add facade namespaces `fx.workflow` and `fx.cluster`.
- [x] Add architecture docs for import direction and ownership.
- [x] Add empty architecture tests that enforce facade export shape.

Acceptance:

- [x] `bun run zigeffect:test` passes.
- [x] Architecture docs explain what belongs in workflow vs cluster.

## Milestone 2: Journal Event Model

Goal: define the durable event vocabulary before storage or execution.

Deliverables:

- [x] Add `WorkflowEventKind`.
- [x] Add stable event structs for workflow lifecycle, activity lifecycle,
  timers, durable deferreds, durable queues, signals, interrupts, resume,
  suspension, and completion.
- [x] Define `WorkflowId`, `ExecutionId`, `ActivityId`, `TimerId`,
  `DeferredId`, `QueueId`, and `JournalSequence`.
- [x] Define schema name and schema version constants.
- [x] Add JSON/text formatting helpers for journal events.

Acceptance:

- [x] Unit tests cover every event kind formatting path.
- [x] Schema docs include all event fields and redaction rules.

## Milestone 3: Journal Fold And Replay State

Goal: turn event history into deterministic workflow state.

Deliverables:

- [x] Add `WorkflowReplayState`.
- [x] Fold lifecycle events into pending, running, suspended, completed,
  failed, interrupted, cancelled, and defect states.
- [x] Fold activities into scheduled, running, completed, failed, and
  retry-ready states.
- [x] Fold timers into scheduled and fired states.
- [x] Fold deferreds into pending and completed states.
- [x] Fold queues into offered, claimed, completed, failed, and acked states.
- [x] Detect malformed histories with structured replay errors.

Acceptance:

- [x] Golden tests cover valid and invalid histories.
- [x] Replay is allocation-explicit and deterministic.

## Milestone 4: In-Memory Journal Store

Goal: build the first storage implementation for tests and model checks.

Deliverables:

- [x] Add `JournalStore` contract.
- [x] Implement append, read all, read from sequence, latest state, and reset.
- [x] Implement in-memory store.
- [x] Add optimistic sequence checks.
- [x] Add event idempotency keys.

Acceptance:

- [x] Tests prove append ordering, duplicate rejection, sequence conflict, and
  replay from memory.

## Milestone 5: File Append-Only Journal Store

Goal: make local durability real before workflow execution becomes complex.

Deliverables:

- [x] Implement newline-delimited JSON journal segments.
- [x] Add fsync policy options.
- [x] Add segment naming and recovery from partial trailing records.
- [x] Add lock file or process ownership guard.
- [x] Add corruption reporting with exact file and offset.
- [x] Add compaction checkpoint format that preserves replay equivalence.

Acceptance:

- [x] Crash fixture tests simulate partial writes and restart replay.
- [x] File store and memory store produce the same folded state.

## Milestone 6: Workflow Definition API

Goal: define typed workflows without executing them yet.

Deliverables:

- [x] Add `Workflow(Name, Payload, Success, Failure, Env)`.
- [x] Add payload idempotency key callback.
- [x] Add execution id derivation.
- [x] Add workflow metadata and requirement declarations.
- [x] Add compile diagnostics for invalid workflow functions.

Acceptance:

- [x] Tests cover valid definitions, invalid callback shapes, and metadata.

## Milestone 7: Activity Definition API

Goal: isolate side effects behind durable activity records.

Deliverables:

- [x] Add `Activity(Name, Payload, Success, Failure, Env)`.
- [x] Add activity idempotency keys.
- [x] Add retry schedule attachment.
- [x] Add timeout metadata.
- [x] Add compensation metadata.
- [x] Add compile diagnostics for invalid activity functions.

Acceptance:

- [x] Activity definitions can be formatted, inspected, and requirement-checked.

## Milestone 8: WorkflowEngine Core

Goal: register workflows and create durable executions.

Deliverables:

- [x] Add `WorkflowEngine`.
- [x] Add register, execute, poll, inspect, and list APIs.
- [x] Append `WorkflowStarted` and initial state events.
- [x] Return typed `WorkflowResult`.
- [x] Integrate dependency validation with runtime providers.

Acceptance:

- [x] In-memory engine can start and poll a no-op workflow.
- [x] Duplicate execution id behavior is explicit and tested.

## Milestone 9: Deterministic Workflow Step Runner

Goal: run pure workflow steps through replay-aware execution.

Deliverables:

- [x] Add a workflow context service available only inside workflow runs.
- [x] Add step labels and deterministic sequence assignment.
- [x] Ensure replay returns recorded step outcomes instead of re-running
  completed side effects.
- [x] Record defects and typed failures through `Exit` and `Cause`.

Acceptance:

- [x] A workflow run followed by replay emits no duplicate activity execution.
- [x] Tests prove pure steps and recorded steps converge to the same result.

## Milestone 10: Activity Scheduling And Completion

Goal: let workflows call side-effecting activities durably.

Deliverables:

- [x] Add `WorkflowContext.activity`.
- [x] Append `ActivityScheduled`, `ActivityStarted`, `ActivityCompleted`, and
  `ActivityFailed`.
- [x] Add activity attempt counters.
- [x] Add activity result serialization boundary.
- [x] Add idempotent completion by activity id.

Acceptance:

- [x] Activity success and failure replay correctly.
- [x] Re-running after crash does not duplicate completed activity effects.

## Milestone 11: Activity Retry And Timeout Semantics

Goal: connect activity failure to existing `Schedule` behavior.

Deliverables:

- [x] Record schedule decisions in journal events.
- [x] Add retry delay calculation using `Clock`.
- [x] Add timeout events and timeout failure causes.
- [x] Add exhausted retry behavior.
- [x] Add causal mapping to existing schedule decision events.

Acceptance:

- [x] Tests cover retry success, retry exhaustion, timeout, and replay.

## Milestone 12: Compensation

Goal: support cleanup for already completed durable steps when workflows fail.

Deliverables:

- [x] Add compensation registration event.
- [x] Add compensation execution events.
- [x] Define compensation ordering.
- [x] Preserve compensation failures in `Cause`.
- [x] Add idempotent compensation completion.

Acceptance:

- [x] Tests cover success, failure, repeated replay, and compensation failure.

## Milestone 13: Durable Deferred

Goal: provide durable waiting for externally completed values.

Deliverables:

- [x] Add `DurableDeferred`.
- [x] Append create, await, complete, fail, and cancel events.
- [x] Add typed success and failure serialization boundary.
- [x] Add `WorkflowContext.awaitDeferred`.
- [x] Add external completion API.

Acceptance:

- [x] Workflow can suspend on a deferred and resume after completion.
- [x] Replay preserves the completed value.

## Milestone 14: Durable Timers And Durable Clock

Goal: support durable sleep and wake-up.

Deliverables:

- [x] Add `DurableClock`.
- [x] Add `sleep`, `sleepUntil`, and timer cancellation.
- [x] Append timer scheduled and timer fired events.
- [x] Add timer query API for the local scheduler.
- [x] Add file-store timer wake-up loop.

Acceptance:

- [x] Workflow sleeps, exits process, restarts, fires timer, and resumes.

## Milestone 15: External Signals And Events

Goal: make human-in-the-loop and webhook-style workflows possible.

Deliverables:

- [x] Add named signal definitions.
- [x] Add `waitForSignal`.
- [x] Add signal append API.
- [x] Add signal idempotency keys.
- [x] Add signal timeout support.

Acceptance:

- [x] Workflow can wait for a signal, receive it after restart, and continue.

## Milestone 16: Durable Queue

Goal: build persisted producer/worker coordination on top of the journal store.

Deliverables:

- [x] Add `DurableQueue`.
- [x] Add offer, claim, complete, fail, retry, and ack events.
- [x] Add worker concurrency limits.
- [x] Add queue item idempotency keys.
- [x] Add queue processing from workflows.

Acceptance:

- [x] Queue items survive restart.
- [x] Claim timeout and retry are tested.
- [x] Workflow can await queue item completion.

## Milestone 17: Suspend, Resume, Interrupt, And Cancel

Goal: expose lifecycle controls that work across restarts.

Deliverables:

- [x] Add suspend event and suspended state.
- [x] Add resume event and runnable state transition.
- [x] Add interrupt event and interruption cause.
- [x] Add cancel event and cancellation cause.
- [x] Define behavior for pending timers, deferreds, queues, and activities.

Acceptance:

- [x] Tests cover each lifecycle action before and after restart.

## Milestone 18: Workflow Inspector And CLI Tools

Goal: make local durable runtime state understandable to humans and agents.

Deliverables:

- [x] Add `zig build workflow-journal-inspect`.
- [x] Add `zig build workflow-replay`.
- [x] Add `zig build workflow-list`.
- [x] Add formatted state, pending timers, pending deferreds, pending queues,
  and last failure reports.
- [x] Add JSON report format for agent consumption.

Acceptance:

- [x] CLI tools operate on memory fixture files and real file journals.

## Milestone 19: Causal Runtime Integration

Goal: connect durable execution to the existing agent-observable runtime.

Deliverables:

- [x] Add causal event kinds or mappings for workflow events.
- [x] Link workflow events to run id, fiber id, scope id, trace id, and span id.
- [x] Add durable workflow findings to causal query tools.
- [x] Add DOT graph rendering for workflow histories.
- [x] Add causal dogfood scenario for workflow crash recovery.

Acceptance:

- [x] Causal reports explain workflow failure, retry, suspend, and resume.

## Milestone 20: Journal Schema Versioning And Migration

Goal: make durable histories survive runtime upgrades.

Deliverables:

- [x] Add schema version headers.
- [x] Add migration registry.
- [x] Add unknown event handling policy.
- [x] Add downgrade/read-only failure mode.
- [x] Add golden fixtures for v1 histories.

Acceptance:

- [x] Older fixture histories replay under the new reader.

## Milestone 21: Storage Compaction, Snapshots, And Retention

Goal: keep long-running workflows bounded without losing correctness.

Deliverables:

- [x] Add replay snapshots.
- [x] Add safe compaction after completed sequences.
- [x] Add retention policies for completed workflows.
- [x] Add archive export.
- [x] Add corruption-safe compaction commit protocol.

Acceptance:

- [x] Snapshot plus tail replay equals full replay.
- [x] Crash during compaction does not lose acknowledged events.

## Milestone 22: Async Backend Contract Expansion

Goal: prepare the runtime for real suspension without changing workflow APIs.

Deliverables:

- [x] Expand `BackendKind` and `BackendCapabilities`.
- [x] Add async backend trait shape for suspend, wake, timer, and interrupt.
- [x] Add deterministic backend conformance tests.
- [x] Add workflow engine backend requirements.
- [x] Add diagnostics when a workflow feature requires unavailable backend
  capabilities.

Acceptance:

- [x] Deterministic backend remains green.
- [x] Unsupported async-only behavior fails with clear diagnostics.

## Milestone 23: Cooperative Local Scheduler

Goal: run pending workflow work, timers, and queues in one local process.

Deliverables:

- [x] Add runnable work registry.
- [x] Add timer wake-up polling.
- [x] Add fair queue processing loop.
- [x] Add graceful shutdown.
- [x] Add bounded work budgets.

Acceptance:

- [x] Scheduler can drive multiple workflows and queues deterministically.

## Milestone 24: Supervision Trees

Goal: introduce Erlang-style restart policy locally before clustering.

Deliverables:

- [x] Add supervisor definitions.
- [x] Add one-for-one, one-for-all, and rest-for-one policies.
- [x] Add restart intensity limits.
- [x] Add child specs for workflow workers, queue workers, and entities.
- [x] Preserve failures in `Cause` and causal reports.

Acceptance:

- [x] Supervisor tests cover restart, escalation, and shutdown ordering.

## Milestone 25: Local Entity Actor Model

Goal: add actor/entity identity and mailbox semantics without distribution.

Deliverables:

- [x] Add `EntityType`, `EntityId`, `EntityAddress`, and `EntityRef`.
- [x] Add local mailbox storage.
- [x] Add ask, tell, reply, and interrupt envelopes.
- [x] Add entity lifecycle and idle shutdown.
- [x] Add entity-scoped services and finalizers.

Acceptance:

- [x] Local entities process ordered mailbox messages and recover failures
  through supervision.

## Milestone 26: Message Envelope And Delivery Semantics

Goal: define the durable protocol shared by local and cluster messaging.

Deliverables:

- [x] Add envelope ids and idempotency keys.
- [x] Add request, reply, ack, interrupt, and chunk reply envelopes.
- [x] Add at-least-once delivery semantics.
- [x] Add duplicate reply handling.
- [x] Add redaction for message diagnostics.

Acceptance:

- [x] Message protocol tests cover duplicates, missing replies, and retries.

## Milestone 27: Shard Identity And Routing

Goal: map entity ids to shard ids deterministically.

Deliverables:

- [x] Add `ShardId`.
- [x] Add configurable shard count.
- [x] Add stable hash function for entity ids.
- [x] Add shard routing table.
- [x] Add local single-runner routing.

Acceptance:

- [x] Routing stays stable across restart and shard table reload.

## Milestone 28: Runner Identity And Health

Goal: define cluster participants before leases and rebalancing.

Deliverables:

- [x] Add `RunnerId`, `RunnerAddress`, and `MachineId`.
- [x] Add runner startup registration.
- [x] Add runner heartbeat records.
- [x] Add health states.
- [x] Add local runner health inspector.

Acceptance:

- [x] Runner health transitions are persisted and inspectable.

## Milestone 29: Runner Storage

Goal: persist runner and shard ownership metadata.

Deliverables:

- [x] Add `RunnerStorage` contract.
- [x] Implement in-memory runner storage.
- [x] Implement file-backed runner storage.
- [x] Add acquire, refresh, release, and release-all operations.
- [x] Add lease conflict errors.

Acceptance:

- [x] Lease acquisition is atomic for the file-backed local model.

## Milestone 30: Shard Leasing

Goal: let runners own shards safely for bounded time.

Deliverables:

- [x] Add lease duration and refresh cadence.
- [x] Add expired lease acquisition.
- [x] Add graceful shard handoff.
- [x] Add forced recovery after runner death.
- [x] Add causal events for shard ownership.

Acceptance:

- [x] Tests simulate runner death and shard reacquisition.

## Milestone 31: Message Storage

Goal: persist cluster messages independently of runner memory.

Deliverables:

- [x] Add `MessageStorage` contract.
- [x] Implement in-memory message storage.
- [x] Implement file-backed message storage.
- [x] Add unprocessed messages by shard.
- [x] Add unprocessed messages by id.
- [x] Add ack and reply storage.

Acceptance:

- [x] Recovery replays unprocessed messages without losing replies.

## Milestone 32: Cluster Entity Runtime

Goal: run local entities through shard-owned durable message storage.

Deliverables:

- [x] Add `ClusterRuntime`.
- [x] Load owned shards.
- [x] Pull unprocessed messages.
- [x] Dispatch envelopes to entity actors.
- [x] Store replies and acks.
- [x] Release shards on shutdown.

Acceptance:

- [x] Single process cluster runtime behaves like the local entity runtime.

## Milestone 33: Multi-Runner Local Cluster

Goal: prove clustering on one machine with multiple runner processes.

Deliverables:

- [x] Add runner process CLI.
- [x] Add shared file-backed runner and message storage.
- [x] Add shard balancing across runners.
- [x] Add runner death simulation.
- [x] Add message routing between runner processes.

Acceptance:

- [x] Two local runners split shards, recover from one runner exit, and keep
  entity messages correct.

## Milestone 34: Transport Abstraction

Goal: separate cluster protocol from file/local execution.

Deliverables:

- [x] Add `ClusterTransport` contract.
- [x] Add in-process transport.
- [x] Add loopback HTTP transport.
- [x] Add message serialization and compatibility tests.
- [x] Add timeout and retry policy.

Acceptance:

- [x] Cluster tests pass through both in-process and HTTP loopback transport.

## Milestone 35: Cluster Workflow Engine

Goal: run durable workflows as shard-owned cluster entities.

Deliverables:

- [x] Add workflow execution entity type.
- [x] Route workflow commands by execution id.
- [x] Store workflow journal through the cluster-owned entity.
- [x] Run timers, deferreds, queues, and signals through shard ownership.
- [x] Resume workflow execution after shard migration.

Acceptance:

- [x] Workflow started on runner A can resume and complete on runner B.

## Milestone 36: Distributed Timers And Wakeups

Goal: make timers safe when shards move.

Deliverables:

- [x] Store timer ownership by shard.
- [x] Rebuild wake-up indexes after shard acquisition.
- [x] Prevent duplicate timer firing with event idempotency.
- [x] Add late timer handling.
- [x] Add timer migration tests.

Acceptance:

- [x] Timer scheduled on one runner fires once after ownership moves.

## Milestone 37: Cluster Durable Queues

Goal: make durable queues work across runner boundaries.

Deliverables:

- [x] Shard queue ids.
- [x] Store queue claims durably.
- [x] Add claim lease expiration.
- [x] Route worker completions to owning shard.
- [x] Add concurrency limits per queue and per runner.

Acceptance:

- [x] Queue worker crash returns claimed work to the cluster.

## Milestone 38: Split-Brain And Lease Safety

Goal: make stale runners harmless.

Deliverables:

- [x] Add lease epoch to all shard-owned writes.
- [x] Reject writes from stale epochs.
- [x] Add fencing tokens to message and journal stores.
- [x] Add stale runner shutdown behavior.
- [x] Add diagnostics for lease conflicts.

Acceptance:

- [x] Tests prove stale runner writes cannot corrupt journal or mailbox state.

## Milestone 39: Cluster Supervision

Goal: make supervision work across entity and runner failures.

Deliverables:

- [x] Add shard supervisor.
- [x] Add entity supervisor.
- [x] Add workflow worker supervisor.
- [x] Add runner-level restart policy.
- [x] Add escalation to shard release when local recovery fails.

Acceptance:

- [x] Failures restart locally when possible and migrate when necessary.

## Milestone 40: Cluster Observability And Causal Queries

Goal: make cluster behavior inspectable with the same causal tools.

Deliverables:

- [x] Add runner, shard, message, lease, and entity causal events.
- [x] Add cluster query reports.
- [x] Add cluster DOT graph rendering.
- [x] Add metrics for leases, mailbox lag, retries, and migrations.
- [x] Add trace propagation across message sends.

Acceptance:

- [x] A cluster failure report identifies runner, shard, message, and cause.

## Milestone 41: Storage Adapter Hardening

Goal: make storage pluggable enough for real deployments.

Deliverables:

- [x] Add shared conformance suites for `JournalStore`, `RunnerStorage`, and
  `MessageStorage`.
- [x] Add file-backed conformance tests.
- [x] Add SQL-shaped storage contract.
- [x] Add Cockroach/PostgreSQL adapter plan; no in-repo Zig driver is selected
  for a live adapter in this milestone.
- [x] Add migration and schema management commands.

Acceptance:

- [x] All stores pass the same conformance suite.

## Milestone 42: Property, Fuzz, And Crash Testing

Goal: verify the system under generated histories and failure schedules.

Deliverables:

- [x] Add generated workflow histories.
- [x] Add generated message histories.
- [x] Add crash point injection.
- [x] Add replay equivalence checks.
- [x] Add scheduler fairness checks.

Acceptance:

- [x] Generated tests find no replay divergence across memory and file stores.

## Milestone 43: Performance And Bounded Resource Work

Goal: make the runtime viable for long histories and large mailboxes.

Deliverables:

- [x] Benchmark journal append and replay.
- [x] Benchmark mailbox dispatch.
- [x] Add bounded memory modes.
- [x] Add replay snapshot frequency tuning.
- [x] Add backpressure metrics.

Acceptance:

- [x] Benchmarks have stable local output and documented thresholds.

## Milestone 44: End-To-End Examples

Goal: provide runnable examples that explain the system better than prose.

Deliverables:

- [x] Add local approval workflow example.
- [x] Add durable queue worker example.
- [x] Add timer and signal workflow example.
- [x] Add local actor example.
- [x] Add multi-runner cluster example.
- [x] Add cluster workflow migration example.

Acceptance:

- [x] `zig build examples` compiles and runs all examples.

## Milestone 45: Public API Review And Stabilization

Goal: turn the experimental runtime into a coherent public package surface.

Deliverables:

- [x] Review public names.
- [x] Review ownership and allocator contracts.
- [x] Review error sets and diagnostics.
- [x] Review schema versioning guarantees.
- [x] Review docs for direct-style Zig clarity.
- [x] Add compatibility notes for future backend adapters.

Acceptance:

- [x] Public API review produces no unresolved naming or ownership issues.

## Milestone 46: Release Gate

Goal: finish the first release-quality durable workflow and local cluster
foundation with a reproducible check.

Deliverables:

- [x] Add one command that runs workflow and cluster conformance checks.
- [x] Add CI artifact paths for durable workflow and cluster reports.
- [x] Add README quickstart.
- [x] Add roadmap completion report.
- [x] Add migration notes from deterministic-only runtime to durable runtime.

Acceptance:

- [x] `bun run zigeffect:test` passes.
- [x] `bun run zig:test` passes.
- [x] `cd packages/zigeffect && zig build examples` passes.
- [x] Durable workflow crash recovery example passes.
- [x] Multi-runner cluster migration example passes.

## Milestone 47: Real Async IO Backend

Goal: replace cooperative/local-only execution limits with a real async IO
backend that can suspend, wake, interrupt, and run IO-bound fibers without
blocking the whole runtime.

Deliverables:

- [x] Select and document the production async backend strategy.
- [x] Add an async backend implementation for timers, network waits, file waits,
  and cancellation wakeups.
- [x] Integrate async backend execution with `Runtime`, `FiberRuntime`,
  `WorkflowEngine`, durable timers, durable queues, and cluster transports.
- [x] Add async-safe `Scope` finalization behavior.
- [x] Add interruption tests for suspended IO work.
- [x] Add compatibility tests proving deterministic backend semantics remain
  unchanged.

Acceptance:

- [x] A workflow can await real async IO, suspend, resume, and clean up on
  interruption.
- [x] Async execution does not duplicate completed durable activity results.
- [x] Deterministic and async backends both pass the shared backend conformance
  suite.

## Milestone 48: Production Shard Leasing

Goal: harden shard ownership from local proof into production-grade leases with
fencing, renewal, expiration, and recovery guarantees.

Deliverables:

- [x] Add lease epochs to all shard-owned journal, mailbox, queue, and timer
  writes.
- [x] Add storage-backed fencing tokens.
- [x] Add renewal jitter, renewal deadlines, and clock-skew tolerance rules.
- [x] Add stale owner detection and forced shard release.
- [x] Add lease audit reports.
- [x] Add crash tests for renewal loss, partial release, stale writes, and
  rapid reacquisition.

Acceptance:

- [x] Stale runners cannot write workflow journal, mailbox, queue, or timer
  state after lease loss.
- [x] Shards recover automatically after runner death without duplicate timer
  firing or lost mailbox messages.

## Milestone 49: Multi-Runner Transport

Goal: make runners communicate across real process and host boundaries through
a transport abstraction with backpressure, retries, and observability.

Deliverables:

- [x] Implement production HTTP transport.
- [x] Implement production socket transport if it fits the selected async
  backend.
- [x] Add transport-level authentication hooks.
- [x] Add envelope size limits and streaming or chunking for large replies.
- [x] Add connection lifecycle metrics and trace propagation.
- [x] Add transport backpressure and retry policies.
- [x] Add compatibility tests across in-process, loopback HTTP, and production
  transport modes.

Acceptance:

- [x] Multiple runners on separate processes can route entity messages,
  workflow commands, replies, interrupts, and queue completions reliably.
- [x] Transport failure produces retryable cluster errors and causal evidence
  without corrupting durable state.

## Milestone 50: Real Clustering

Goal: graduate the local multi-runner model into a real distributed cluster
runtime with membership, placement, rebalancing, and rolling recovery.

Deliverables:

- [x] Add cluster membership protocol.
- [x] Add runner discovery and admission.
- [x] Add shard placement strategy.
- [x] Add rebalancing planner.
- [x] Add rolling restart and graceful drain behavior.
- [x] Add node-down detection and recovery.
- [x] Add split-brain test scenarios.
- [x] Add cluster administration and inspection commands.

Acceptance:

- [x] A cluster can add a runner, rebalance shards, remove a runner, recover
  from runner death, and keep workflows and entity mailboxes correct.
- [x] Cluster inspection reports show membership, placement, leases, lag,
  rebalancing actions, and recent failures.

## Milestone 51: Full Supervision Trees

Goal: provide Erlang-style supervision as a complete runtime feature across
fibers, workflow workers, queue workers, entities, shards, runners, and cluster
services.

Deliverables:

- [x] Add typed child specs for fibers, activities, workflow workers, queue
  workers, entities, shard workers, transport servers, and runner services.
- [x] Implement permanent, transient, and temporary restart modes.
- [x] Implement one-for-one, one-for-all, rest-for-one, and dynamic supervisor
  strategies.
- [x] Add restart intensity windows and escalation.
- [x] Add supervisor state inspection.
- [x] Add distributed supervision behavior for shard release and runner drain.
- [x] Add causal events for supervisor decisions.

Acceptance:

- [x] Supervision handles local child failure, repeated failure escalation,
  shard worker failure, transport failure, and runner drain.
- [x] Supervisor reports explain restart decisions, escalation causes, affected
  children, and cleanup outcomes.

## Capability Matrix

| Capability | Milestones |
| --- | --- |
| Durable journal | 2, 3, 4, 5, 20, 21 |
| Durable core prerequisites | 0.5 |
| Workflow API | 6, 8, 9, 18 |
| Activities | 7, 10, 11, 12 |
| Durable waits | 13, 14, 15 |
| Durable queues | 16, 37 |
| Lifecycle control | 17 |
| Causal observability | 19, 40 |
| Async backend path | 22, 23, 47 |
| Supervision | 24, 39, 51 |
| Local actors | 25, 26, 27 |
| Runner and shard control | 28, 29, 30, 32, 33, 48 |
| Message storage | 31 |
| Cluster transport | 34, 49 |
| Cluster workflows | 35, 36 |
| Lease safety | 38 |
| Real clustering | 50 |
| Storage adapters | 41 |
| Hardening | 42, 43, 45, 46, 48, 49, 50, 51 |
| Examples | 44 |

## Always-On Verification

Use these commands as the common verification language:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
```

Additional milestone-specific tools should be added as they are created:

```bash
cd packages/zigeffect && zig build workflow-journal-inspect
cd packages/zigeffect && zig build workflow-replay
cd packages/zigeffect && zig build workflow-list
cd packages/zigeffect && zig build cluster-runner
cd packages/zigeffect && zig build cluster-inspect
```

## Completion Definition

This roadmap is complete when a workflow can start on one local runner, record
all durable decisions in an append-only journal, suspend on timers or external
events, survive process death, resume on a different runner after shard
rebalancing, complete exactly once from the user's perspective, run over a real
async IO backend, operate inside a real multi-runner cluster with production
shard leasing and transport, recover through full supervision trees, and produce
causal artifacts that explain every retry, migration, failure, restart,
transport error, lease transition, and cleanup.
