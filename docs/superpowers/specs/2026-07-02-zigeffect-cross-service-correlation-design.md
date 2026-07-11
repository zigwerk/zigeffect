# zigeffect cross-service correlation, multi-host ingest, hub persistence — design

Date: 2026-07-02. Follow-up to
`2026-07-01-zigeffect-multi-service-live-observability-design.md`, delivering the
three items that design explicitly deferred: cross-service correlation via a
boundary id, multi-host/auth, and hub persistence.

## H7 — cross-service correlation (boundary id)

**Problem.** Each service's causal trace is an island. When payments-api posts an
entry to ledger, the workbench shows two unrelated traces; nothing links the
outbound effect in one service to the run it caused in the other.

**Wire.** `CausalEvent` gains `boundary_id: ?u64 = null` — one id stamped on both
sides of a service boundary: the ORIGIN allocates it (`store.nextBoundaryId()`)
and records it on its outbound event; the CALLEE receives it over the real
transport (like a trace id) and records it on its inbound run/scope events.
Emitted everywhere the other ids are: live NDJSON (`formatCausalJsonLine`), the
saved artifact, and all cloning backends (plain value field — no ownership work).

*Known limitation (accepted):* per-store `nextBoundaryId()` counters can collide
across services if two origins allocate independently. The correlation index
lists occurrences, so a collision shows extra links — degraded, not broken. Real
deployments should propagate origin-allocated ids only.

**Hub index.** The hub maintains `boundary_id → occurrences[{service_key,
event_id, event_kind, label}]` across ALL services (the frontend only buffers
subscribed ones). Bounded like everything else: at most `maxBoundaries` distinct
ids (default 4096), at most 32 occurrences per id; a GC'd service's occurrences
are pruned. Exposed as `GET /correlate?boundary=<id>`.

**Workbench.** `LiveFrame`/artifact events carry `boundary_id`/`boundaryId`. When
the selected event has one and the workbench is in hub mode, the inspector shows a
**Boundary** section: the id plus each occurrence in another service as a jump
link — clicking focuses that service and selects the correlated event (the same
promote semantics as pinned panes). Static/single-artifact mode shows the id only.

**Demo.** `multi_service_stream_example.zig`: payments-api records
`effect_started "post ledger entry"` with a boundary id; ledger's
`scope_opened "post entry"` carries the same id — the browser demo can jump
payments-api → ledger through the inspector.

## H8 — multi-host ingest + auth

Scope: several machines' services fan into one hub on a trusted dev network —
NOT internet-facing infra. No TLS, no users, no sessions.

- `HUB_HOST` env (default `127.0.0.1`): bind address; set `0.0.0.0` to accept
  remote emitters.
- `HUB_TOKEN` env: when set, every mutating/reading endpoint requires it —
  HTTP via `authorization: Bearer <token>`, the `/live` WebSocket and browser
  GETs via `?token=<token>` (browsers cannot set WS headers). Comparison is
  timing-safe. Unset = today's open localhost behavior.
- CORS: `access-control-allow-origin: *` on responses so the workbench (another
  port) can call `/correlate` and `/services` directly.

## H9 — hub persistence

Opt-in snapshot so a hub restart doesn't lose buffered traces:

- `HUB_PERSIST=<path>.json`: the hub atomically (tmp + rename) writes a
  versioned snapshot of its state — per-service frames, `sequence`,
  `totalFrames`, layers, and the boundary index — debounced from the sweep
  timer after ingest activity, and once more on SIGINT/SIGTERM.
- On boot with `HUB_PERSIST` set and the file present: state is restored with
  every service marked `stopped` (a live emitter flips it back to running with
  its next frame). **Sequences continue from their restored values** — critical,
  because the frontend treats a sequence regression as a service restart and
  resets its buffer.
- Snapshot version mismatch or unparseable file → start empty and log; never
  crash on a stale snapshot.

Bun-native `fs` is fine here — the hub is LOCAL tooling, never Worker code.

## Explicitly out of scope

TLS termination, per-user auth, retention beyond the ring buffers, clustering
of hubs, and cross-hub correlation.
