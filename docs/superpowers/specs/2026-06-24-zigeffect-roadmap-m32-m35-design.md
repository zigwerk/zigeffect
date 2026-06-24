# zigeffect Roadmap M32-M35 Design

Date: 2026-06-24

## Context

M28-M31 provided validated command inbox polling, a core poll-batch bridge,
schema governance for the new artifact families, and alert delivery envelopes.
The remaining gap is turning one-shot helpers into repeatable integration
contracts that real daemons/adapters can use later.

## Goals

- Add a bounded command poll loop abstraction over the existing poll batch
  runner.
- Add an eval diff artifact writer sink so dev-loop tools can persist artifacts
  without learning eval internals.
- Add validation for runner deployment metadata before lineage artifacts are
  treated as deployment evidence.
- Add an alert delivery sink over the redacted alert delivery envelope.

## Non-Goals

- No process supervision or background daemon.
- No filesystem writer inside the core eval service.
- No real TLS handshake implementation.
- No external alert provider SDK.

## Milestones

### M32 - Bounded command poll loop

Add a callback-based `CausalLiveCommandPoller` and
`runCausalLiveCommandPollLoop`. The loop is bounded by `max_polls`, aggregates
tap counters, carries the cursor, and stops on an empty batch.

### M33 - Eval diff artifact writer sink

Add `AgentEvalDiffArtifactSink` and `runAgentEvalAndWriteDiffArtifact`, which
emits the same artifact as `runAgentEvalWithDiffArtifact` to a caller-provided
sink.

### M34 - Runner deployment metadata validation

Add validation over runner deployment metadata for required TLS, minimum auth
epoch, required address, and healthy state.

### M35 - Alert delivery sink

Add `CausalOpsAlertDeliverySink` and `deliverCausalOpsAlert`, which formats the
redacted delivery envelope and passes it to a caller-provided sink.

## Acceptance

- Tests prove the poll loop processes multiple batches and stops on empty.
- Tests prove the eval writer sink receives a linked diff artifact.
- Tests prove deployment metadata validation reports TLS/auth/address/health
  issues.
- Tests prove alert delivery sends redacted JSON to the delivery sink.
