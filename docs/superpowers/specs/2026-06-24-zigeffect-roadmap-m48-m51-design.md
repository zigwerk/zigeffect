# zigeffect Roadmap M48-M51 Design

Date: 2026-06-24

## Context

M0-M47 hardened the causal engine through local daemon lifecycle evidence,
service-discovery selection, linked eval diff manifests, and ops HTTP response
headers. The next deeper-work slice should connect those pieces without claiming
a hosted distributed platform exists.

## Milestones

### M48 — Live engine command daemon bridge

Add a local TypeScript harness that composes `runLiveCommandDaemon` with a
caller-owned engine bridge. The bridge receives sanitized command inbox batches,
applies them through whatever real engine poll bridge the host process owns, and
returns tap counters plus engine-produced `LiveFrame`s. The harness aggregates
processed/applied/rejected/human-review counts and forwards returned frames to a
caller-owned emitter for the workbench live stream.

This keeps the boundary honest: `workbench/src/liveAttach.ts` does not import
or execute Zig. It wires the local collector polling loop to an explicit engine
adapter supplied by the process that is actually running the engine.

### M49 — External service-discovery snapshot ingestion

Extend `InMemoryClusterTransportServiceDiscovery` with a snapshot refresh method
that accepts externally discovered endpoints as data. The method upserts owned
endpoint hosts into the existing registry, runs the same validation/selection
logic, and returns a refresh report with source metadata, imported count,
registry size, and selection.

This is the first honest external-backend boundary: Consul/DNS/Kubernetes/etc.
can provide snapshots later, but the core only needs a deterministic snapshot
shape and validation result today.

### M50 — Linked eval artifact manifest writer

Add a single helper that runs an agent eval, writes the eval diff artifact,
writes the remediation link artifact, and writes the linked manifest through
caller-provided sinks. This turns M41/M46 into one atomic persistence path that
dev-loop/remediation tools can call without duplicating artifact ordering logic.

The helper does not write files directly. It accepts sinks, so tools can persist
to `.zig-cache`, tests can capture memory, and the core stays filesystem-free.

### M51 — Ops alert webhook request adapter

Add an adapter-ready alert webhook request formatter plus a sink delivery
helper. It should produce a `POST` request shape with fixed JSON/no-store/
nosniff headers and a redacted `ops-alert-delivery.v1` body, then hand it to a
caller-owned HTTP sink.

This is an external-provider integration seam, not an embedded HTTP client.
Network IO remains outside the deterministic core.

## Testing

- M48: Bun unit test with fake collector batches and a fake engine bridge. The
  test must prove command batches are applied, returned frames are emitted, and
  aggregate tap counts survive.
- M49: Zig test that refreshes an in-memory discovery registry from an external
  snapshot containing unsafe and safe endpoints, then verifies owned selection
  and source metadata.
- M50: Zig test that captures three sink writes and verifies diff, link, and
  manifest schemas/paths are all emitted from one eval call.
- M51: Zig test that captures a webhook request and verifies method, endpoint,
  fixed headers, schema body, and sentinel redaction.

## Documentation

Update `packages/zigeffect/docs/roadmap.md`,
`docs/superpowers/2026-06-24-future-agent-briefing.md`, and stale live-attach
comments while touching the path.
