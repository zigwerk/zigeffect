# zigeffect Roadmap M64-M67 Design

Date: 2026-06-24

## Context

M60-M63 created deployability seams without embedding external systems in the
deterministic core: a live-engine host bundle, HTTP-shaped discovery responses,
patch-proposal eval artifacts, and provider alert secret injection. The next
slice should keep turning post-M63 frontier bullets into tested host/operator
primitives, still avoiding false claims about a hosted distributed platform.

## M64: Supervised Live Engine Host Loop

`createLiveEngineHost` exposes the apply adapter and command daemon bridge. M64
adds a small supervisor around `host.runCommandDaemon(...)` so a local host can
restart a failed daemon run a bounded number of times, emit lifecycle evidence,
and return aggregate command/apply/frame counters.

This is not an OS process manager. It is the deterministic, testable inner loop
a real host process can call from its own process supervisor.

## M65: Continuous NDJSON Fact Tap

The collector already accepts engine NDJSON via `POST /ingest`. M65 adds a
host-side stream helper that reads engine NDJSON chunks, posts complete lines to
the collector, flushes trailing partial lines, and reports line/ingest/error
counts. This gives the live host a tested continuous fact-tap primitive without
assuming a particular engine process implementation.

## M66: HTTP Discovery Refresh With Caller-Owned Fetcher

M61 added request/response shapes for discovery snapshots. M66 composes them into
a refresh helper that formats the request, calls a caller-owned fetcher, parses
the governed response, and refreshes the in-memory registry. Core still does not
own an HTTP client.

## M67: Provider Alert Retry Reporting

M63 added secret injection for PagerDuty delivery. M67 adds a small retry/report
wrapper so host-owned alert transports can retry transient sink failures and get
a bounded attempts/delivered/failure report. Secret resolution and request bodies
remain transient per attempt.

## Verification

Use focused RED/GREEN tests for each milestone, then the same package gates as
previous slices:

- Bun live attach tests for host supervision and NDJSON fact tapping.
- Zig cluster transport tests for HTTP discovery refresh.
- Zig ops alert tests for provider retry reporting.
- Full workbench, zigeffect, zio, hygiene, diff, and release gates before commit.
