# Live-attach collector

The WebSocket bridge between a running zigeffect engine and the SolidJS workbench.

```
engine ──NDJSON──▶ collector ──LiveFrame per WS message──▶ workbench (?live=)
```

The engine feeds NDJSON via `CausalNdjsonTap` (in
`services/causal_hub_backend.zig`) — a `CausalBackend` that serializes each
recorded `CausalEvent` to an NDJSON line as it happens (safe with bounded stores)
and buffers it for `drain`. This collector ingests that NDJSON, maps each line to
the workbench `LiveFrame` wire shape (`frame.ts`), and broadcasts it — one frame
per WebSocket message — to every connected browser.

## Run

The engine half is `examples/live_stream_example.zig` (`CausalNdjsonTap` →
NDJSON). End to end:

```bash
# 1. Build the engine emitter once.
cd packages/zigeffect && zig build live-stream-example

# 2. Stream a sample causal run into the collector (serves :4500):
./zig-out/bin/zigeffect-live-stream-example \
  | bun src/collector/collector.ts   # cwd: packages/zigeffect/workbench

# …or POST NDJSON to an already-running collector:
curl -XPOST --data-binary @events.ndjson http://127.0.0.1:4500/ingest
```

`zig build live-stream` also prints the sample NDJSON to stdout directly. Set
`PORT` to change the listen port. (`sample-engine-stream.ndjson` here is that
emitter's output, replayed verbatim by the end-to-end collector test.)

### Endpoints
- `GET /live` — WebSocket; browser clients subscribe here. Each message is one
  JSON causal, command, or local agent frame.
- `POST /ingest` — body is NDJSON engine `CausalEvent` lines; returns
  `{"ingested": <count>}` and broadcasts each mapped frame.
- `POST /frames` — validates and broadcasts trusted, already-mapped live frames.
- `POST /command` — validates, redacts, stores, and broadcasts one intervention
  command intent.
- `GET /commands?after=<sequence>` — returns command intents newer than the
  caller's cursor for an engine-side command tap.
- `POST /agent-events` — validates, redacts, and broadcasts one local Dev Session
  event or an array of events.
- `POST /agent-feed` — validates and broadcasts a local Dev Session JSONL body.
- `GET /health` — `{"ok": true, "clients": <n>}`.

## Local agent processes

`localAgentProcessSupervisor.ts` owns one Bun child process, tails stdout,
drains bounded stderr, and emits running/check/terminal receipts through
`POST /agent-events`. `localAgentTranscriptAdapters.ts` supplies native public
stream adapters and command builders for:

```text
codex exec --json "<prompt>"
claude -p "<prompt>" --output-format stream-json --verbose
```

Provider envelopes are reduced to the provider-neutral `agent_turn` contract
before browser delivery. Secret-shaped JSON fields are structurally redacted,
payload snippets are bounded, unsupported events are ignored, and tests use the
offline fixtures under `fixtures/`.

## Durable local sessions

`localAgentSessionRegistry.ts` keeps bounded, copied session records and a
versioned `zigeffect.local-agent-sessions.v1` snapshot. Restoring a snapshot
marks any persisted `starting` or `running` entry `interrupted`, because an OS
process handle cannot survive registry-owner restart.

`bunLocalAgentSessionStore(path)` writes snapshots through a unique sibling
temporary file and atomic rename. Pass both `registry` and `sessionStore` to
`runLocalAgentProcessSupervisor`; it writes through `starting`, `running`, and
terminal transitions. Commands, paths, tasks, labels, and diagnostics are
redacted and capped before persistence. Retention evicts only old terminal
records and never hides active ownership.

## Point the workbench at it

Open the workbench with `?live=<ws-url>`:

```
http://localhost:5173/?live=ws://127.0.0.1:4500/live
```

`webSocketLiveSource` (in `../liveAttach.ts`) connects, and the accumulating
artifact feeds every existing view (timeline, graph, findings, …) live.

## Runtime boundary

This is **local tooling**, not a Cloudflare Worker handler, so it uses Bun-native
`Bun.serve` (with WebSocket) per the project's runtime rule. Do not import it into
a Worker request path.
