# zigeffect Causal Registry Application Readiness Design

Date: 2026-06-07

## Purpose

`zig build causal-scenario-registry-patch -- --from-proposal <path>` now turns
scenario learning evidence into review-only registry patch drafts. The next
missing boundary is not source mutation. It is an auditable gate that tells an
agent whether a reviewed registry patch is actually ready to be applied or has
already been applied manually and verified.

This design adds a policy-controlled readiness tool. It consumes
`zigeffect.causal.registry-patch.v1`, records an explicit reviewer decision,
checks the current registry and docs for the review conditions that must be
true, and writes JSON/text readiness reports. It does not edit
`tools/causal_run.zig`, does not edit docs, does not run arbitrary shell
commands, and does not claim coverage unless the readiness checks prove it.

## Safety Boundary

The command is still non-mutating. Its strongest positive result is
`readiness_status=applicable`, meaning "a reviewer-approved registry change has
enough evidence to apply manually or to hand to a future guarded mutation
backend." It never writes source and it keeps `applied=false`.

If the registry patch is generated but the source registry has not been updated,
the command reports `readiness_status=blocked`. This is intentional: generated
Zig snippets are drafts, not coverage.

## Command

```sh
zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> approve --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]...
zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> reject --reason <reason> [--by <actor>] [--policy <policy>]
```

The command accepts paths ending in `-registry-patch.json`. Output paths are
derived by replacing that suffix with
`-registry-application-readiness.json` and
`-registry-application-readiness.txt`.

Examples:

```sh
zig build causal-registry-application-readiness -- --from-registry-patch .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json approve --reason "reviewed registry entry and docs" --verified-command "zig build causal-run learned-dogfood-service-resolution" --verified-command "zig build examples"
zig build causal-registry-application-readiness -- --from-registry-patch .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json reject --reason "no scenario change needed"
```

## Inputs

The primary input schema is `zigeffect.causal.registry-patch.v1`. The readiness
tool reads:

- `recommendation`;
- `patch_status`;
- `target`;
- `scenario_slug`;
- `scenario_conflict`;
- `known_invariant_ids`;
- `new_invariant_ids`;
- `review_checklist`;
- `guardrails`.

The tool also consults:

- `causal_run.scenarioByName()` to verify the scenario exists when a patch is
  being marked applicable;
- `causal_run.invariantById()` to verify every known and new invariant id is
  present in the current catalog;
- the current scenario entry's `argv` to reject the generated placeholder
  command `zig build examples`;
- `packages/zigeffect/docs/causal-scenarios.md` to verify documentation mentions
  the scenario slug.

Reviewer intent comes from command-line decision fields:

- decision: `approve` or `reject`;
- reviewer: `--by`, default `local-reviewer`;
- policy: `--policy`, default `manual-review`;
- reason: required for both approval and rejection;
- verified commands: repeated `--verified-command <command>` values.

## Outputs

Schema id:

```text
zigeffect.causal.registry-application-readiness.v1
```

JSON fields:

- `schema`
- `schema_version`
- `source_registry_patch`
- `decision`
- `readiness_status`
- `decided_by`
- `policy`
- `reason`
- `applied`
- `target`
- `scenario_slug`
- `checks`
- `required_verification_commands`
- `verified_commands`
- `guardrails`

Text report starts with:

```text
zigeffect causal registry application readiness
schema: zigeffect.causal.registry-application-readiness.v1
source registry patch: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json
decision: approve
readiness_status: blocked
```

## Readiness Status

### `applicable`

Only approval can produce `applicable`. All checks must pass:

- registry patch schema is `zigeffect.causal.registry-patch.v1`;
- patch status is `review-required`;
- recommendation is `add-scenario` or `refine-scenario`;
- reviewer supplied a non-empty reason;
- scenario slug is non-empty and exists in the current compiled registry;
- current scenario argv is not the generator placeholder `zig build examples`;
- every invariant id listed by the patch exists in the current invariant
  catalog;
- docs contain the scenario slug;
- verified commands include `zig build examples` and the scenario-specific
  causal run command.

The status means "ready for manual application or guarded application." It does
not mean the tool applied anything.

### `blocked`

`blocked` is used when a reviewer approved the patch but one or more checks
failed, or when the reviewer explicitly rejected the patch. The report lists
each failed check and its reason.

### `not-applicable`

`not-applicable` is used for no-op registry patches. A no-op remains useful in
the chain because it proves the agent looked at the proposal and did not turn
clear evidence into speculative coverage.

## Checks

Each check is reported as:

```json
{
  "name": "scenario-present",
  "status": "pass",
  "detail": "scenario exists in causal_run registry"
}
```

Check names:

- `registry-patch-schema`
- `reviewer-decision`
- `patch-status`
- `scenario-present`
- `scenario-conflict`
- `placeholder-argv-replaced`
- `invariant-catalog-consistent`
- `scenario-docs-updated`
- `required-verification-recorded`

## Required Verification Commands

For a scenario slug `learned-example`, the report requires:

```sh
zig build causal-run learned-example
zig build examples
zig build test --summary none
```

The tool records these commands and whether the reviewer supplied matching
`--verified-command` values. It does not run them. This keeps the readiness gate
deterministic and prevents a policy artifact generator from becoming an
unbounded shell executor.

## Acceptance Criteria

- `zig build causal-registry-application-readiness -- --from-registry-patch <path> approve --reason <reason>` writes deterministic JSON/text readiness artifacts.
- Rejection writes a blocked report with reviewer, policy, reason, and
  `applied=false`.
- No-op registry patches write `readiness_status=not-applicable`.
- Approved add/refine registry patches are blocked until the current compiled
  registry contains the scenario.
- Approved patches are blocked when the current scenario argv is still the
  generated placeholder.
- Approved patches are blocked when invariant ids are absent from the current
  catalog.
- Approved patches are blocked when `docs/causal-scenarios.md` does not mention
  the scenario slug.
- Approved patches are blocked unless required verification commands are
  recorded.
- `causal-artifacts` lists default and scenario readiness artifact paths.
- README, agent guide, scenario docs, and roadmaps describe the new readiness
  gate.
- The command never edits source and always emits `applied=false`.

## Future Direction

A future guarded mutation backend can consume
`zigeffect.causal.registry-application-readiness.v1` and require
`readiness_status=applicable` before attempting source edits. That backend
should still write a separate application artifact rather than changing this
readiness schema into a mutation schema.
