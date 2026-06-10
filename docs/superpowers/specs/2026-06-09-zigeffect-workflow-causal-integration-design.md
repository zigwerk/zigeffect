# zigeffect Workflow Causal Integration Design

Date: 2026-06-09

## Purpose

Milestone 19 connects durable workflow execution to the existing causal runtime
so agents can ask why a workflow failed, retried, suspended, resumed, or
recovered after a crash. The integration must reuse `CausalStore`, causal JSON,
causal DOT, and causal query tooling rather than creating a parallel
observability stack.

## Design

Add `workflow/causal.zig` as the workflow-to-causal adapter. It maps
append-only workflow journal events into causal events and builds causal stores,
reports, and DOT graphs from workflow histories.

Add one causal event kind:

```zig
workflow_event_recorded
```

This event kind is structural and finding evidence. It is not sampleable because
workflow journal rows are already durable, bounded by journal storage, and
semantically important.

Workflow event causal IDs are deterministic:

- `run_id` is `workflow_id`;
- `scope_id` is `execution_id`;
- `fiber_id` is `activity_id` when present, otherwise `queue_id`, otherwise
  `timer_id`, otherwise `deferred_id`, otherwise null;
- `trace_id` is `workflow_id`;
- `span_id` is the workflow journal `sequence`;
- `parent_id` is the workflow journal `parent_sequence`.

Workflow event labels use `event.name` when present and fall back to the
workflow event kind name. `type_name` is `workflow.<kind>`. `status` is the
event status when present and otherwise a deterministic status derived from the
kind. `redacted_detail` preserves the journal row detail and appends target ids
only when useful for causal queries.

Existing schedule-decision recording in `WorkflowContext` remains valid. The
new adapter covers persisted journal histories, including histories replayed
from `FileJournalStore`.

## Queries

Extend `causal-query` with workflow-aware filters:

- `workflow <run_id>` returns causal events whose `run_id` matches and whose
  kind is `workflow_event_recorded`.
- `workflow-findings <run_id>` returns workflow failure, retry exhaustion,
  suspend, and resume evidence for that run.

The existing `retries <run_id>` query continues to show `schedule_decision`
events, including workflow retry decisions recorded by `WorkflowContext`.

## DOT

Add `formatWorkflowCausalDot(allocator, events)` in `workflow/causal.zig`. It
builds a temporary `CausalStore` from mapped workflow events and calls the
existing causal DOT renderer. Workflow DOT therefore uses the same styling,
node labels, tooltips, and parent edges as all other causal graphs.

## Dogfood

Add a deterministic workflow crash-recovery dogfood scenario to the causal
artifact harness. The scenario records:

- workflow start;
- activity retry scheduling;
- suspend on durable timer or signal wait;
- resume after external wake-up;
- terminal failure detail.

The dogfood report, JSON, and DOT artifacts must explain failure, retry,
suspend, and resume from the same causal artifact set used by existing causal
tools.

## Acceptance

- Workflow journal events map to causal events with deterministic run, scope,
  fiber, trace, span, and parent links.
- Causal reports include workflow failure, retry, suspend, and resume evidence.
- `causal-query workflow <run_id>` returns workflow causal events.
- `causal-query workflow-findings <run_id>` returns durable workflow findings.
- Workflow history DOT renders with existing causal DOT infrastructure.
- The causal dogfood harness emits workflow crash-recovery artifacts.
- Milestone 19 is marked complete after the full gate passes.
