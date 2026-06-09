# zigeffect Causal Scenario Fork Proposals Design

## Context

M5 now has named snapshot manifests, snapshot comparison, replay feasibility,
and deterministic registered-scenario replay. The roadmap still needs a safe
forking boundary. Actual runtime forking is not appropriate yet: causal JSON
artifacts are observations, not executable programs, and the runtime does not
serialize closures, services, resources, fibers, clocks, scheduler state,
external IO, or memory.

This branch adds the honest first fork step: a reviewable scenario fork proposal
artifact. A fork proposal names a baseline snapshot, a registered scenario, and
a proposed fork name. It explains which rerun/compare commands are allowed,
which operations are blocked, and what evidence an agent should inspect next.
It does not execute commands, mutate source, mutate runtime state, or apply a
registry change.

## Goals

- Add `zig build causal-snapshot -- fork-proposal <snapshot> <scenario> <fork>`.
- Accept snapshot names or explicit manifest JSON paths for `<snapshot>`.
- Require `<scenario>` to resolve through `causal_run.scenarioByName`.
- Validate `<fork>` with the existing snapshot-name rules.
- Read the source snapshot manifest and referenced artifact metadata.
- Write JSON and text artifacts with schema
  `zigeffect.causal.scenario-fork-proposal.v1`.
- Include scenario metadata, source snapshot metadata, fork name, proposal
  status, allowed commands, blocked operations, guardrails, and next queries.
- Keep the proposal explicitly non-executing and non-mutating.

## Non-Goals

- No runtime memory forking.
- No arbitrary event-log replay.
- No command execution.
- No source mutation.
- No scenario registry mutation.
- No new database, CockroachDB, RoachGraph, or direct NenDB package dependency.
- No attempt to create a new snapshot manifest from the proposed fork.

## Selected Architecture

Extend `packages/zigeffect/tools/causal_snapshot.zig` again. M5 snapshot,
compare, replay-feasibility, replay execution, and now fork proposal all share
the same snapshot reference resolution and manifest parser. Keeping the proposal
beside those tools preserves a single M5 CLI surface:

```sh
zig build causal-snapshot -- fork-proposal <snapshot> <scenario> <fork>
```

The implementation adds:

- `scenario_fork_proposal_schema =
  "zigeffect.causal.scenario-fork-proposal.v1"`;
- path helpers for JSON/text proposal artifacts:
  `.zig-cache/causal-artifacts/zigeffect-causal-fork-proposal-<snapshot>-<scenario>-<fork>.json`
  and `.txt`;
- `formatScenarioForkProposalJson(...)`;
- `formatScenarioForkProposalText(...)`;
- a CLI subcommand that reads the manifest, formats both artifacts, writes them,
  and prints their paths.

## Artifact Shape

JSON fields:

```json
{
  "schema": "zigeffect.causal.scenario-fork-proposal.v1",
  "schema_version": 1,
  "mode": "registered_scenario_fork_proposal",
  "proposal_status": "draft",
  "approved": false,
  "executed": false,
  "fork_name": "missing-service-fork",
  "source": {
    "manifest": ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-missing-service-baseline.json",
    "snapshot": "missing-service-baseline",
    "artifact": ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json"
  },
  "scenario": {
    "slug": "missing-service-compile-fail",
    "owner": "service_resolution",
    "expectation": "expected_failure",
    "finding_policy": "expected_failure_command_emits_assertion"
  },
  "allowed_commands": [
    "zig build causal-snapshot -- replay-scenario missing-service-baseline missing-service-compile-fail",
    "zig build causal-snapshot -- replay-feasibility missing-service-baseline"
  ],
  "blocked_operations": [
    "runtime memory forking",
    "arbitrary causal event-log replay",
    "source mutation",
    "scenario registry mutation"
  ],
  "guardrails": [
    "Proposal is advisory until reviewed.",
    "Fork proposal does not execute commands.",
    "Use replay output and compare reports before claiming behavior changed."
  ],
  "next_queries": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json snapshot"
  ]
}
```

The text report should mirror the JSON in a scan-friendly format for humans and
agents.

## CLI Behavior

```sh
zig build causal-run -- missing-service-compile-fail
zig build causal-snapshot -- capture missing-service-baseline missing-service-compile-fail
zig build causal-snapshot -- fork-proposal missing-service-baseline missing-service-compile-fail missing-service-fork
```

The command writes:

```text
.zig-cache/causal-artifacts/zigeffect-causal-fork-proposal-missing-service-baseline-missing-service-compile-fail-missing-service-fork.json
.zig-cache/causal-artifacts/zigeffect-causal-fork-proposal-missing-service-baseline-missing-service-compile-fail-missing-service-fork.txt
```

It prints a short summary with those paths and the safe replay command. It exits
nonzero for invalid snapshot names, unknown scenarios, invalid fork names, or
missing manifests/artifacts.

## Relationship To Existing Scenario Proposals

`causal_scenario_proposal.zig` proposes registry coverage from dev-loop
evidence. A scenario fork proposal is different:

- it is snapshot-centered rather than dev-loop-centered;
- it does not propose a new scenario registry entry;
- it does not emit registry patch snippets;
- it prepares a reviewed rerun/compare fork workflow for an existing scenario.

Later work can connect fork proposals to workbench UI, approvals, or richer
scenario variants. This branch only creates the safe proposal artifact.

## Testing

Unit tests should cover:

- stable JSON/text proposal paths;
- JSON includes schema, mode, draft status, approved/executed false, source
  snapshot, scenario metadata, allowed commands, blocked operations, guardrails,
  and next queries;
- text includes the same safety boundary;
- usage lists `fork-proposal`.

CLI verification should cover:

- run the missing-service expected-failure scenario;
- capture `missing-service-baseline`;
- write a fork proposal named `missing-service-fork`;
- confirm both JSON and text artifacts exist;
- confirm JSON contains `registered_scenario_fork_proposal` and
  `"executed": false`.

## Self-Review

- Placeholder scan: no placeholders or unresolved future behavior remain.
- Internal consistency: the artifact is advisory and non-executing everywhere.
- Scope check: this is a single M5 closeout branch, not a runtime fork engine.
- Ambiguity check: "fork" means reviewed rerun/compare proposal, not memory or
  event-log forking.
