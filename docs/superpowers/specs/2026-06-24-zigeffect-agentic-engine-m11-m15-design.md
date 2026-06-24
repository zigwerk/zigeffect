# zigeffect Agentic Engine M11-M15 Design

Date: 2026-06-24

## Goal

Move the agentic runtime from "can observe and score bounded actions" to "can
explain graph deltas, accept policy-gated live commands, expose richer
concurrency facts, harden remote transport policy, and apply ops guardrails."

## Scope

This design covers five follow-on milestones:

- M11: semantic causal graph diffs
- M12: bidirectional live debugging command path
- M13: race/both and STM causal annotations
- M14: remote cluster transport policy hardening
- M15: durable retention and ops hardening

The implementation stays honest and local. It adds runtime capabilities and
tests under `src/`, `test/`, and the workbench collector. It does not claim real
multi-node deployment, browser source mutation, or hosted TLS infrastructure.

## M11 Semantic Causal Graph Diffs

Add `services/causal_diff.zig`.

The diff engine compares two causal traces by semantic facts instead of event
ids. It reports:

- findings resolved and introduced;
- fiber terminal facts added or removed;
- resource finalization facts added or removed;
- lineage and parent/cause edge facts added or removed.

`runCounterfactual` returns this diff, and `runAgentEval` uses it to expose a
structured improvement signal rather than only a finding count.

## M12 Bidirectional Live Debugging

Extend the workbench live transport with a command lane.

The collector accepts `POST /command` requests containing a bounded intervention
request. The collector validates shape, redacts label/detail fields, assigns a
monotonic command sequence, broadcasts a command frame to WebSocket subscribers,
and stores it in memory for tests/status. The browser-side live source can send
commands through an injectable fetcher, so UI code can wire buttons later without
creating a second transport.

The engine remains the policy authority. The collector command path records and
transports command intent; applying a command still goes through
`AgentInterventionPolicy`.

## M13 Race/Both and STM Causal Annotations

Add a small runtime annotation helper under `services/causal_concurrency.zig`.

The helper records graph facts that existing executors and STM can call into:

- race started, winner selected, and loser interrupted;
- both started and both completed;
- STM transaction started, conflict detected, retry scheduled, and committed.

This first implementation provides the event vocabulary and testable recording
surface without threading causal stores through every effect interpreter call in
one large edit.

## M14 Remote Cluster Transport Policy Hardening

Extend `RemoteSocketClusterTransport` with production-policy fields:

- TLS policy metadata with rotation epoch and pinned fingerprint;
- connection-pool limits with idle timeout and health-check interval;
- backpressure strategy with reject/drop/block semantics;
- cross-runner causal lineage via `origin_causal_event_id`.

The transport validates these policies at init/preflight and records operational
metrics. This is still a local socket wrapper; real TLS handshakes and deployed
multi-node service discovery are not claimed.

## M15 Durable Retention and Ops Hardening

Add `services/causal_ops.zig`.

The ops helper provides reusable runtime policy checks for causal artifacts:

- deployment metadata validation;
- access-control checks for actor/scope reads;
- retention limit decisions;
- alert emission as causal facts when thresholds are breached.

This gives future storage backends a tested policy core without introducing new
report-only tools.

## Testing

Each milestone has direct tests and is imported from `test/all_test.zig`.

Verification commands:

```bash
cd packages/zigeffect && zig build test-raw
cd packages/zigeffect-zio && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
packages/zigeffect/tools/check_tool_hygiene.sh
git diff --check
```

## Non-goals

- No autonomous source mutation.
- No real deployed TLS handshake.
- No hosted multi-runner platform.
- No browser UI controls beyond command transport primitives.
- No new `tools/` files.
