# zigeffect Activity Scheduling And Completion Design

Date: 2026-06-09

## Purpose

Milestone 10 adds durable activity calls to `WorkflowContext`. A workflow can
schedule a side-effecting activity, journal its start and terminal outcome, and
replay a completed or failed activity from the journal without invoking the
activity function again.

## Design

Use the existing `Activity` definition API as the type-level contract:

- `ActivityType.name` identifies the activity family.
- `ActivityType.PayloadType` is passed to the activity function.
- `ActivityType.SuccessType` is decoded from completed journal payloads.
- `ActivityType.FailureType` must be an error set for this milestone, so a
  recorded `Exit.cause.failure:<error-name>` can be returned as a typed error.
- `ActivityType.idempotencyKey(allocator, payload)` determines the logical
  activity id.

Add first-class attempt counters to the workflow journal:

- `WorkflowEvent.attempt: u32 = 0`.
- `ActivityState.attempt: u32 = 0`.
- workflow event JSON, text formatting, parsing, replay state, and checkpoint
  JSON preserve the attempt number.

Add this workflow-context API:

```zig
try context.activity(ChargeCard, payload, u64_codec, ChargeRunner.run);
```

`context.activity` is generic over the activity definition. The result codec is
the durable serialization boundary for successful activity results. Failure
payloads use the same `Exit` and `Cause` vocabulary introduced for step
failures.

## Execution Semantics

On `activity(ActivityType, payload, result_codec, run_fn)`:

- compute the activity id from `ActivityType.name` and the activity
  idempotency key;
- if replay history contains `activity_completed` for that activity id, decode
  `redacted_detail` with `result_codec` and return it without calling
  `run_fn`;
- if replay history contains `activity_failed` with
  `Exit.cause.failure:<error-name>`, convert the error name into
  `ActivityType.FailureType` and return it without calling `run_fn`;
- otherwise append `activity_scheduled` and `activity_started` with attempt `1`;
- call `run_fn(payload)`;
- on success, encode the result with `result_codec`, append
  `activity_completed`, and return the result;
- on failure, append `activity_failed` with
  `Exit.cause.failure:<error-name>` and return the typed error.

Lifecycle journal rows use per-row idempotency keys derived from activity id,
event kind, and attempt. The logical replay identity remains the activity id.

## Non-Goals

- No retry scheduling or retry delay calculation.
- No activity worker polling loop.
- No timeout handling.
- No compensation.
- No distributed activity execution.

## Acceptance

- Journal JSON/text parsing and formatting preserve `attempt`.
- Replay state and checkpoint JSON preserve activity attempts.
- Activity success records scheduled, started, and completed rows.
- Replaying a completed activity returns the decoded result without re-running
  the activity function.
- Activity failure records a typed `Exit.cause.failure` detail.
- Replaying a failed activity returns the typed error without re-running the
  activity function.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 10 is marked complete in the roadmap.
