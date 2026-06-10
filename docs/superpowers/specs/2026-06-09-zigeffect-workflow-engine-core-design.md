# zigeffect WorkflowEngine Core Design

Date: 2026-06-09

## Purpose

Milestone 8 adds the first workflow engine surface: registration, durable
execution start, polling, inspection, listing, duplicate execution behavior,
and provider requirement validation. It does not execute workflow bodies yet.

## Design

Add `packages/zigeffect/src/workflow/engine.zig` and expose it through
`fx.workflow`.

The engine owns:

- `WorkflowEngine`;
- `WorkflowExecution`;
- `WorkflowExecutionList`;
- `WorkflowExecutionStatus`;
- `WorkflowEngineError`;
- `WorkflowResult(Success, Failure)`.

`WorkflowEngine` is initialized with a `JournalStore` and an optional static
provider service tuple. Registration validates a workflow definition's
requirements against the provider service set. Execution derives ids from the
workflow definition's idempotency key callback, appends `workflow_started`, and
records a running execution in memory for poll/inspect/list.

## APIs

- `init(allocator, journal_store)`;
- `initWithProviders(allocator, journal_store, .{ Services })`;
- `register(WorkflowType)`;
- `execute(WorkflowType, payload)`;
- `poll(WorkflowType, execution_id)`;
- `inspect(execution_id)`;
- `list(allocator)`;
- `deinit()`.

`WorkflowResult(Success, Failure)` is a typed union with:

- `running`;
- `completed`;
- `failed`;
- `not_found`.

Only `running` and `not_found` are produced in this milestone.

## Journal Semantics

`execute` appends one `workflow_started` event with:

- monotonic journal sequence;
- deterministic workflow id derived from workflow name;
- deterministic execution id from workflow payload idempotency key;
- workflow name;
- `running` status;
- idempotency key.

Duplicate execution ids return `DuplicateWorkflowExecution` before appending.

## Non-Goals

- No workflow body execution.
- No step runner.
- No activity scheduling.
- No completion/failure writing.
- No durable engine recovery.
- No multi-workflow journal partitioning.

## Acceptance

- Tests register and execute a no-op workflow definition.
- Tests poll the started execution as `running`.
- Tests inspect and list executions.
- Tests prove `workflow_started` is appended.
- Tests prove duplicate execution id behavior is explicit.
- Tests prove missing provider requirements fail registration.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 8 is marked complete in the roadmap.
