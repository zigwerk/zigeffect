# zigeffect Native Agent Transcript Adapters Design

## Goal

Normalize the public JSONL stream envelopes emitted by current Codex and Claude
Code CLIs into zigeffect's provider-neutral local `agent_turn` receipts.

## Source Boundary

The adapter contract is based on public, script-oriented output modes:

- Codex `codex exec --json`, documented as newline-delimited state-change
  events. The installed development version is `codex-cli 0.144.0-alpha.4`.
- Claude Code `claude -p --output-format stream-json --verbose`, documented as
  newline-delimited events for programmatic runs. The installed development
  version is `2.1.191`.

Fixtures contain minimal representative public envelopes. They do not copy or
parse private session-rollout storage under `~/.codex` or `~/.claude`.

## Decision

Add provider adapters beside the provider-neutral transcript tail. An adapter
accepts one line, agent identity, and sequence, and returns zero, one, or several
normalized `agent_turn` events. Multiple results cover parallel tool-use blocks
without dropping evidence. The transcript tail receives an optional adapter;
it tries the explicit adapter first and retains the current provider-neutral
JSON/tagged-text parser as a fallback.

Provider process-tool builders attach the correct adapter and public CLI flags:

- Codex: `codex exec --json <prompt>`.
- Claude Code: `claude -p <prompt> --output-format stream-json --verbose`.

The process supervisor forwards the tool's adapter into the existing transcript
tail. Provider details therefore remain outside the workbench session model.

## Codex Mapping

Codex item lifecycle events use `item.id` as the stable turn ID:

- `agent_message` -> assistant turn.
- `command_execution`, `file_change`, `mcp_tool_call`, and `web_search` -> tool
  turn.
- `collab_tool_call` -> tool turn with sender/receiver state.
- `reasoning` and `todo_list` -> system turn using only the public summary.
- `error` item or top-level `turn.failed` / `error` -> failed system turn.
- `item.started` / `item.updated` -> started status; `item.completed` -> completed
  or failed status.

Thread/turn lifecycle records without displayable evidence are ignored. The
process supervisor remains the source of terminal process status.

## Claude Code Mapping

- `system/init` and documented operational system records -> system turns.
- `assistant` messages with text content -> assistant turns keyed by message ID.
- `assistant` messages with `tool_use` content -> started tool turns keyed by
  tool-use ID; parallel tool-use blocks each receive a turn.
- `user` messages with `tool_result` content -> completed/failed tool turns using
  the same tool-use ID, so the workbench upserts lifecycle state.
- `result` records -> completed/failed assistant result turns.
- `stream_event` partial deltas -> ignored to prevent duplicated token fragments;
  complete assistant messages remain the evidence boundary.

## Safety And Compatibility

- Free text and JSON snippets are capped before event normalization.
- JSON-shaped text is parsed and redacted recursively so quoted secret keys do
  not bypass the plain-text redaction expressions.
- All emitted events still pass through `parseLocalDevSessionEventMessage`,
  preserving the existing redaction boundary.
- Unknown event/item/content types return `null` and do not terminate the tail.
- Adapters use defensive record checks and optional fields because provider
  envelopes can add fields over time.
- Command builders expose exact argument arrays; they do not invoke either CLI.

## Non-Goals

- Do not capture private reasoning or hidden transcript files.
- Do not emit partial-token events.
- Do not execute a paid provider call in tests.
- Do not promise every future provider event type is displayable.

## Acceptance Criteria

- Offline Codex fixtures produce stable assistant/tool/system turn receipts.
- Offline Claude Code fixtures produce stable system/tool/assistant/result turn
  receipts and tool lifecycle upserts.
- Sentinel secrets are absent from every normalized event.
- Unknown and partial events are ignored without stopping stream ingestion.
- Command-builder tests prove the supported public streaming invocation shapes.
- Process-supervisor tests prove a tool-attached adapter is used end to end.
