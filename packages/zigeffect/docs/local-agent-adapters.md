# Local Agent Adapters

Date: 2026-07-10

Local agent adapters let Codex, Claude Code, humans, and zigeffect tools append
small JSONL events that update a local development session in the workbench.
They are local files or stdin streams, not hosted telemetry.

## Event stream

Each line is one JSON object. Invalid lines are ignored.

Common fields:

- `sequence`: non-negative safe integer
- `kind`: one of `agent_status`, `agent_turn`, `check_result`, `artifact_link`,
  `transport_status`, `next_action`, `guardrail`, or `warning`

`agent_status`:

```json
{"sequence":1,"kind":"agent_status","agent_id":"codex","agent_kind":"codex","agent_label":"Codex","status":"running","task":"editing workbench"}
```

`check_result`:

```json
{"sequence":2,"kind":"check_result","label":"bun run zigeffect:workbench:test","status":"pass","command":"bun run zigeffect:workbench:test","detail":"all tests passed"}
```

`artifact_link`:

```json
{"sequence":3,"kind":"artifact_link","key":"agent_activity","path":".zig-cache/causal-artifacts/local-agent-activity.jsonl"}
```

`agent_turn` records assistant, user, tool, or system evidence with a stable ID:

```json
{"sequence":4,"kind":"agent_turn","agent_id":"codex","agent_kind":"codex","agent_label":"Codex","turn_id":"item-7","role":"assistant","status":"completed","summary":"Implemented the parser","output":"Tests pass"}
```

`next_action`, `guardrail`, and `warning` use `value`:

```json
{"sequence":5,"kind":"guardrail","value":"do not claim verification without the gate receipt"}
```

## Native CLI streams

The collector runtime includes explicit adapters for the public script output of
both supported local coding agents:

```text
codex exec --json "<prompt>"
claude -p "<prompt>" --output-format stream-json --verbose
```

`codexTranscriptAdapter` maps completed and in-progress Codex items such as
assistant messages, commands, file changes, MCP calls, collaboration calls, web
searches, plans, reasoning summaries, and errors. Item IDs are preserved so
started/updated/completed events update one workbench turn.

`claudeCodeTranscriptAdapter` maps system initialization, complete assistant
messages, tool-use/tool-result pairs, and result records. Partial token deltas
are ignored to prevent duplicate text. Parallel tool uses in one assistant
message receive distinct monotonic event sequences.

`codexLocalAgentProcessTool` and `claudeCodeLocalAgentProcessTool` build the
supported command arrays and attach the matching adapter. Pass the result to
`runLocalAgentProcessSupervisor` with the collector's local `/agent-events` URL.
Tests use offline fixtures and never invoke a paid agent run.

## Redaction

The parser redacts secret-shaped text in labels, tasks, commands, details,
artifact paths, and values before the workbench model sees the event. JSON tool
inputs are parsed and redacted structurally, including nested secret-key fields,
before being serialized again. Native adapter snippets are capped at 4096
characters. Adapter writers should still avoid writing raw secrets, but the
parser is the local workbench boundary.

## Sample

`packages/zigeffect/workbench/public/sample-agent-activity.jsonl` contains a
Codex plus Claude Code activity sample that can be parsed by
`localDevSessionEventsFromJsonl` and applied to a
`zigeffect.causal.dev-session.v1` artifact.

Native public-envelope fixtures live at:

- `packages/zigeffect/workbench/src/collector/fixtures/codex-exec-jsonl.jsonl`
- `packages/zigeffect/workbench/src/collector/fixtures/claude-code-stream-json.jsonl`
