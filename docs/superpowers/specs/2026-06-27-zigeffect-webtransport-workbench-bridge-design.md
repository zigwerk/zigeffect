# zigeffect WebTransport Workbench Bridge Design

## Goal

Turn the experimental QUIC/WebTransport adapter into a visible local
development path: zigeffect can frame local agent-session events as
WebTransport payloads, and the workbench can consume those frames while showing
transport health beside agents, checks, commands, and artifacts.

## Architecture

`packages/zigeffect-quic` owns transport framing. It accepts local agent JSONL
from `zstd.Agent.Session`, wraps each event as a redacted WebTransport dev-frame
JSONL line, records those payloads into a deterministic fake WebTransport
client for tests, and emits a bridge receipt.

`packages/zigeffect/workbench` owns visual interpretation. Its local dev-session
feed parser accepts both raw local dev-session events and
`zigeffect.webtransport.local-dev-frame.v1` wrapper frames. It also understands
`transport_status` events and renders them in the Dev Session tab.

## Scope

- Add a deterministic WebTransport local dev-session bridge in
  `zigeffect-quic`.
- Add workbench parsing for WebTransport-framed local dev-session events.
- Add local dev-session transport models, timeline rows, and UI panel.
- Update docs and roadmap for M19.

## Non-Goals

- Do not replace the existing WebSocket collector path.
- Do not require a live browser WebTransport connection in CI.
- Do not add MoQ or production WebTransport server hosting.

## Acceptance Criteria

- `bun run zigeffect:quic:test` proves `zstd.Agent.Session` JSONL is bridged
  into redacted WebTransport frame JSONL.
- `bun run zigeffect:workbench:test` proves the browser model consumes framed
  events and renders transport state.
- Dev Session UI shows transport protocol/status/frame count when present.
- Existing raw JSONL and static dev-session samples continue to work.
