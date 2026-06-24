# zigeffect Roadmap M52-M55 Design

Date: 2026-06-24

## Context

M48-M51 added local adapter seams: a live engine command daemon bridge, discovery
snapshot refresh, a linked eval manifest writer, and webhook request shapes for
ops alerts. M52-M55 should turn those seams into concrete host-process and
provider-facing contracts while preserving the deterministic core boundary.

## Milestones

### M52 — HTTP live-engine bridge and frame ingest

Add a TypeScript HTTP bridge factory that implements `LiveCommandEngineBridge`.
It posts command inbox batches to a caller-owned engine apply endpoint, validates
the returned tap counters and `LiveFrame`s, and can post returned frames to a
collector frame-ingest endpoint. Add `POST /frames` to the Bun collector for
already-mapped `LiveFrame` payloads so a running engine host can stream facts
without going through NDJSON when it already owns the mapping.

### M53 — Service-discovery snapshot JSON adapter

Add a deterministic JSON adapter for external service-discovery snapshots. It
parses `zigeffect.cluster.service-discovery-snapshot.v1` into an owned snapshot
that can be refreshed into `InMemoryClusterTransportServiceDiscovery`, with
owned endpoint hosts and explicit deinit.

### M54 — Dev-loop linked eval artifact persistence

Wire the real `causal_loop` tool to persist a built-in, bounded eval artifact set
during the `after` phase: diff artifact, remediation link, and linked manifest.
This uses the M50 writer and writes to the existing causal artifact directory.
It is a dev-loop smoke eval, not a claim that user remediation was applied.

### M55 — Operator runbook endpoint metadata

Extend the ops runbook artifact with optional operator endpoint metadata:
artifact endpoint path, alert delivery kind, and alert endpoint id. This lets
runbooks generated from live deployments describe which hosted artifact endpoint
and alert provider seam operators should use.

## Testing

- M52: Bun tests cover the HTTP bridge client and collector `POST /frames`
  broadcast path.
- M53: Zig test parses snapshot JSON, refreshes the registry, and selects the
  safe endpoint.
- M54: Zig tool test writes the dev-loop eval diff/link/manifest artifacts and
  verifies the manifest schema and paths.
- M55: Zig test verifies runbook JSON includes endpoint metadata while retaining
  existing redaction behavior.

## Documentation

Update the roadmap and future-agent briefing to M55 and keep remaining frontier
wording focused on real providers/processes, not local seams that now exist.
