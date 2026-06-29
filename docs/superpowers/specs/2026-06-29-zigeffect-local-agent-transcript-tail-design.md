# zigeffect Local Agent Transcript Tail Design

## Goal

Convert long-running local agent transcript streams into live Dev Session turn
receipts.

## Decision

Add a provider-neutral transcript tail adapter in the local workbench collector
package. It consumes line-oriented text from a `ReadableStream`, converts
recognized JSONL or tagged text lines into `agent_turn` events, and posts those
events to the existing collector `POST /agent-events` endpoint.

Supported first-pass input shapes:

- JSON object lines with `kind: "agent_turn"`.
- JSON object lines with `type: "turn"` or obvious turn fields such as `role`,
  `summary`, `input`, or `output`.
- Plain tagged lines such as `assistant: edited the CLI parser` or
  `user: run the gate`.

Every output event is normalized through `parseLocalDevSessionEventMessage`
inside `postLocalAgentEvent`, so transcript text is redacted before it reaches
the browser.

## Non-Goals

- Do not reverse-engineer private Codex or Claude transcript internals.
- Do not own terminal lifecycle yet; this adapter consumes streams that a runner
  gives it.
- Do not persist full unredacted transcripts.

## Acceptance Criteria

- Tests prove JSONL transcript lines map to redacted `agent_turn` events.
- Tests prove tagged plaintext lines map to turn events.
- Tests prove stream tailing handles chunk boundaries and flushes trailing
  partial lines.
- Tests prove junk lines are ignored without stopping the tail.
