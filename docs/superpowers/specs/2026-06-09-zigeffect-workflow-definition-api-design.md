# zigeffect Workflow Definition API Design

Date: 2026-06-09

## Purpose

Milestone 6 defines typed workflow metadata without executing workflows. It
creates the compile-time surface later workflow-engine milestones will register
and run.

## Design

Add `packages/zigeffect/src/workflow/definition.zig` and expose it through
`fx.workflow`.

The primary API is:

```zig
const Approval = fx.workflow
    .Workflow("approval", ApprovalPayload, ApprovalSuccess, ApprovalError, Env)
    .withIdempotencyKey(approvalKey)
    .requires(.{ fx.Logger, fx.Config });
```

`Workflow(Name, Payload, Success, Failure, Env)` returns a definition type.
Refinement methods return new definition types:

- `.withIdempotencyKey(callback)`;
- `.requires(.{ ServiceA, ServiceB })`.

No workflow body or execution function is accepted in this milestone.

## Idempotency Callback

The callback shape is:

```zig
fn (std.mem.Allocator, Payload) anyerror![]const u8
```

The returned key is caller-owned. The definition exposes:

- `idempotencyKey(allocator, payload)`;
- `deriveExecutionId(allocator, payload)`.

Execution ids are deterministic `u64` values derived by FNV-1a over
`workflow-name ":" idempotency-key`.

## Metadata

`WorkflowMetadata` includes:

- name;
- payload type name;
- success type name;
- failure type name;
- environment type name;
- requirement count;
- whether an idempotency key callback is installed.

The definition type exposes:

- `name`;
- `PayloadType`;
- `SuccessType`;
- `FailureType`;
- `EnvType`;
- `RequiredServices`;
- `metadata()`;
- `requiredServices(allocator)`.

## Compile Diagnostics

Invalid callback shapes fail with a message beginning:

```text
zigeffect invalid workflow idempotency key callback
```

Invalid requirement declarations reuse the existing service tuple diagnostics.

## Non-Goals

- No workflow body.
- No workflow registration.
- No journal writes.
- No workflow engine.
- No activity definitions.
- No payload codecs.

## Acceptance

- Tests cover valid definitions, metadata, requirement declarations,
  idempotency key generation, and execution id stability.
- Compile-fail tests cover invalid callback shape.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 6 is marked complete in the roadmap.
