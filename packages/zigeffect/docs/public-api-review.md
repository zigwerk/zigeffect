# zigeffect Public API Review

Date: 2026-06-10

Milestone: 45 - Public API Review And Stabilization

## Result

The public package surface is stable enough for the durable workflow and local
cluster roadmap work completed so far. The preferred import remains:

```zig
const fx = @import("zigeffect");
```

The stable shape is namespace-first. Durable workflow APIs live under
`fx.workflow`, cluster APIs live under `fx.cluster`, storage metadata lives
under `fx.storage`, and deterministic performance reports live under
`fx.performance`. Top-level aliases remain curated compatibility conveniences
for core runtime types and the most commonly used cluster, storage, and
performance values.

The review found no open naming or ownership issues. The focused build gate is:

```bash
cd packages/zigeffect
zig build public-api-review
```

## Public Names

### Root Namespaces

The root facade exports these package domains:

| Namespace | Contract |
| --- | --- |
| `fx.core` | `Cause`, `Exit`, `Scope`, and typed execution context. |
| `fx.dependency` | service-set metadata, validation, and reports. |
| `fx.effect` | direct-style effect wrappers, resources, and schedules. |
| `fx.runtime` | runtime, fibers, coordination, backends, and supervision. |
| `fx.layer` | dependency layers and executable layer graphs. |
| `fx.services` | logger, config, clock, metrics, tracing, ids, and causal services. |
| `fx.testing` | deterministic `TestEnv` and assertion helpers. |
| `fx.traits` | codec, equality, hashing, ordering, show, and redaction contracts. |
| `fx.data` | option, either, duration, date-time, decimal, chunk, hash set, and redacted values. |
| `fx.match` | tagged-union matching. |
| `fx.pattern` | structural patterns, captures, and predicates. |
| `fx.workflow` | durable workflow definitions, journal, replay, engine, timers, signals, queues, scheduler, lifecycle, and inspection. |
| `fx.cluster` | actor identity, mailboxes, entities, storage, runners, shards, leases, fencing, supervision, transport, and cluster workflow routing. |
| `fx.storage` | schema catalog and SQL migration plans for durable adapters. |
| `fx.performance` | deterministic bounded-resource benchmark reports. |

### Workflow Namespace

The workflow namespace is the stable entry point for durable workflow code:

| Area | Stable names |
| --- | --- |
| Definitions | `Workflow`, `WorkflowMetadata`, `Activity`, `ActivityMetadata`. |
| Journal | `WorkflowEvent`, `WorkflowEventKind`, `WorkflowEventMigrationRegistry`, `JournalStore`, `JournalAppend`, `JournalEventBatch`, `InMemoryJournalStore`, `FileJournalStore`. |
| Replay | `WorkflowReplayState`, `WorkflowStatus`, `ReplayError`. |
| Engine | `WorkflowEngine`, `WorkflowExecution`, `WorkflowResult`, `WorkflowBackendRequirement`. |
| Context | `WorkflowContext`, `WorkflowContextOptions`, `WorkflowContextError`. |
| Durable primitives | `DurableClock`, `DurableDeferred`, `DurableSignal`, `DurableQueue`. |
| Scheduling | `WorkflowScheduler`, `WorkflowSchedulerTickResult`, `WorkflowLifecycle`. |
| Inspection | `WorkflowInspectionReport`, list, replay, inspect, text, and JSON formatters. |
| Ownership helpers | `cloneWorkflowEvent`, `deinitWorkflowEventStrings`. |

Workflow code should prefer `fx.workflow.*` names over root aliases. Root
aliases are deliberately not expanded for every workflow symbol; the namespace
keeps the durable API readable and avoids crowding the root facade.

### Cluster Namespace

The cluster namespace is the stable entry point for Erlang-style local actor and
runner work:

