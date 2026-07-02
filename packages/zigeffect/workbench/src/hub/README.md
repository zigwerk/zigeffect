# Causal hub

Multi-service fan-in for the workbench. Generalizes the single-stream
[`../collector`](../collector/README.md): instead of one anonymous live stream, the
hub groups every causal event by its engine **`service_key`** (which
`formatCausalJsonLine` already emits on every event), so **services auto-discover**
— no registration and no hand-assigned ids required.

```
zig-service-A ─┐
zig-service-B ─┼─▶ causal-hub ─▶ workbench (1 ws, subscribe per service)
zig-service-C ─┘
```

## What it does

- **Auto-discovery** — each NDJSON line self-identifies via `service_key`; the hub
  routes it to that service's buffer, creating the service on first sight.
- **Per-service bounded ring buffer** — retention is enforced centrally
  (`maxFramesPerService`, default 5000; oldest dropped past the cap). This caps
  memory regardless of whether a service used a bounded `CausalStore`.
- **Liveness** — a service is `running` on recent frames, decaying to `idle` then
  `stopped` via a sweep; `POST /register` / `POST /deregister` give explicit signals.
- **Multiplexed WebSocket** — one `/live` socket; a client sends
  `{type:"subscribe",services:[…]}` and receives `roster`, `frame`, and
  `service-status` messages. Subscribing **backfills** that service's buffered
  history so drilling into a running service shows its trace so far.

## Run

```bash
# The runnable two-service demo (payments-api + ledger, layer-tagged, via
# CausalStore.initForService — each event self-identifies on the wire):
cd packages/zigeffect && zig build multi-service-stream-example
./zig-out/bin/zigeffect-multi-service-stream-example | bun workbench/src/hub/hub.ts

# Real deployments fan several emitters into one hub (:4600):
( ./svc-a & ./svc-b & ) | bun src/hub/hub.ts        # cwd: packages/zigeffect/workbench
#   …or POST NDJSON to a running hub, tagging an untagged stream:
curl -XPOST --data-binary @events.ndjson 'http://127.0.0.1:4600/ingest?service=payments-api'
```

### Endpoints
- `GET /live` — WebSocket; browser clients subscribe here (`HubMessage` JSON).
- `POST /ingest[?service=<key>]` — NDJSON body; routes each line by its own
  `service_key`, falling back to the `?service=` tag when a line has none.
- `POST /register {service_key}` / `POST /deregister {service_key}` — liveness.
- `GET /services` — `{services: ServiceSummary[]}` roster.
- `GET /correlate?boundary=<id>` — everywhere that boundary id was observed,
  across ALL services: `{boundary_id, occurrences: [{service_key, event_id,
  event_kind, label}]}`. The inspector's cross-service jump links use this.
- `GET /health` — `{ok, services, clients, rejected_lines, boundaries}`. Always
  open, even when a token is configured.

### Environment
- `PORT` (4600) · `HUB_SERVICE` — default service_key for untagged stdin lines.
- `HUB_HOST` (127.0.0.1) — set `0.0.0.0` to accept emitters from other machines
  on a trusted dev network. This is local tooling: no TLS, no users.
- `HUB_TOKEN` — when set, every endpoint but `/health` requires it:
  `authorization: Bearer <token>` for HTTP, `?token=<token>` for the WebSocket
  and browser GETs (append it to the `?hub=` URL and the workbench carries it
  through to `/correlate`). Comparison is timing-safe.
- `HUB_PERSIST=<path>.json` — snapshot the hub's state (frames, sequences,
  layers, boundary index) atomically after activity and on SIGINT/SIGTERM;
  restored on boot with services `stopped` and **sequences continuing** (a
  regression would read as a service restart to clients). An incompatible or
  corrupt snapshot is ignored, never fatal.

## Point the workbench at it

Open the workbench with `?hub=<ws-url>` (multi-service), analogous to the
single-service `?live=`:

```
http://localhost:5173/?hub=ws://127.0.0.1:4600/live
```

## Runtime boundary

**Local tooling**, not a Cloudflare Worker handler — it uses Bun-native
`Bun.serve` (with WebSocket) per the project's runtime rule. Do not import it into
a Worker request path.
