# zigeffect multi-service live observability (design)

Date: 2026-07-01
Surfaces: `packages/zigeffect` (Zig runtime + collector), `packages/zigeffect/workbench`
Status: design draft, not yet approved to build

## Goal

Let a developer point the workbench at a running system of **multiple zig
programs / microservices** and *auto-discover* them — no hand-typed `?live=` URL
per service. From a drill-down sidebar (services → layers within a service) they
can focus one service at a time, or **pin** two-plus services into a side-by-side
comparison to correlate cross-service causality live.

Locked decisions (from the user):
1. **Discovery** — a central persistent **causal hub** process. Each zig service
   registers/streams to it on startup; the workbench connects once and gets the
   live roster + multiplexed channels.
2. **Multi-view** — a services sidebar with one-at-a-time drill-down by default,
   plus optional **pinning** into a side-by-side comparison view.
3. **Layer concept** — first-class **layer** identity (not just inferred from
   event type names).

## The key finding: identity already flows to the wire

This is cheaper than it looks. Reading the source:

- `CausalEvent` already has **`service_key: []const u8`** and **`layer_id: ?u64`**
  fields (`src/services/causal.zig:224-225`).
- The **live** per-event NDJSON serializer `formatCausalJsonLine` already emits
  both on every frame (`src/services/causal_jsonl_backend.zig:118-121`, schema
  `zigeffect.causal.event.v1`). The full artifact serializer emits them too
  (`causal.zig:1526-1529`).
- `CausalStore.nextLayerId()` already mints stable layer ids (`causal.zig:858`).
- `recordCausal(event)` exists at every level (context/scope/fiber/graph/
  supervisor) and takes a `CausalEvent` struct, so `.service_key` / `.layer_id`
  are settable per event **today** with no schema change.

**So the engine already knows which service and which layer each event belongs
to, including on the live stream. The gap is 100% downstream** — the wire
`LiveFrame`, the collector, and the frontend all *drop* `service_key`/`layer_id`:

- `LiveFrame` (`workbench/src/liveAttach.ts:28-38`) has no service/layer fields.
- `causalLineToFrame` (`workbench/src/collector/frame.ts:66-95`) maps only
  id/kind/status/label/lane/parent/finding/priority — it discards the rest.
- The frontend `CausalEvent` / `normalizeEvent` and `frameToEventRecord` never
  read them.
- The collector (`collector.ts`) is a single anonymous stream: no service
  identity, no roster, no per-service buffering.

## Architecture

```
┌────────────────────┐  register {service_key, pid, meta}  ┌──────────────────┐
│ zig-service-A       │────────────────────────────────────▶│   causal-hub      │
│  CausalStore         │  stream NDJSON (already tagged with │  (new, persistent)│
│  + CausalNdjsonTap    │   service_key + layer_id per event) │                   │
│  drain → hub          │────────────────────────────────────▶│  • service roster │
└────────────────────┘                                        │  • per-service    │
┌────────────────────┐                                        │    bounded buffer │
│ zig-service-B  … →   │───────────────────────────────────▶ │  • liveness/HB    │
└────────────────────┘                                        │  • ONE multiplexed│
┌────────────────────┐                                        │    WS w/ channels │
│ zig-service-C  … →   │───────────────────────────────────▶ └────────┬─────────┘
└────────────────────┘                                                 │ 1 ws
                                                              ┌────────▼─────────┐
                                                              │   workbench       │
                                                              │  ServicesRail     │
                                                              │  (services→layers)│
                                                              │  1 pane / N pinned│
                                                              └──────────────────┘
```

The hub is the one genuinely new piece of infrastructure. It generalizes the
existing single-stream `collector.ts` (most of that logic — NDJSON→frame mapping,
redaction, broadcast — moves into the hub, now keyed per service).

**Reachability assumption:** like everything else in the causal pipeline today,
this is **local-dev / same-host or same-LAN tooling** — the hub is a process you
run alongside your services, not deployed shared infra. Observing services on
separate hosts (staging/containers) changes the hub's reachability + auth story
and is called out as a follow-up, not in this MVP.

## Component design

### 1. Zig side — near-zero, mostly ergonomics

The schema already supports this. Two small, optional improvements:

- **`withServiceKey` ergonomic helper** (recommended): today `service_key` must
  be set on every `recordCausal(.{ ... })` call. Add a runtime/context builder
  (e.g. `runtime.withServiceKey("payments-api")`) so a service names itself once
  and every event it records inherits it. Without this the feature still works;
  it's a DX nicety that avoids repetition and mistakes.
