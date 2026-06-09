# zigeffect Activity Definition API Design

Date: 2026-06-09

## Purpose

Milestone 7 defines typed activity metadata without executing activities.
Activities are the future side-effect boundary for durable workflows; this
milestone only makes that boundary declarable and inspectable.

## Design

Add `packages/zigeffect/src/workflow/activity.zig` and expose it through
`fx.workflow`.

The primary API is:

```zig
const ChargeCard = fx.workflow
    .Activity("charge-card", ChargePayload, ChargeSuccess, ChargeError, Env)
    .withIdempotencyKey(chargeKey)
    .withRetrySchedule(fx.Schedule.exponential(.{ ... }).withLabel("charge-retry"))
    .withTimeoutMs(30_000)
    .withCompensation("refund-charge")
    .requires(.{ fx.Logger, PaymentGateway });
```

`Activity(Name, Payload, Success, Failure, Env)` returns a definition type.
Refinement methods return new definition types:

- `.withIdempotencyKey(callback)`;
- `.withRetrySchedule(schedule)`;
- `.withTimeoutMs(timeout_ms)`;
- `.withCompensation(name)`;
- `.requires(.{ ServiceA, ServiceB })`.

No activity execution function is accepted in this milestone.

## Idempotency Callback

The callback shape is:

```zig
fn (std.mem.Allocator, Payload) anyerror![]const u8
```

The returned key is caller-owned. Invalid shapes fail with a message beginning:

```text
zigeffect invalid activity idempotency key callback
```

## Metadata

`ActivityMetadata` includes:

- name;
- payload type name;
- success type name;
- failure type name;
- environment type name;
- requirement count;
- whether an idempotency key callback is installed;
- whether a retry schedule is installed;
- retry schedule label;
- timeout milliseconds;
- compensation name.

The definition exposes:

- `metadata()`;
- `requiredServices(allocator)`;
- `idempotencyKey(allocator, payload)`;
- `retrySchedule()`;
- `format(allocator)`.

## Non-Goals

- No activity execution function.
- No activity runner.
- No journal writes.
- No retry calculation beyond storing an existing `Schedule`.
- No compensation execution.
- No payload codecs.

## Acceptance

- Tests cover valid definitions, formatting, metadata, requirements,
  idempotency keys, retry schedule metadata, timeout metadata, and compensation
  metadata.
- Compile-fail tests cover invalid idempotency callback shape.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 7 is marked complete in the roadmap.
