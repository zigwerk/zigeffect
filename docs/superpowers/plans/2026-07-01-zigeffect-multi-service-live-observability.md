# zigeffect multi-service live observability — implementation plan

Design: `docs/superpowers/specs/2026-07-01-zigeffect-multi-service-live-observability-design.md`
Targets: `packages/zigeffect/workbench` (hub + frontend), `packages/zigeffect` (Zig example)
Verify: `bun run zigeffect:workbench:typecheck` · `bun run zigeffect:workbench:test` ·
`cd packages/zigeffect && zig build test` · preview with two fake services piped to the hub.

## Constraints

- **Runtime boundary:** the hub is **local tooling** (Bun-native `Bun.serve`),
  exactly like `collector.ts`. It must NOT be imported into any Cloudflare Worker
  path. No `Bun.*` in Worker code.
- Strict TS, `verbatimModuleSyntax` (`import type`), `noUncheckedIndexedAccess`.
- The `derive*` functions in `causalArtifact.ts` are the contract; extend
  `normalizeEvent`/`frameToEventRecord` additively (new optional fields only).
- Keep the workbench suite green (currently 130 pass) and Zig `zig build test`
  green. Every milestone ends verifiable on its own.
- Redaction stays where it is (source + frame mapper); do not weaken it.

## File plan

New:
- `workbench/src/hub/hub.ts` — the causal hub (Bun server: register, tagged
  ingest, per-service bounded buffers, roster, multiplexed WS). Mirrors the
  structure/testability of `collector.ts` (a `createHub()` factory + `if
  (import.meta.main)` server bootstrap).
- `workbench/src/hub/hub.test.ts`, `workbench/src/hub/README.md`.
- `workbench/src/hub/protocol.ts` — the `HubMessage` union + subscribe/roster
  types, shared by hub and frontend (type-only where possible).
- `workbench/src/liveServices.ts` — frontend multi-source registry keyed by
  `service_id` (generalizes `createLiveArtifact`) + `hubLiveSource`.
- `workbench/src/services/ServicesRail.tsx` — the drill-down sidebar
  (services → layers, status dots, focus + pin).
- Zig: `packages/zigeffect/examples/multi_service_stream_example.zig` — two
  layered services recording service_key + layer_id, emitting NDJSON.

Edited:
- `workbench/src/liveAttach.ts` — `LiveFrame` gains `service_key?`, `layer_id?`
  (+ `layer_name?`); `frameToEventRecord` carries them; add `hubLiveSource`.
- `workbench/src/collector/frame.ts` — `causalLineToFrame` stops discarding
  `service_key`/`layer_id`.
- `workbench/src/causalArtifact.ts` — `CausalEvent` type + `normalizeEvent` read
  `service_key`/`layer_id`(/`layer_name`); no change to existing derive outputs.
- `workbench/src/App.tsx` — mount `ServicesRail`; per-service live wiring; focus
  vs. legacy single `?live=` path.
- Zig (optional, small): `src/services/causal.zig` + `causal_jsonl_backend.zig`
  add `layer_name`; a `withServiceKey` helper on the runtime/context; a
  `multi-service-stream` step in `build.zig`.

## Milestones (each independently verifiable)

- **H1 — carry service + layer identity downstream (no hub yet).** TDD.
  Extend `LiveFrame` + `causalLineToFrame` + `frameToEventRecord` + TS
  `CausalEvent`/`normalizeEvent` to preserve `service_key`/`layer_id`. Update
  `collector/frame.test.ts` to assert they survive the NDJSON→frame mapping.
  Verify: workbench typecheck + tests green; a hand-fed NDJSON line with
  `service_key`/`layer_id` round-trips into a workbench event record. *This alone
  proves the engine's existing identity reaches the UI.*
- **H2 — hub core.** Build `createHub()`: `POST /register` → `service_id`;
  `POST /ingest?service=` + stdin forward; per-service bounded ring buffer;
  `GET /services` roster; `GET /live` multiplexed WS with subscribe/unsubscribe
  and `HubMessage` envelopes; `/health`. Tests (`hub.test.ts`) mirror
  `collector.test.ts`: registration, tagged ingest routes to the right buffer,
  bounded trim drops oldest, roster reflects liveness, subscribe filters frames.
  Verify: `bun test` green; `curl` register+ingest+roster by hand.
- **H3 — frontend multi-source.** `liveServices.ts`: a registry of per-service
  live buffers + `hubLiveSource` that routes hub messages. Unit-test the routing
  + bounded accumulation. Verify: tests green; a mock hub source drives two
  independent service buffers.
- **H4 — ServicesRail + drill-down + layer grouping.** Sidebar lists services
  (status dot) → expand to layers (grouped by `layer_id`/`layer_name`); click
  focuses a service (drives the existing workspace via its buffer); layer becomes
  a grouping/filter in the trace + a line in the inspector. Verify: preview —
  two fake services piped to the hub appear in the rail; drilling in shows each
  service's trace/DAG live; typecheck + tests green.
