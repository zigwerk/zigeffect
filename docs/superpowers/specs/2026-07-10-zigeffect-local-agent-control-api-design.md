# zigeffect Local Agent Control API Design

## Goal

Expose bounded local list/start/stop/session-detail operations for approved
agent tools so the workbench can operate the local runtime without accepting
arbitrary commands or introducing a hosted control plane.

## Authority Model

The server accepts only a `tool_id`, optional safe `session_id`, and bounded
tool-specific input. It never accepts an argv array from HTTP. The embedding
process owns a fixed allowlist of `LocalAgentControlTool` entries; each entry
validates/builds its own `LocalAgentProcessTool` from the input.

Every control route requires a non-empty bearer token. `/agent-control/health`
is the only open route. The server returns explicit CORS headers for local
workbench fetches and rejects oversized request bodies before tool construction.

## Routes

- `GET /agent-control/health`: open liveness and active-count response.
- `GET /agent-control/tools`: authenticated safe tool metadata, never commands.
- `GET /agent-control/sessions`: authenticated registry list.
- `GET /agent-control/sessions/:id`: authenticated registry detail.
- `POST /agent-control/sessions`: start one allowlisted tool.
- `POST /agent-control/sessions/:id/stop`: abort active ownership.
- `GET /agent-control/receipts`: authenticated bounded control audit receipts.

`OPTIONS` returns the local CORS policy without executing a route.

## Process Ownership

Starting a session allocates or validates a safe ID, creates an
`AbortController`, and launches `runLocalAgentProcessSupervisor` with the shared
registry/store. Active controllers are retained only until the supervisor
settles. Duplicate active or retained session IDs return conflict and never
start a second child.

Stopping requests abort the owned controller. Terminal or unknown sessions are
not treated as active. `waitForIdle` allows tests and graceful local shutdown to
await all owned supervisors.

## Receipts

The control server records a bounded append-only audit receipt for every
accepted or policy-rejected start/stop operation. Receipts contain sequence,
action, outcome, session/tool IDs, timestamp, and redacted detail. An optional
async sink can mirror each receipt into a causal/event backend; sink failure is
isolated and never delays or alters the control decision.

Authentication failures are not mirrored to the agent event stream, preventing
an unauthenticated caller from generating unbounded workbench noise. They still
receive a 401 response.

## Limits And Validation

- Tool IDs and session IDs use bounded safe identifier syntax.
- Tool IDs must be unique at construction.
- Request body size defaults to 64 KiB.
- Control receipts default to a 512-entry ring.
- Tool builders may throw a validation error; the server returns 400 and records
  a rejected start receipt.
- Tool builders must return a non-empty command and matching agent metadata.
- Registry capacity is observed before a start response is accepted.

## Non-Goals

- Do not accept arbitrary shell commands over HTTP.
- Do not expose environment variables or unredacted commands.
- Do not implement PTY stdin or resize yet.
- Do not add SolidJS controls yet; that is M86.
- Do not bind a network port inside the core server object; callers own
  `Bun.serve` and host selection.

## Acceptance Criteria

- Tests prove bearer auth and CORS behavior.
- Tests prove tool metadata never exposes argv.
- Tests prove allowlisted starts reach terminal registry state.
- Tests prove unknown tools, invalid inputs, duplicate IDs, and oversized bodies
  cannot start a child.
- Tests prove stop aborts exactly one owned child and persists interruption.
- Tests prove list/detail/receipt routes are bounded and redacted.
- Tests prove `waitForIdle` settles all background supervisor promises.