| Area | Stable names |
| --- | --- |
| Identity | `EntityType`, `EntityId`, `EntityAddress`, `entityId`, `entityAddress`. |
| Local actors | `LocalMailboxStore`, `EntityEnvelope`, `EntityAsk`, `LocalEntityRuntime`, `EntityScope`, `EntityHandlerResult`. |
| Messages | `MessageEnvelope`, `MessageStorage`, `InMemoryMessageStorage`, `FileMessageStorage`, `MessageDeliveryTracker`. |
| Runners | `RunnerRegistration`, `RunnerHeartbeat`, `LocalRunnerRegistry`, `LocalRunnerHealthInspector`. |
| Runner storage | `RunnerStorage`, `InMemoryRunnerStorage`, `FileRunnerStorage`, `ShardLease`. |
| Shards and leases | `ShardRoutingTable`, `LocalShardLeaseManager`, `ShardLeaseFence`, `validateShardFence`. |
| Supervision | `ClusterSupervisionPolicy`, `ClusterRunnerRestartPolicy`, `ClusterSupervisionReport`. |
| Runtime | `ClusterRuntime`, `ClusterEntityRef`, `ClusterProcessReport`, `ClusterShutdownReport`. |
| Transport | `ClusterTransport`, `InProcessClusterTransport`, `LoopbackHttpClusterTransport`, transport request and response formatters. |
| Cluster workflows | `ClusterWorkflowEngine`, `ClusterWorkflowEntityRegistry`, command/result schemas and formatters. |
| Distributed indexes | `ClusterTimerWakeupIndex`, `ClusterQueueIndex`. |
| Local multi-runner helpers | `LocalClusterRouter`, `LocalClusterRunner`, `balancedShardPlan`, `planDeadRunnerShardRecovery`. |
| Ownership helpers | `cloneEntityAddress`, `deinitEntityAddress`, `cloneEntityEnvelope`, `deinitEntityEnvelope`, `cloneMessageEnvelope`, `deinitMessageEnvelope`. |

Root aliases exist for the most common cluster values so examples can stay
compact. New public cluster names should be introduced through `fx.cluster`
first, then promoted to the root facade only when repeated user code benefits
from the shorter form.

## Ownership And Allocators

Allocator arguments are borrowed from the caller. Passing an allocator to a
function does not transfer ownership of the allocator itself.

Caller-owned return values follow one of two patterns:

- a struct stores `allocator` and exposes `deinit`, such as
  `JournalEventBatch`, `MessageRecordBatch`, `RunnerLeaseBatch`,
  `WorkflowExecutionList`, `PerformanceBenchmarkReport`, and cluster route or
  ask reports;
- a function returns allocated bytes, and the function name or surrounding doc
  follows the standard Zig convention that the caller frees the returned slice.

Borrowed values follow these rules:

- schema names and domain names are static strings;
- `@typeName`-derived service and payload names are static strings;
- payload slices passed to append, submit, offer, or signal APIs are borrowed
  for the call and cloned before durable storage keeps them;
- handlers may return borrowed reply payloads, and runtime/storage code clones
  when a value crosses a durable boundary.

Store read and claim methods return caller-owned values. Release nested strings
with the matching helper or batch `deinit`:

```zig
var events = try journal.readAll(allocator);
defer events.deinit();

const owned = try fx.workflow.cloneWorkflowEvent(allocator, event);
defer fx.workflow.deinitWorkflowEventStrings(allocator, owned);
```

Cluster ownership mirrors workflow ownership:

```zig
const owned = try fx.cluster.cloneMessageEnvelope(allocator, envelope);
defer fx.cluster.deinitMessageEnvelope(allocator, owned);
```

`Context.allocator` is per-run scratch space owned by the context creator.
Graph startup resources belong to the graph startup scope. Fiber resources
belong to the child fiber scope. Shared runtime scopes are explicit caller-owned
lifecycles. See [Resource Ownership](resource-ownership.md) for the broader
scope model.

## Error Sets And Diagnostics

Public domain errors are concrete where the package can name the cases:

| Domain | Error sets |
| --- | --- |
| Core/runtime | `ScopeError`, `FinalizerRegistrationError`, `FiberPrimitiveError`, `SupervisorError`, `BackendCapabilityError`. |
| Dependency | `DependencyError` plus dependency reports. |
| Workflow | `WorkflowDefinitionError`, `ActivityDefinitionError`, `WorkflowEventParseError`, `ReplayError`, `JournalStoreError`, `FileJournalStoreError`, `WorkflowEngineError`, `WorkflowContextError`, `WorkflowReportError`. |
| Cluster | `EntityMailboxError`, `EntityRuntimeError`, `MessageDeliveryError`, `MessageStorageError`, `ShardRoutingError`, `RunnerRegistryError`, `RunnerStorageError`, `ShardLeaseManagerError`, `FenceValidationError`, `ClusterRuntimeError`, `ClusterTransportError`, `ClusterWorkflowCommandError`, `LocalClusterError`. |
| Storage/performance | schema compatibility reports and benchmark threshold violation kinds. |

Type-erased storage and transport vtables may return `anyerror` at the adapter
boundary. This is intentional for adapter composition: file-backed stores,
in-memory stores, and external backends can expose backend-specific failures
through the vtable while concrete leaf methods keep narrower error unions.

