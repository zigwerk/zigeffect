# zigeffect Live Debugging Browser Proof

Date: 2026-06-24

## Scope

This proof covers milestone M2: engine NDJSON -> Bun collector -> WebSocket ->
workbench live artifact model -> rendered browser view.

The automated coverage proves the first three links:

```bash
bun run zigeffect:workbench:test
```

The collector test named `END-TO-END: REAL engine NDJSON (live_stream_example
output) flows through the collector to a client` replays
`packages/zigeffect/workbench/src/collector/sample-engine-stream.ndjson`, which
was captured from `zig build live-stream-example`, through the real collector
WebSocket path. `liveAttach.test.ts` then proves those frames feed the existing
`deriveWorkbenchModel` pipeline used by the timeline, graph, findings, queries,
and metadata views.

The browser proof below was captured with the Codex in-app browser against the
real Vite workbench and Bun collector. It is intentionally not a fake DOM test:
the page opened `?live=ws://127.0.0.1:4500/live`, then the collector received
fresh engine NDJSON over `POST /ingest`.

## Browser Proof

Terminal 1:

```bash
bun run zigeffect:workbench:dev -- --port 5173
```

Terminal 2:

```bash
PORT=4500 bun packages/zigeffect/workbench/src/collector/collector.ts
```

Terminal 3, after the browser is connected:

```bash
cd packages/zigeffect
zig build live-stream > /tmp/zigeffect-live-proof.ndjson
curl -sS -X POST --data-binary @/tmp/zigeffect-live-proof.ndjson \
  http://127.0.0.1:4500/ingest
```

Browser:

```text
http://127.0.0.1:5173/?live=ws://127.0.0.1:4500/live
```

Observed result on 2026-06-24:

```json
{
  "ingested": 11,
  "hasLiveAttach": true,
  "hasRunStarted": true,
  "hasFiberSuspended": true,
  "hasRunCompleted": true,
  "hasSuccess": true
}
```

Screenshot:

![Live workbench proof](/Users/seanknowles/Desktop/Projects/yachdee/docs/superpowers/specs/2026-06-24-zigeffect-live-debugging-browser-proof.png)

First-viewport evidence:

- The header artifact path is `live-attach`.
- The metric strip shows a non-zero `events` count.
- The Timeline tab lists live engine events such as `run_started`,
  `fiber_started`, `timer_scheduled`, `timer_fired`, `fiber_resumed`, and
  `run_completed`.
- Selecting an event updates the inspector with the same event id, kind, status,
  and generated `causal-query` commands.
- The Graph tab shows parent edges from the same streamed events.

## Evidence Boundary

This is stronger than the static `?sample=` path because the frames arrive
through the collector WebSocket and are rendered by the browser workbench. If the
project later accepts Playwright or a DOM harness in CI, this proof should become
an automated test that opens the URL above, waits for `live-attach`, and asserts
the Timeline DOM contains streamed event kinds and statuses.
