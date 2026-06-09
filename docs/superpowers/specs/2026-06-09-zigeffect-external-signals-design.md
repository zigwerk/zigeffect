# zigeffect External Signals Design

Date: 2026-06-09

## Purpose

Milestone 15 adds durable external signals for human-in-the-loop and webhook
workflows. A workflow can wait for a named signal, suspend durably, receive the
signal after a restart, resume, consume the received payload exactly once, and
continue without duplicating journal rows.

## Design

Add `workflow/signal.zig`:

- `signalId(name)` for stable suspension identity;
- `Signal(name, Payload)` for named typed signal definitions;
- `SignalMetadata`;
- `SignalWaitResult(Payload)`;
- `DurableSignal` for external append APIs.

Signal payloads use the existing `Codec(Payload)` boundary. `signal_received`
stores the encoded payload in `redacted_detail`. `signal_consumed` records the
consumed received event sequence in this form:

```text
received_sequence=<sequence>
```

External append callers must provide an idempotency key. The journal row uses a
derived key:

```text
signal:<name>:received:<external-key>
```

Calling the append API with the same external key returns `false` instead of
adding another event. A successful append wakes a suspended workflow execution
by appending a correlated `workflow_resumed` row.

`WorkflowContext.waitForSignal(SignalType, codec)` reads the current journal:

- if a prior `signal_consumed` row exists, it replays the consumed received
  payload;
- if an unconsumed `signal_received` row exists, it appends `signal_consumed`
  and returns `.received`;
- if no signal is present, it appends `workflow_suspended` once and returns
  `.suspended` with `SuspensionKind.signal`.

Timeouts use durable timers. `Signal(...).withTimeoutMs(ms)` causes
`waitForSignal` to schedule a timer named `signal:<name>:timeout`. When that
timer fires, `waitForSignal` appends a `signal_consumed` row with status
`timed_out` and returns `.timed_out`. If a signal arrives first, the timeout
timer is cancelled so the local clock cannot fire a stale timeout later.

## Acceptance

- Signal definitions expose stable names, payload type metadata, timeout
  metadata, and stable signal ids.
- Waiting on a missing signal appends one durable suspension row and replays
  before receipt without duplicates.
- External signal append records `signal_received`, honors idempotency keys,
  and wakes suspended workflows with `workflow_resumed`.
- Waiting after receipt appends `signal_consumed`, decodes the payload, and
  replays the consumed payload without duplicate consumption.
- Timed waits schedule durable timers, return `.timed_out` after the timer
  fires, and cancel the timeout if the signal arrives first.
- The same append/wait flow works after `FileJournalStore` reopen.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 15 is marked complete in the roadmap.
