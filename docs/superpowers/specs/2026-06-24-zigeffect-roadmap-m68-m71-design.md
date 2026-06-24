# zigeffect Roadmap M68-M71 Design

Date: 2026-06-24

## Context

M64-M67 gave the live host and discovery/alert paths bounded inner loops. The
next slice adds host-facing request/runtime composition and makes discovery more
rotation-aware while still avoiding a fake deployment platform.

## M68: Live Engine Host Request Router

Add a small `Request` router for host processes. It should route a configured
apply path to `host.handleApplyRequest(request)`, expose a JSON health endpoint,
and reject unknown paths/methods with fixed JSON/no-store/nosniff headers.

This is not `Bun.serve`; it is the handler a real local host server can pass to
whatever process/runtime owns the socket.

## M69: Live Engine Host Runtime Runner

Compose the supervised command loop and optional NDJSON fact tap in one helper.
A host can call it with a `LiveEngineHost`, command inbox URL, optional NDJSON
stream, and collector ingest URL. The helper runs the available pieces and
returns their reports.

This still does not own OS process lifecycle; it is the tested inner runtime
runner a process manager can call.

## M70: Bounded HTTP Discovery Refresh Loop

Compose the caller-owned HTTP discovery fetcher into a bounded loop with failure
accounting. The loop should stop once a selected endpoint exists when configured
to do so, or after a fixed refresh count.

## M71: Freshest Auth-Epoch Discovery Selection

Add an auth-rotation-aware selector that chooses the safe endpoint with the
highest auth epoch rather than simply the first safe endpoint. Keep the original
first-safe selector for stable behavior where ordering is intentional.

## Verification

- Bun live attach tests for the host router and runtime runner.
- Zig cluster transport tests for bounded refresh loops and freshest auth-epoch
  selection.
- Full workbench, zigeffect, zio, hygiene, diff, and release gates before commit.
