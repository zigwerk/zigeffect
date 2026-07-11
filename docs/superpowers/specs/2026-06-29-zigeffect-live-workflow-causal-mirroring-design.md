# zigeffect Live Workflow Causal Mirroring Design

## Goal

Make durable workflow execution correctly feed the agentic causal system while preserving the journal as the source of truth.

## Decision

When a workflow path is given a `CausalStore`, every successful workflow journal append is mirrored into that store as a `workflow_event_recorded` causal event. This is opt-in by attachment, not global telemetry: callers that do not attach a causal store keep the current journal-only behavior.

## Architecture

Add a `CausalJournalStore` decorator in `workflow/store.zig`. It wraps an existing `JournalStore`, delegates reads/state/reset unchanged, and on successful `append` maps the appended `WorkflowEvent` through `workflow/causal.zig` before recording it in the attached `CausalStore`. The decorator also tracks workflow journal sequence to causal event id mappings, so `parent_sequence` becomes a real causal `parent_id` even when the target `CausalStore` already contains earlier runtime events.

`WorkflowContext.init` wraps its journal store when `WorkflowContextOptions.causal_store` is present, so steps, activities, durable timers, durable deferreds, durable signals, and durable queues all emit live workflow causal events through their existing append paths.

`ClusterWorkflowEntityServices` carries an optional causal store/run id. `ClusterWorkflowEntityHandler` wraps the shard-guarded journal store after lease validation, so cluster-owned workflow command handling emits the same live workflow causal events while keeping the lease fence as the journal write authority.

## Data Flow

1. Caller attaches a `CausalStore` to `WorkflowContext` or cluster workflow entity services.
2. Workflow code appends to the durable journal through the decorated `JournalStore`.
3. The inner journal append succeeds or fails.
4. Only on success, the decorator maps `parent_sequence` through its sequence map, then records the workflow causal event.
5. The decorator records the returned causal event id for the appended workflow sequence.
6. Duplicate journal appends that are rejected by the journal do not record duplicate causal events.

## Error Handling

Causal mirroring is best-effort after a successful durable append. If the causal record fails, the append result still succeeds. This keeps workflow durability stronger than observability and avoids turning an agent-observability failure into a duplicate or inconsistent workflow execution.

## Testing

Add tests that prove:

- `WorkflowContext` records live `workflow_event_recorded` events for workflow appends when a causal store is attached.
- Duplicate workflow appends do not produce duplicate live causal events.
- Parent workflow sequences are mapped to actual causal event ids when the causal store already has earlier events.
- Cluster workflow commands can attach a causal store to entity services and record workflow journal events live.
