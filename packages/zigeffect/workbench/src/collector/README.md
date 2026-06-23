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

```bash
# Serve on :4500 and fan out NDJSON piped on stdin:
your-engine-emitting-ndjson | bun packages/zigeffect/workbench/src/collector/collector.ts

# …or POST NDJSON to the ingest endpoint of an already-running collector:
curl -XPOST --data-binary @events.ndjson http://127.0.0.1:4500/ingest
```

Set `PORT` to change the listen port.

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
