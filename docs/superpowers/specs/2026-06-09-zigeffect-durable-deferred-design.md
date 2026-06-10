# zigeffect Durable Deferred Design

Date: 2026-06-09

## Purpose

Milestone 13 adds durable deferred values. A workflow can await a value that is
completed externally, suspend durably while the value is missing, and replay the
completed value without re-suspending after the external completion row is in
the journal.

## Design

The journal already has deferred lifecycle events:

- `deferred_created`;
- `deferred_awaited`;
- `deferred_completed`;
- `deferred_failed`;
- `deferred_cancelled`.

Add durable deferred identity:

- `deferredId(label)` derived with FNV-1a over the label.

Add `workflow/deferred.zig`:

- `DeferredAwaitResult(Success, Failure)`;
- `DurableDeferred`;
- external APIs `complete`, `fail`, and `cancel`.

Add `WorkflowContext.awaitDeferred`:

```zig
const result = try context.awaitDeferred(
    "approval",
    u64_codec,
    error{Rejected},
);
```

The return type is:

```zig
union(enum) {
    completed: Success,
    failed: Failure,
    cancelled: []const u8,
    suspended: Suspension,
}
```

Success values use `Codec(Success)`. Failed deferred values use
`Exit.cause.failure:<error-name>` details and error-set parsing.

## Execution Semantics

`WorkflowContext.awaitDeferred(label, success_codec, FailureType)`:

- computes `deferredId(label)`;
- if a completed row exists, decodes and returns `.completed`;
- if a failed row exists, parses and returns `.failed`;
- if a cancelled row exists, returns `.cancelled`;
- otherwise appends `deferred_created` when absent, appends
  `deferred_awaited`, appends `workflow_suspended` with `status = "waiting"`,
  and returns `.suspended` with `SuspensionKind.deferred`.

`DurableDeferred.complete(label, codec, value)` appends
`deferred_completed` with encoded value. `fail(label, err)` appends
`deferred_failed` with `Exit.cause.failure:<error-name>`. `cancel(label,
reason)` appends `deferred_cancelled` with the reason as redacted detail.

External appends are idempotent by deferred id and terminal event kind: if a
terminal row already exists, the helper returns without appending a duplicate.

## Non-Goals

- No distributed notification channel.
- No scheduler loop.
- No durable timer integration.
- No worker polling API.

## Acceptance

- Awaiting a missing deferred appends create, await, and workflow suspension
  rows.
- External completion resumes replay as a decoded completed value.
- External failure replays as a typed failed result.
- External cancellation replays as a cancelled result.
- Repeated external completion does not append duplicate terminal rows.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 13 is marked complete in the roadmap.
