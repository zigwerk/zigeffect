# zigeffect Roadmap M36-M39 Design

Date: 2026-06-24

## Context

M32-M35 added callback loops and sinks. The next step is to make those contracts
usable from local tooling and operator boundaries without claiming a hosted
platform exists.

## Goals

- Add an async command polling loop in local TypeScript tooling over
  `fetchLiveCommands`.
- Add an eval diff artifact link JSON shape for remediation-chain cross-links.
- Add validation for discovered remote transport endpoints before pool use.
- Add an HTTP-shaped ops artifact response wrapper over the existing policy
  formatter.

## Non-Goals

- No background process supervisor.
- No actual service discovery backend.
- No hosted HTTP server inside the core service.
- No direct filesystem writes from the core.

## Milestones

### M36 - Local command polling loop

Add `runLiveCommandPollingLoop` in the workbench live attach module. It repeatedly
fetches inbox batches, calls a caller-provided handler, advances the cursor, and
stops on empty or `maxPolls`.

### M37 - Eval diff artifact link

Add `formatAgentEvalDiffArtifactLinkJson` so remediation chains can reference a
persisted eval diff artifact by path/id plus remediation event ids.

### M38 - Service discovery endpoint validation

Add validation for discovered remote transport endpoints: host, port, TLS, health,
and auth epoch.

### M39 - HTTP-shaped ops artifact response

Add an HTTP-shaped response wrapper that returns status + redacted body using the
existing `formatCausalOpsArtifactResponseJson`.

## Acceptance

- Tests prove the polling loop advances cursors, handles multiple batches, and
  stops on empty.
- Tests prove eval artifact links include path and remediation ids.
- Tests prove endpoint discovery validation reports missing TLS/health/auth
  problems.
- Tests prove allowed ops artifact responses return 200 and denied responses
  return 403 without event bodies.
