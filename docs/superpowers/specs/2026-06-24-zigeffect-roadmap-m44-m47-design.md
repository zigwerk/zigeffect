# zigeffect Roadmap M44-M47 Design

Date: 2026-06-24

## Context

M40-M43 added reusable local harnesses and adapter boundaries. The next slice
adds lifecycle evidence, a real in-memory discovery backend, a manifest for
linked eval artifacts, and HTTP response metadata that real hosts can forward.

## Goals

- Emit local command daemon lifecycle events through a caller-owned callback.
- Add an in-memory service-discovery registry that owns endpoint host strings and
  can select a safe candidate.
- Add a linked eval diff manifest JSON schema that references both the diff
  artifact and the remediation-link artifact.
- Add fixed response headers for ops artifact HTTP responses: content type,
  no-store cache policy, and nosniff.

## Non-Goals

- No process supervisor or hosted daemon.
- No network service-discovery backend.
- No filesystem writes from the Zig core.
- No HTTP server in the Zig core.

## Milestones

### M44 - Daemon lifecycle evidence

Extend `runLiveCommandDaemon` with `onLifecycle` events for start, cycle, error,
and stop.

### M45 - In-memory discovery registry

Add `InMemoryClusterTransportServiceDiscovery`, with owned endpoint storage,
upsert, count, and safe candidate selection.

### M46 - Linked eval manifest

Add `zigeffect.causal.agent-eval-linked-manifest.v1`, with paths for the diff
artifact and link artifact plus remediation ids.

### M47 - Ops HTTP response headers

Attach fixed adapter-facing headers to ops artifact HTTP responses.

## Acceptance

- Tests prove daemon lifecycle events are emitted in order.
- Tests prove discovery upsert replaces an endpoint and selection sees the safe
  candidate.
- Tests prove the linked manifest names both artifacts and remediation ids.
- Tests prove allowed, denied, and method/path error ops responses include
  no-store and JSON content headers.