- **H5 — Zig example + ergonomics.** ✅ Done (2026-07-02).
  `examples/multi_service_stream_example.zig`: payments-api + ledger, layer-tagged
  events, interleaved NDJSON (proves the hub demuxes purely by each line's
  `service_key`). Build steps: `multi-service-stream` (run) +
  `multi-service-stream-example` (compile+test), hooked into `examples`.
  Ergonomic landed as `CausalStoreOptions.service_key` +
  `CausalStore.initForService(allocator, key)` — the default is stamped in
  `record` when an event's own `service_key` is empty (explicit key wins; slice
  must outlive the store). Verified: `zig build test` green; the installed binary
  piped into the hub populated `/services` with both services + layers.
- **H6 — pinned side-by-side panes + layer drill-down.** ✅ Done (2026-07-02).
  Rail: ⧉ pin toggle per service; layer chips are now buttons — clicking one
  focuses the service AND sets the trace text filter to the layer name
  (`layerName`/`serviceKey` were added to `searchableEventText`). Pinned services
  render as compact side panes (`src/services/PinnedPanes.tsx`) beside the main
  stage (`.stage-split`; stacks below on ≤1100px): status dot, findings badge,
  gap ("trace starts mid-run") notice, newest-first rows. Panes are ambient
  monitors — interaction PROMOTES (clicking the title or a row focuses that
  service and selects the event in the main workspace), so the single shared
  inspector is never ambiguous. Decision recorded: per-pane inspectors rejected
  because event ids collide across services; for the same reason every
  focus-switch clears the selection (`focusService` in App.tsx). Verified E2E
  in-browser: pin → backfill fills the pane, promote → focus+selection, chip →
  filter, desktop side-by-side + narrow stacked layouts.
- **Still future (separate plan):** cross-service correlation via a boundary id;
  multi-host/auth; hub persistence.

## Verification gates

1. `bun run zigeffect:workbench:typecheck` → exit 0.
2. `bun run zigeffect:workbench:test` → green (H1 frame tests, H2 hub tests, H3
   routing tests, updated existing tests).
3. `cd packages/zigeffect && zig build test` → green (H5).
4. Manual end-to-end: run the hub; pipe two fake NDJSON services (or the H5
   example) into it; open the workbench pointed at the hub; confirm the rail
   auto-lists both services, drill-down shows layers, and each service's live
   trace/DAG update independently — dark + light.
5. Final adversarial review of the diff (correctness of the multiplexing +
   bounded buffers + reconnect; a11y of the new rail; token discipline).

## Review + hardening round (2026-07-02)

A 22-agent adversarial review (5 dimensions, per-finding refutation) confirmed 17
findings (13 after dedup); all were fixed the same day:

- **Zig**: all four `appendJsonString` copies on the causal path now `\u00xx`-escape
  control bytes (< 0x20) — previously an ANSI escape in a label made the NDJSON line
  unparseable and the event silently vanished; runner-lineage edge clone leak fixed.
- **Wire**: `LiveFrame` now carries `run_id`/`fiber_id`/`scope_id`/`resource_id`/
  `type_name`, so live-mode findings/lanes match the identical events loaded as an
  artifact (they diverged before — leak findings could be suppressed live).
- **Protocol**: `parseHubMessage` strictly validates roster/frame payloads (a drifted
  hub can no longer crash the UI); new `gap` message announces backfill truncation.
- **Hub**: register() refreshes liveness (no stop/GC flap on re-register); backfill
  sends `gap` when the ring buffer evicted undelivered frames; empty `layer_name`
  no longer blanks a discovered name; per-client subscription state is capped +
  pruned at GC (still-subscribed clients resume across a service restart); caps on
  distinct services, /ingest body (413), and line bytes; rejected-line counter in
  `/health`; roster broadcasts coalesced per ingest batch.
- **Frontend**: per-service buffers reset on sequence regression (service restart —
  no more two-runs-blended chimera traces) and on `gap` (dropped count surfaced as a
  session warning); the workspace `<Show>` is no longer `keyed` (a keyed Show tore
  down the entire workspace DOM on every live frame); focus re-homes when the
  focused service is GC'd from the roster.

Gates after the round: workbench typecheck clean, 163 tests green, production build
OK; `zig build test` green; E2E re-verified from the real H5 binary through the
hardened hub into the browser (screenshot: rail + drill-down + live finding +
full identity in the inspector; `/health` rejected_lines counting live).

## Notes / decisions to confirm before H2

- Keep the legacy single-service `?live=<collector>` path working as a thin
  back-compat shim (recommended) vs. hard-cut to the hub.
- `service_key` as both identity and display name for MVP (add `service_name`
  only if they diverge).
- Reconnect/buffering policy when a service starts before the hub or the hub
  restarts (buffer-and-retry on the service side, or accept gaps).
