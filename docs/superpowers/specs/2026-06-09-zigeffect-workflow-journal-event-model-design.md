# zigeffect Workflow Journal Event Model Design

Date: 2026-06-09

## Purpose

Milestone 2 defines the first durable workflow journal vocabulary. It adds
typed ids, event kinds, a stable event envelope, schema constants, and
human/JSON formatters. It does not add a journal store, replay fold, workflow
engine, activity runner, timers, deferreds, queues, or signals.

## Design

Add `packages/zigeffect/src/workflow/journal.zig` and expose it through
`fx.workflow`.

The journal module owns:

- `workflow_journal_event_schema = "zigeffect.workflow.journal-event.v1"`;
- `workflow_journal_event_schema_version = 1`;
- id aliases: `WorkflowId`, `ExecutionId`, `ActivityId`, `TimerId`,
  `DeferredId`, `QueueId`, `JournalSequence`;
- `WorkflowEventKind`;
- `workflowEventKindName(kind)`;
- `WorkflowEvent`;
- `formatWorkflowEventJson(allocator, event)`;
- `formatWorkflowEventText(allocator, event)`.

`WorkflowEvent` is a stable envelope with required workflow/execution ids and
optional target ids. This keeps the event model simple until replay and stores
need stronger constructors.

## Event Envelope Fields

Every formatted event includes:

- `schema`;
- `schema_version`;
- `sequence`;
- `kind`;
- `workflow_id`;
- `execution_id`;
- `parent_sequence`;
- `activity_id`;
- `timer_id`;
- `deferred_id`;
- `queue_id`;
- `name`;
- `status`;
- `redacted_detail`.

`redacted_detail` is the only detail field in this milestone. Callers must pass
already-redacted durable details. Workflow-specific redaction policies can layer
on top of this envelope when activity payload codecs and journal stores land.

## Event Kinds

The first taxonomy covers:

- workflow lifecycle: `workflow_started`, `workflow_suspended`,
  `workflow_resumed`, `workflow_completed`, `workflow_failed`,
  `workflow_interrupted`, `workflow_cancelled`;
- activities: `activity_scheduled`, `activity_started`,
  `activity_completed`, `activity_failed`;
- timers: `timer_scheduled`, `timer_fired`, `timer_cancelled`;
- durable deferreds: `deferred_created`, `deferred_awaited`,
  `deferred_completed`, `deferred_failed`, `deferred_cancelled`;
- durable queues: `queue_offered`, `queue_claimed`, `queue_completed`,
  `queue_failed`, `queue_acked`;
- signals: `signal_received`, `signal_consumed`.

## Formatting

JSON formatting should emit a single event object with schema metadata. Optional
ids are emitted as `null`. Text formatting should emit a readable report for
CLI tools and agent diagnostics.

The formatter is intentionally one-way for this milestone. Parsing belongs to
the replay-state and journal-store milestones.

## Public Surface

Expose through `fx.workflow`:

- all id aliases;
- schema constants;
- `WorkflowEventKind`;
- `WorkflowEvent`;
- `workflowEventKindName`;
- `formatWorkflowEventJson`;
- `formatWorkflowEventText`.

No root aliases are added.

## Testing

Add `packages/zigeffect/test/workflow_test.zig` and import it from
`test/all_test.zig`.

Tests cover:

- every event kind has a stable string name;
- JSON formatting includes schema, schema version, ids, kind, name, status,
  and redacted detail;
- optional ids format as either numbers or `null`;
- text formatting names the same event facts;
- architecture tests prove the workflow namespace exposes the journal module.

## Non-Goals

- No journal store.
- No replay state.
- No parser.
- No workflow definition API.
- No activity runner.
- No durable timer/deferred/queue behavior.

## Acceptance

- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 2 is marked complete in the durable workflows/clustering roadmap.
