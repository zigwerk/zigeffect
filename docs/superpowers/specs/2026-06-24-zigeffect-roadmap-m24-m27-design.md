# zigeffect Roadmap M24-M27 Design

Date: 2026-06-24

## Context

M20-M23 made the agent-operable substrate real inside local boundaries:
command batches can be applied through the engine policy gate, semantic diffs can
be emitted and rendered, alerts can leave the causal store, and runner traces can
be stitched by cross-runner cause ids.

The next frontier should connect those pieces without jumping straight to a
hosted distributed platform. The design here keeps every new API small,
deterministic, and testable.

## Goals

- Add a network-facing command inbox to the Bun collector so a running engine can
  poll command frames produced by `POST /command`.
- Add an eval artifact path that emits the portable semantic diff JSON and links
  it to remediation event ids.
- Add an access-controlled operator artifact JSON response over the existing
  NenDB-backed ops read policy.
- Add deployment metadata to stitched runner lineage artifacts so cross-runner
  causal edges can be reviewed in deployment context.

## Non-Goals

- No long-lived engine process manager.
- No TLS/socket client in Zig yet.
- No external PagerDuty/Slack/email delivery.
- No hosted access-control server.

Those remain later milestones; this slice builds the contracts they will use.

## Milestones

### M24 - Collector command inbox

Add a small command history inside `createCollector()` and expose:

- `commandsSince(afterSequence)`
- `GET /commands?after=<sequence>`

The response is a bounded JSON shape suitable for an engine tap poller:

```json
{
  "commands": [],
  "next_after": 0
}
```

### M25 - Eval diff artifact

Add `runAgentEvalWithDiffArtifact`, returning the existing eval result plus a
JSON artifact:

- schema `zigeffect.causal.agent-eval-diff.v1`
- eval name and pass/fail state
- remediation event ids from the intervention chain
- embedded `zigeffect.causal.semantic-diff.v1` object

### M26 - Ops artifact endpoint response

Add a formatter over `readCausalOpsArtifact`:

- schema `zigeffect.causal.ops-artifact-response.v1`
- allowed/denied result
- reason and event count
- a small redacted event list when access is allowed

### M27 - Deployed runner lineage artifact

Add a runner lineage JSON formatter with deployment metadata:

- schema `zigeffect.causal.runner-lineage.v1`
- deployment id
- runner metadata with region/service/environment/address/health/auth epoch
- cross-runner lineage edges

## Acceptance

- Collector tests prove posted commands can be polled by sequence.
- Zig tests prove eval artifact JSON embeds semantic diff and remediation links.
- Zig tests prove denied ops responses do not include events and allowed
  responses redact sentinel secrets.
- Zig tests prove runner lineage JSON includes deployment metadata and
  cross-runner edges.
- Roadmap and future-agent briefing are updated as work lands.