- **First-class layer *name*** (the user's "first-class layer tag"): `layer_id`
  is numeric and stable but not human-readable. To show "HTTP / domain /
  persistence" in the drill-down, add an optional **`layer_name: []const u8 =
  ""`** to `CausalEvent`, mirroring `service_key`, and one append line to each of
  the two serializers (`formatCausalJsonLine`, `formatCausalJson`). Alternative
  if we want zero Zig schema change: derive a display label from the first
  `type_name`/`label` seen at a `layer_id` (fuzzier). Recommendation: add
  `layer_name` — it's ~4 lines and matches the user's stated intent.

No new instrumentation hooks; causal recording stays explicit/opt-in as designed.

### 2. Causal hub (new process — `packages/zigeffect/workbench/src/hub/`)

Bun-native (local tooling, same runtime rule as the collector). Responsibilities:

- **Registration** — `POST /register {service_key, pid, hub_token?}` returns a
  `service_id`; a service streams NDJSON to `POST /ingest?service=<service_id>`
  (or stdin when launched as `service | hub-forward --service X`). The existing
  "pipe stdout" ergonomic is preserved; we just tag the stream with a service.
- **Per-service bounded buffers** — each service gets its own ring buffer
  (default cap, e.g. 5–10k frames). **This also fixes the unbounded-memory
  footgun centrally**: rather than trusting every zig program to call
  `initBounded`, the hub enforces uniform retention regardless.
- **Liveness** — heartbeat or pipe-close detection marks a service
  `running`/`idle`/`stopped`; the roster reflects it.
- **Roster** — `GET /services` returns
  `[{service_id, service_key, status, layer_ids, frame_count, since}]`; also
  pushed as a control message so the sidebar updates without polling.
- **Multiplexed WS** — one `GET /live` socket. The browser sends
  `{subscribe:[service_id,…]}` / `{unsubscribe:[…]}`; the hub sends
  `{type:"roster",…}`, `{type:"frame", service_id, …LiveFrame}`, and
  `{type:"service-status", service_id, status}`. One browser connection, N
  services.

### 3. Wire format extension

- **`LiveFrame`** (`liveAttach.ts`) gains `service_key?: string` and
  `layer_id?: number | null` (+ `layer_name?` if we add it in Zig).
  `causalLineToFrame` stops discarding them.
- **Hub envelope** — new discriminated `HubMessage` union (`roster` |
  `frame` | `service-status`) carrying `service_id`. The existing bare-frame
  `webSocketLiveSource` remains for the legacy single-service `?live=` path
  (back-compat), with a new `hubLiveSource` for the multiplexed path.
- `frameToEventRecord` + the TS `CausalEvent`/`normalizeEvent` gain
  `service_key`/`layer_id`(/`layer_name`) so downstream views can group by them.

### 4. Frontend

- **Multi-source registry** — generalize `createLiveArtifact` (today one buffer
  for one URL) into a small store keyed by `service_id`, so services can be
  subscribed/unsubscribed independently. One `hubLiveSource` fans hub messages
  into the right per-service buffer.
- **`ServicesRail`** (new leftmost slideout, above the lens switcher): services
  with a live status dot; expand a service to see its **layers** (grouped by
  `layer_id`/`layer_name` as events arrive). Click = drill in (replaces the
  workspace — the "one-at-a-time" default). A **pin** control adds a service to a
  comparison set.
- **Pinned side-by-side** — when >1 service is pinned, the workspace splits into
  per-service panes; **each pane is just the existing `TracePane` + `DagPanel`**
  fed by that service's buffer. The trace/DAG/inspector rendering barely changes;
  what's new is the selection layer above them. Selection/inspector become
  per-pane (or a shared inspector that follows the focused pane — open question).
- **Layer surfacing** — inside a service, `layer_id`/`layer_name` becomes a
  grouping in the trace (a lane band or a filter) and a line in the inspector;
  the drill-down list is generated from the layers seen in that service's stream.

## Safety / security

- Read-only viewer contract preserved end-to-end; the hub only fans out frames,
  it issues no commands to services.
- Redaction already happens at the source (`redactCausalText`) and again in the
  frame mapper (`redactFrameText`); unchanged.
- The hub's per-service bounded buffers cap memory centrally (the main new
  resource risk), and an optional `hub_token` gates `/register` and `/ingest` so a
  stray process can't inject frames.

## MVP vs later

- **MVP:** hub with register + tagged ingest + roster + multiplexed WS + per-
  service bounded buffers; `LiveFrame` carries `service_key`+`layer_id`;
  `ServicesRail` with drill-down + one-at-a-time focus; layer grouping in the
  trace. (Zig: populate the fields in an example service; optional
  `withServiceKey`.)
- **Later:** pinned side-by-side panes; `layer_name` string + first-class layer
  view; cross-service causality linking (correlate `A`'s retry with `B`'s
  failure); multi-host/auth; hub persistence across restarts.

## Risks / open questions

- **Hub chicken-and-egg** — it must be up before services start; needs a clean
  "service started before hub / hub restarted" reconnect story (buffer-and-retry
  on the service side, or accept gaps).
- **Ordering across services** — each service's `sequence`/event `id` is
  independent; there is no global clock, so side-by-side correlation is by
  logical content, not a shared timeline. Cross-service causality (later) needs an
  explicit correlation id (`trace_id`? `cause_event_id`?) — worth confirming what
  crosses a service boundary.
- **`service_key` = identity or display?** If a key can differ from a friendly
  name, we may want `service_name` too; likely `service_key` suffices for MVP.
- **Shared vs per-pane inspector** in the pinned view — pick before building
  side-by-side.
- **Do we keep the legacy single `?live=` collector path?** Recommend yes, as a
  thin back-compat shim over the hub, so existing docs/examples don't break.
