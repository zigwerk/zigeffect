# zigeffect Causal Scenario Registry Patch Design

Date: 2026-06-07

## Purpose

`zig build causal-scenario-proposal -- local [scenario]` now tells agents when
causal evidence should become reviewed scenario or invariant coverage. The next
step is to make that recommendation easier to act on without letting a causal
tool mutate source.

This design adds a review-only registry patch generator. It reads an existing
scenario proposal artifact and writes three artifacts: a machine-readable JSON
record, a human text review report, and a `.zig` snippet that a reviewer can
copy into `tools/causal_run.zig` after checking the command, invariant ids, and
scenario policy.

## Safety Boundary

The command never edits `tools/causal_run.zig`, never changes the scenario
registry, never updates docs, and never claims new regression coverage. It only
generates review artifacts. Registry changes become real only after a reviewer
manually applies the snippet or a later policy-controlled tool explicitly
performs that mutation.

## Command

```sh
zig build causal-scenario-registry-patch -- --from-proposal <scenario-proposal.json>
```

The command accepts any local proposal path ending in
`-scenario-proposal.json`. Output paths are derived by replacing that suffix
with `-registry-patch.json`, `-registry-patch.txt`, and
`-registry-patch.zig`.

Examples:

```sh
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json
```

## Inputs

The input proposal schema is `zigeffect.causal.scenario-proposal.v1`. The
generator reads:

- `recommendation`;
- `reason`;
- `source`;
- `evidence`;
- `proposed_scenario`;
- `proposed_invariants`;
- `review_checklist`;
- `guardrails`.

The generator also consults `causal_run.scenarioRegistry()` and
`causal_run.invariantCatalog()` to detect slug conflicts and known invariant
ids.

## Outputs

Schema id:

```text
zigeffect.causal.registry-patch.v1
```

JSON fields:

- `schema`
- `schema_version`
- `source_proposal`
- `recommendation`
- `patch_status`
- `target`
- `scenario_slug`
- `scenario_conflict`
- `known_invariant_ids`
- `new_invariant_ids`
- `scenario_entry`
- `argv_constants`
- `invariant_entries`
- `review_checklist`
- `guardrails`

Text report starts with:

```text
zigeffect causal scenario registry patch
schema: zigeffect.causal.registry-patch.v1
source proposal: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json
recommendation: add-scenario
patch_status: review-required
```

The `.zig` snippet contains copy-paste ready constants and scenario entries,
with comments that cite the source proposal and warn reviewers to replace the
placeholder argv with the smallest reproducing command.

## Recommendation Handling

### `add-scenario`

The generator writes:

- invariant id constants;
- argv constants with a conservative placeholder command;
- a scenario registry entry matching the proposal's slug, label, owner,
  expectation, finding policy, and purpose;
- invariant catalog snippets only for proposed invariant ids that do not exist
  in `causal_run.invariantCatalog()`.

If the proposed slug already exists, the JSON and text reports set
`scenario_conflict=true` and the `.zig` snippet is still emitted as a review
draft. The text report must tell the reviewer to resolve the conflict before
applying the patch.

### `refine-scenario`

The generator writes a review report and `.zig` comments for the existing
scenario. It does not attempt to rewrite the existing registry entry. The
snippet includes suggested invariant ids and argv guidance so a reviewer can
apply a targeted edit manually.

### `none`

The generator writes a no-op registry patch report with `patch_status=no-op`
and no scenario or invariant snippets. This lets agents run the command in a
fixed chain without turning clear evidence into speculative source changes.

## Formatting Rules

Generated identifiers derive from the scenario slug:

- non-alphanumeric characters become underscores;
- repeated underscores collapse;
- leading digits are prefixed with `scenario_`;
- suffixes are `_invariants` and `_argv`.

Generated enum values must preserve existing registry spelling:

- owner: `.command_harness`, `.service_resolution`, `.scope_lifecycle`,
  `.fiber_runtime`, `.schedule_retry`, or `.package`;
- expectation: `.expected_pass` or `.expected_failure`;
- finding policy: `.none_when_command_passes`,
  `.failure_artifact_on_command_failure`, or
  `.expected_failure_command_emits_assertion`.

The placeholder argv for new scenarios is:

```zig
const learned_example_argv: []const []const u8 = &.{
    "zig",
    "build",
    "examples",
};
```

The text and snippet both require the reviewer to replace that placeholder with
the smallest reproducing command before applying the registry change.

## Validation

The command validates:

- exactly one `--from-proposal <path>` argument is present;
- the proposal path ends in `-scenario-proposal.json`;
- proposal schema is `zigeffect.causal.scenario-proposal.v1`;
- proposal schema version is `1`;
- recommendation is `add-scenario`, `refine-scenario`, or `none`;
- `add-scenario` and `refine-scenario` proposals include
  `proposed_scenario`;
- owner, expectation, and finding policy map to known registry enum values;
- proposed invariant ids are non-empty strings.

## Acceptance Criteria

- `zig build causal-scenario-registry-patch -- --from-proposal <default proposal>`
  writes deterministic JSON, text, and Zig snippet artifacts.
- Scenario-specific proposal paths write scenario-specific registry patch
  artifacts.
- `add-scenario` proposals produce scenario entry and argv snippets.
- Known invariant ids are listed as known, not duplicated as new invariant
  catalog entries.
- `refine-scenario` proposals produce review guidance without rewriting an
  existing registry entry.
- `none` proposals produce a no-op report and no registry snippet.
- `zig build causal-artifacts` lists default and scenario registry patch
  artifact paths.
- README, agent guide, scenario docs, and roadmaps document the command.
- The command never edits source.

## Future Direction

A later policy-controlled tool can consume
`zigeffect.causal.registry-patch.v1`, verify reviewer approval, and apply a
registry mutation. That future tool should reuse this artifact rather than
re-parsing scenario proposal evidence from scratch.
