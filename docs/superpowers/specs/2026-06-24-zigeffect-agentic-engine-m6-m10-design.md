# zigeffect Agentic Engine M6-M10 Design

Date: 2026-06-24

## Goal

Turn zigeffect from an agent-observable runtime into an agent-operable runtime:
agents can request bounded interventions, run sandboxed counterfactuals, check
runtime invariants, cross a hardened remote transport boundary, and evaluate
whether their actions improved the causal graph.

## Scope

This design covers five follow-on milestones:

- M6: agent intervention protocol
- M7: counterfactual re-executor
- M8: runtime invariant DSL
- M9: production-style remote socket transport wrapper
- M10: agent eval harness

The implementation remains conservative. Mutation-capable behavior is policy
gated and disabled by default. Runtime evidence is emitted through existing
causal event kinds where possible. New capability goes under `src/` with tests;
no new report-only tools are introduced.

## M6 Agent Intervention Protocol

Add `services/agent_intervention.zig`.

The protocol exposes a bounded action enum:

- `interrupt_fiber`
- `fire_timer`
- `pause_runner`
- `replace_provider`
- `replay_scenario`
- `inject_failure`

Every request is decided by `AgentInterventionPolicy`. The default policy is
record-only: it records `remediation_requested` and `remediation_decided`, but
does not record an applied/effect event. When the master gate is enabled and a
specific action is `auto_approve`, the protocol records `remediation_applied`
and an action-specific causal event such as `fiber_interrupted`, `timer_fired`,
`service_replaced`, `workflow_event_recorded`, or `assertion_recorded`.

## M7 Counterfactual Re-executor

Add `services/counterfactual.zig`.

The re-executor takes a baseline causal trace and an intervention request, then
builds two sandbox stores:

- `before`: the baseline trace replayed into a store for findings
- `after`: the same baseline plus the approved intervention

It returns finding counts, finding delta, structural equivalence, and an
`improved` bit. This is not stack resurrection. It is a deterministic causal
trace fork that proves whether the requested intervention improves graph facts.

## M8 Runtime Invariant DSL

Add `services/causal_invariant.zig`.

The DSL is a Zig-native builder over a fixed set of causal invariants:

- no pending/running fibers after a scope closes
- every acquired resource is finalized
- every suspended fiber resumes, joins, or is interrupted
- no assertion failures

The builder produces a small invariant set and a checker returns structured
violations. This gives agents a way to author and run graph rules without adding
a new language.

## M9 Remote Socket Transport

Extend `cluster/transport.zig` with `RemoteSocketClusterTransport`.

This is a production-style wrapper over the existing socket frame path. It keeps
the local deterministic storage handler but adds the operational envelope needed
before true multi-node work:

- endpoint host/port options
- nonzero pool size validation
- auth preflight before durable submission
- bounded reconnect attempts
- lifecycle metrics and redacted failure reports

It uses `production_socket` as the transport kind until the enum needs a
separate deployed-remote distinction.

## M10 Agent Eval Harness

Add `services/agent_eval.zig`.

The eval harness runs a baseline trace through the counterfactual executor and
then applies an invariant set. A result passes only when:

- the intervention is approved and applied
- findings improve or stay within the expected bound
- no invariant violations remain
- no new critical finding class appears

This turns graph deltas into an agent honesty benchmark: a debugging agent gets
credit for improving the causal graph, not for producing persuasive prose.

## Testing

Each milestone has direct Zig tests and is included in `test/all_test.zig`.

Verification commands:

```bash
cd packages/zigeffect && zig build test-raw
cd packages/zigeffect-zio && zig build test
packages/zigeffect/tools/check_tool_hygiene.sh
git diff --check
```

## Non-goals

- No autonomous source mutation.
- No remote deployment platform.
- No new report-only tools.
- No exact event-id replay guarantee.
- No new invariant language parser.

