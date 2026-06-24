# zigeffect Roadmap M40-M43 Design

Date: 2026-06-24

## Context

M36-M39 added adapter-facing contracts, but each still requires caller glue. The
next slice should turn those contracts into reusable local harnesses without
pretending there is a hosted distributed platform.

## Goals

- Add a local command daemon harness in TypeScript that repeatedly calls the
  command polling loop until stopped or a cycle budget is exhausted.
- Compose eval diff artifact writing with remediation-link writing so dev-loop
  callers can persist both artifacts through caller-owned sinks.
- Select safe service-discovery endpoints after validation.
- Add an HTTP request adapter for ops artifact reads that handles method/path
  checks before delegating to the policy-gated status/body formatter.

## Non-Goals

- No process supervisor, background service manager, or hosted daemon.
- No filesystem writes from the Zig core.
- No service-discovery backend or connection-pool implementation.
- No HTTP server in the Zig core.

## Milestones

### M40 - Local command daemon harness

Add `runLiveCommandDaemon` in local workbench tooling. It repeatedly invokes
`runLiveCommandPollingLoop`, awaits a caller-owned delay hook between non-empty
cycles, stops when a caller-owned stop signal returns true, and counts handler
errors.

### M41 - Linked eval diff artifact writer

Add `runAgentEvalAndWriteLinkedDiffArtifact`, which writes the eval diff artifact
and a separate remediation-link JSON artifact to caller-provided sinks.

### M42 - Service-discovery endpoint selection

Add `selectClusterTransportServiceDiscoveryEndpoint`, returning the first safe
endpoint plus the validation report.

### M43 - Ops artifact HTTP request adapter

Add `serveCausalOpsArtifactHttpRequest`, which rejects non-GET requests and
wrong paths, then delegates valid requests to
`formatCausalOpsArtifactHttpResponse`.

## Acceptance

- Tests prove the daemon harness advances cursors across cycles and stops via a
  stop signal.
- Tests prove the linked eval writer emits both schemas and remediation ids.
- Tests prove endpoint selection skips unsafe candidates and returns none when
  validation fails.
- Tests prove the ops adapter returns 405, 404, 403, and 200 in the appropriate
  cases.
