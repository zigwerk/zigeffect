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
  JSON `LiveFrame`.
- `POST /ingest` — body is NDJSON engine `CausalEvent` lines; returns
  `{"ingested": <count>}` and broadcasts each mapped frame.
- `GET /health` — `{"ok": true, "clients": <n>}`.

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
