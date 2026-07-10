# zigeffect Local Agent Process Supervisor Design

## Goal

Own the lifecycle of one long-running local agent process and stream its
provider-neutral transcript turns plus terminal status into the live workbench.

## Decision

Add a fakeable process supervisor beside the existing local agent runtime and
transcript tail. The supervisor starts a configured command and, once the start
succeeds, immediately emits an `agent_status: running` event, tails stdout through
`runLocalAgentTranscriptTail`, drains stderr concurrently, waits for the child
to exit, and emits a terminal `check_result` followed by `agent_status: done` or
`agent_status: failed`.

The process contract exposes stdout, stderr, an exit promise, and a `kill`
operation. Production-local use is backed by `Bun.spawn`; tests provide
deterministic in-memory handles. An optional `AbortSignal` terminates the child
and records an interrupted failure instead of leaving an orphan process.

Lifecycle and transcript events share one monotonic sequence. The running event
uses the next sequence, the transcript tail starts after it, and terminal events
continue from the tail's last consumed line. Ignored transcript lines still
advance the sequence so line-derived turn identities remain stable.

Stderr is always drained concurrently to avoid child-process backpressure. Only
a bounded tail is retained for terminal diagnostics, and every diagnostic is
normalized through `postLocalAgentEvent` so secret-shaped values are redacted
before browser delivery.

## Failure Semantics

- A non-zero exit emits a failed check and failed agent status.
- A spawn/start exception emits a warning, failed check, and failed status.
- An abort requests child termination once, waits for process settlement, and
  emits an interrupted failed check and failed status.
- Collector posting failures reject the supervisor call because the workbench
  receipt can no longer honestly represent the process lifecycle.

## Non-Goals

- Do not emulate a PTY or interactive keyboard input in this milestone.
- Do not reverse-engineer private provider transcript storage.
- Do not persist full stderr or unredacted process output.
- Do not supervise multiple children or restart failed agents automatically.

## Acceptance Criteria

- Tests prove success events, parsed turns, and terminal events have monotonic
  sequence numbers.
- Tests prove non-zero exits and spawn exceptions produce honest failed state.
- Tests prove abort requests terminate the owned child and report interruption.
- Tests prove stderr is bounded and sentinel secrets never reach posted events.
- A real Bun subprocess smoke test streams a tagged assistant turn and exits.
