# zigeffect-std Local Agent Supervisor Design

Date: 2026-06-26

Status: delivered on 2026-06-26.

## Decision

Add M14 as a local agent supervisor in `zstd.Agent`.

M13 proved the standard library can build local tools. M14 turns the agent
toolkit into a production-shaped local runner that can execute Codex,
Claude Code, or arbitrary local process adapters; capture stdout/stderr as
redacted artifacts; enforce simple guardrails; and emit workbench-compatible
JSONL.

## Goals

- Add a reusable `zstd.Agent` supervisor API.
- Support multiple supervised tools in one session.
- Start real local processes through the existing `zstd.Process.LocalRunner`
  contract while remaining testable with fake runners.
- Capture command receipts, stdout, stderr, status, guardrails, warnings,
  next actions, and artifact links.
- Keep the emitted feed compatible with the existing workbench parser:
  `agent_status`, `check_result`, `artifact_link`, `guardrail`, `warning`, and
  `next_action`.
- Redact sentinel secrets from feed text, receipts, and captured artifacts.
- Add a copyable `examples/agent_supervisor.zig` example.

## Non-Goals

- No background daemon yet.
- No parallel scheduling yet; tools run sequentially for deterministic local
  development.
- No browser UI changes yet; that is M15.
- No hosted coordination.
- No shell command string parsing; callers pass argv arrays.

## API Shape

`SupervisedTool` wraps an existing `AdapterSpec`:

```zig
pub const SupervisedTool = struct {
    adapter: AdapterSpec,
    check_label: []const u8,
    stdout_artifact_path: []const u8 = "",
    stderr_artifact_path: []const u8 = "",
};
```

`SupervisorPolicy` controls the run:

```zig
pub const SupervisorPolicy = struct {
    fail_fast: bool = true,
    guardrails: []const []const u8 = &.{},
    next_action: []const u8 = "",
};
```

`runSupervisorAlloc` owns a `Session`, runs the tools, and returns an owned
summary:

```zig
pub fn runSupervisorAlloc(
    allocator: std.mem.Allocator,
    session_id: []const u8,
    workspace: []const u8,
    runner: anytype,
    tools: []const SupervisedTool,
    policy: SupervisorPolicy,
) !SupervisorSummary;
```

`runSupervisorEffect` exposes the same behavior through the effect runtime using
provided `Session` and runner services.

## Event Flow

For each tool:

1. record `agent_status` with `running`.
2. execute `adapter.command()` through the runner.
3. capture redacted stdout/stderr artifacts when paths are provided.
4. record `artifact_link` for each captured artifact.
5. record `check_result` with redacted command and detail.
6. record terminal `agent_status` as `done` or `failed`.

The supervisor records configured guardrails before the first tool and a
configured next action after the last tool.

## Testing

Required coverage:

- multi-tool supervisor records pass/fail status, artifacts, guardrails, and
  next action.
- fail-fast policy stops after the first failing tool.
- feed and artifacts redact sentinel secrets.
- effect-native supervisor records causal facts.
- `examples/agent_supervisor.zig` compiles and has a behavior test.