Compile-time diagnostics remain part of the public experience. The package
keeps rich compile-fail messages for missing services, invalid service tuples,
environment mismatches, malformed workflow/activity idempotency callbacks, and
pattern matching errors. Runtime diagnostics remain text-first through
functions such as `formatExit`, `formatCause`, `formatDependencyReport`,
`formatBackendCapabilityDiagnostic`, `formatMessageDiagnostic`, and
`formatClusterFailureReport`.

Structured JSON output is available for durable and tool-facing records:
storage catalogs, SQL migration plans, workflow reports, workflow and cluster
causal reports, cluster transport requests and responses, cluster workflow
commands and results, performance benchmark reports, and causal artifacts. New
structured diagnostics should add new functions instead of changing existing
text output.

## Schema Versioning

Schema names are immutable identifiers. Version constants describe the format
emitted by this package version. Breaking record changes require a version bump
and explicit migration or compatibility handling.

Current durable schemas are version `1`:

| Schema | Version |
| --- | --- |
| `zigeffect.workflow.journal-event.v1` | `1` |
| `zigeffect.workflow.checkpoint.v1` | `1` |
| `zigeffect.workflow.snapshot-commit.v1` | `1` |
| `zigeffect.workflow.inspect.v1` | `1` |
| `zigeffect.workflow.replay.v1` | `1` |
| `zigeffect.workflow.list.v1` | `1` |
| `zigeffect.cluster.runner-lease.v1` | `1` |
| `zigeffect.cluster.message-record.v1` | `1` |
| `zigeffect.cluster.message-reply.v1` | `1` |
| `zigeffect.cluster.transport.request.v1` | `1` |
| `zigeffect.cluster.transport.response.v1` | `1` |
| `zigeffect.cluster.workflow-command.v1` | `1` |
| `zigeffect.cluster.workflow-command-result.v1` | `1` |
| `zigeffect.storage.catalog.v1` | `1` |
| `zigeffect.storage.sql-plan.v1` | `1` |
| `zigeffect.performance.benchmark.v1` | `1` |

Compatible additions should preserve existing fields and parsers. Older or
newer records are classified through storage and workflow compatibility helpers
before they are replayed or migrated. Unknown durable records should fail with
typed parse or compatibility errors rather than being silently accepted.

## Direct-Style Zig Clarity

The public API stays Zig-first. Workflow and actor handlers are plain Zig
functions with explicit allocators, error sets, and cleanup. `Effect` is for
composition, retry, resource scoping, dependency requirements, and runtime
integration; it is not a required wrapper for every function.

Preferred style:

- use plain functions at the workflow, activity, actor, and service boundary;
- wrap functions in `Effect` when composition or runtime scopes matter;
- use `defer` for lexical cleanup and `Scope` finalizers for runtime-owned
  cleanup;
- keep durable payload serialization behind `Codec` values;
- prefer `fx.workflow.*` and `fx.cluster.*` names in durable code so ownership
  and schema context stay visible.

## Backend Compatibility

Backend expansion should add capability checks and adapters without changing
the direct-style source model.

| Backend area | Public compatibility rule |
| --- | --- |
| Real async IO | Direct-style functions remain the user-facing shape. Async backends add suspend, wake, timer, and interrupt capabilities behind runtime/backend contracts. |
| Real clustering | Cluster APIs keep entity identity, shard ids, message storage, runner storage, leases, fencing, and transport schemas stable. |
| Shard leasing | Lease ownership remains fenced by runner identity, lease epoch, and shard id. Stale fences fail through typed errors and diagnostics. |
| Multi-runner transport | Transports preserve request/response schemas, idempotency keys, retry policy, and owned response envelopes. |
| Full supervision trees | Supervision keeps restart policies, shutdown ordering, and `Cause` evidence stable while backend implementations become more capable. |

Capability diagnostics should fail early when a deterministic backend is asked
to perform a durable, async, distributed, or supervised operation that needs a
more capable backend. Existing direct-style programs that only require
deterministic capabilities should continue to run on more capable backends.

## Review Closeout

| Area | Resolution |
| --- | --- |
| Public names | Namespace-first contract approved. Root aliases remain curated compatibility conveniences. |
| Ownership | Allocator and owned-return conventions documented. Clone/deinit helpers are locked by `public-api-review`. |
| Error sets | Concrete domain errors documented. Type-erased adapter `anyerror` boundary accepted for backend composition. |
| Diagnostics | Text diagnostics remain stable. Structured output grows through additive formatters. |
| Schema versioning | Durable v1 schemas locked by the focused test gate. Breaking changes require migration or compatibility handling. |
| Direct-style clarity | Plain Zig functions remain the center of workflow and actor programming. |
| Backend adapters | Real async IO, real clustering, shard leasing, multi-runner transport, and supervision tree expansion have compatibility rules. |

No naming or ownership issue remains open for Milestone 45.
