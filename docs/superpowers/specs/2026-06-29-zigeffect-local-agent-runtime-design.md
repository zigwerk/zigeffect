# zigeffect Local Agent Runtime Design

## Goal

Run local Codex, Claude Code, zigeffect, and tool commands as a supervised local
runtime that streams workbench-compatible agent events into the collector.

## Decision

Build the first runtime in the Bun-local collector/workbench package. This is
local tooling, not Cloudflare request-path code. The runtime accepts a list of
tool definitions, emits local dev-session events to `POST /agent-events`, runs
each command through an injectable runner, and emits check/status events from
the result.

## Architecture

`localAgentRuntime.ts` owns the runtime contract:

- `LocalAgentRuntimeTool` describes one command, its agent kind, label, cwd, and
  optional task text.
- `LocalAgentRuntimeRunner` is an injectable process boundary. Tests use a fake
  runner. Local use can use `bunLocalAgentRunner`, backed by `Bun.spawn`.
- `runLocalAgentRuntime` emits sanitized start, check, done/failed, and optional
  warning events to a caller-provided collector endpoint.

Every event is normalized through `parseLocalDevSessionEventMessage` before it
is posted. That keeps the runtime from leaking token/password-shaped text even
if a future caller posts directly to a mock endpoint rather than the collector.

## Non-Goals

- Do not build a terminal UI.
- Do not manage long-running interactive Codex sessions yet.
- Do not introduce hosting or durable orchestration.
- Do not replace the Zig `zstd.Agent` supervisor; this is the browser/collector
  local runtime companion.

## Acceptance Criteria

- Bun tests prove command events are posted in order with redaction.
- Bun tests prove failures emit failed checks/status and continue unless
  `failFast` is set.
- Bun tests prove the `Bun.spawn` runner can execute a simple local command.
- Existing workbench and collector tests continue to pass.
