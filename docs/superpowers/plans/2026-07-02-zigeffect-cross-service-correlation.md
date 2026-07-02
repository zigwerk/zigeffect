# Plan: cross-service correlation + multi-host + hub persistence

Design: `docs/superpowers/specs/2026-07-02-zigeffect-cross-service-correlation-design.md`

**Status (2026-07-02): H7–H9 implemented and E2E-verified.** The delegated
H7a agent stalled silently (transcript died mid-turn with no notification —
its work was taken over inline). E2E proof, all from the real example binary:
`/services` 401 without the token and full roster with it; `/correlate?boundary=7`
returned both sides (payments-api `effect_started #4` ↔ ledger `scope_opened #2`);
in-browser the inspector's Boundary section jumped payments-api → ledger with
focus + selection following; SIGTERM wrote the snapshot and a cold restart
restored both services (`stopped`, full frames, boundary index intact) with the
browser rendering the restored traces. Adversarial review + commit tracked as H10.

- **H7a — Zig boundary_id.** `CausalEvent.boundary_id: ?u64` (plain value — no
  clone/free work), `CausalStore.nextBoundaryId()`, emission in
  `formatCausalJsonLine` + saved artifact JSON, and the example update:
  payments-api `effect_started "post ledger entry"` + ledger
  `scope_opened "post entry"` share one boundary id. Tests: services_test
  (generator + snapshot), jsonl backend row, example line counts + shared id
  assertion. Verify `zig build test`.
- **H7b — hub boundary index + /correlate.** Bounded map (maxBoundaries 4096,
  32 occurrences/id), pruned when a service is GC'd; `GET /correlate?boundary=`
  returns `{boundary_id, occurrences}`. CORS header on all responses. Tests:
  index across services, cap behavior, GC pruning, endpoint shape.
- **H7c — workbench correlation.** `boundary_id` through LiveFrame →
  frameToEventRecord → `boundaryId` in normalizeEvent; App fetches
  `/correlate` (derived from the `?hub=` URL) when the selected event has a
  boundary id; Inspector "Boundary" section with jump links using the existing
  promote semantics (focusService + select). Tests: passthrough, URL
  derivation, source-assertion UI test.
- **H8 — multi-host + auth.** `HUB_HOST`; `HUB_TOKEN` enforced (timing-safe) on
  HTTP (Bearer) and WS/browser GET (`?token=`). Tests: 401 paths, token via
  both carriers, open behavior when unset.
- **H9 — persistence.** `HUB_PERSIST` snapshot save (debounced in tick +
  SIGINT/SIGTERM, atomic tmp+rename) and restore (services `stopped`,
  sequences continue, boundary index restored; bad/mismatched snapshot →
  empty + log). Tests: save/restore round-trip via injected clock, sequence
  continuity, corrupt-file fallback.
- **H10 — verify + review + ship.** ✅ Done (2026-07-02). A 13-agent adversarial
  review (auth-bypass, persistence, correlation, zig-wire; per-finding
  refutation) confirmed 9 findings — persistence came out clean — all fixed:
  - Empty-string `HUB_TOKEN` looked enabled but was bypassable via `?token=`
    (empty value) → `createHub` throws on an empty token and the bootstrap
    refuses to start (verified: exit 1 with a clear message).
  - Boundary occurrences outlived their frames (ring eviction / restarts) →
    occurrences record their hub sequence and `correlate()` lazily prunes
    below each service's ring floor; the client buffer cap was raised to match
    hub retention (5000) so backfilled jump targets aren't evicted client-side.
  - Stale previous-boundary links flashed during refetch → inspector hides
    occurrences while the resource is loading.
  - `/correlate` with a missing/empty param coerced to boundary 0 → 400
    (boundary 0 itself stays queryable).
  - The correlation resource never refetched for late-arriving occurrences →
    source re-keys on selection identity, focus, and a `boundaryActivity`
    signal (bumped only by boundary-tagged frames — cheap).
  - `boundary_id` was missing from the NenDB properties, OTel attributes, and
    DOT tooltips; the saved-artifact emission had no test guard → all four
    added.
  Final gates: 184 workbench tests + typecheck + build green; `zig build test`
  exit 0.
