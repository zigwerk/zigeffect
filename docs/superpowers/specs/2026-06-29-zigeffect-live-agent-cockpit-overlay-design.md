# zigeffect Live Agent Cockpit Overlay Design

## Goal

Make the existing workbench live WebSocket carry local agent development events
beside causal graph events, so Codex, Claude Code, zigeffect tools, and local
supervisors can update the Dev Session tab without a static artifact reload.

## Decision

Keep `/live` as the single browser WebSocket. The collector will broadcast two
message shapes over it:

- causal `LiveFrame` records, already consumed by the timeline/graph views.
- local dev-session event records, already consumed by `localDevSessionFeed.ts`.

The browser live source routes each message by shape. Causal frames continue into
`LiveCausalBuffer`. Local dev-session events go into a small live session buffer
that produces a `LocalDevSessionModel` overlay for the Dev Session tab.

## Architecture

`liveAttach.ts` grows an optional `onLocalDevEvent` subscriber callback, a
`LiveLocalDevSessionBuffer`, and a `localDevSession()` signal on the live handle.
`webSocketLiveSource` parses a WebSocket message first as a causal frame, then as
a local dev-session event. Unknown messages remain ignored.

The collector adds two local-only endpoints:

- `POST /agent-feed` accepts agent JSONL and broadcasts each valid local
  dev-session event.
- `POST /agent-events` accepts one event or an array of events and broadcasts the
  normalized events.

The collector broadcasts the normalized event returned by the frontend parser,
so redaction and validation happen before browser delivery.

`App.tsx` uses the live local session overlay when the loaded live causal
artifact does not itself contain a dev-session artifact.

## Non-Goals

- Do not launch Codex or Claude Code yet.
- Do not replace the existing causal graph live stream.
- Do not add hosted control-plane APIs.
- Do not add another browser socket.

## Acceptance Criteria

- Bun tests prove `webSocketLiveSource` emits local dev-session events.
- Bun tests prove `createLiveArtifact` exposes a live `LocalDevSessionModel`.
- Bun collector tests prove `POST /agent-feed` broadcasts redacted agent events
  over `/live`.
- Existing causal live-attach tests continue to pass.
