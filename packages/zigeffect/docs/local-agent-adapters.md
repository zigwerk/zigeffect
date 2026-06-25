# Local Agent Adapters

Date: 2026-06-25

Local agent adapters let Codex, Claude Code, humans, and zigeffect tools append
small JSONL events that update a local development session in the workbench.
They are local files or stdin streams, not hosted telemetry.

## Event stream

Each line is one JSON object. Invalid lines are ignored.

Common fields:

- `sequence`: non-negative safe integer
- `kind`: one of `agent_status`, `check_result`, `artifact_link`,
  `next_action`, `guardrail`, or `warning`

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

`next_action`, `guardrail`, and `warning` use `value`:

```json
{"sequence":4,"kind":"guardrail","value":"do not claim verification without the gate receipt"}
```

## Redaction

The parser redacts secret-shaped text in labels, tasks, commands, details,
artifact paths, and values before the workbench model sees the event. Adapter
writers should still avoid writing raw secrets, but the parser is the local
workbench boundary.

## Sample

`packages/zigeffect/workbench/public/sample-agent-activity.jsonl` contains a
Codex plus Claude Code activity sample that can be parsed by
`localDevSessionEventsFromJsonl` and applied to a
`zigeffect.causal.dev-session.v1` artifact.

