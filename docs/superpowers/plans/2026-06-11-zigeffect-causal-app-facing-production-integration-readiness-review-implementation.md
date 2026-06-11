# zigeffect Causal App-Facing Production Integration Readiness Review Implementation Plan

## Branch

`codex/zigeffect-causal-app-facing-production-integration-readiness-review`

## Design Source

`docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-readiness-review-design.md`

## Success Criteria

- A new Zig tool emits
  `zigeffect.causal.app-facing-production-integration-readiness-review.v1`.
- The build exposes
  `zig build causal-app-facing-production-integration-readiness-review`.
- The tool consumes app-facing production integration fixture JSON and writes
  JSON and text readiness-review artifacts.
- `approve` plus complete fixture coverage and required verification commands
  yields `readiness_status=ready`.
- `reject`, unsupported fixture schema, missing source contracts, broken
  authority boundaries, missing fixture coverage, missing required validation
  checks, missing NenDB-only evidence, app mutation enablement, telemetry or
  durable writes, renderer drift, or missing verification commands yields
  `readiness_status=blocked`.
- Schema governance count increases from 83 to 84 and includes the new schema.
- Production hardening backlog records the new readiness review as delivered and
  advances the recommendation to the implementation-proposal branch.
- Docs explain how agents and reviewers should use the readiness review without
  inferring app mutation or live production authority.
- Verification commands pass fresh before the implementation commit.

## TDD Sequence

### Red 1: New Tool Constants And CLI Parsing

Create `packages/zigeffect/tools/causal_app_facing_production_integration_readiness_review.zig`
with tests first:

- schema constant is
  `zigeffect.causal.app-facing-production-integration-readiness-review.v1`;
- source fixture schema is
  `zigeffect.causal.app-facing-production-integration-fixtures.v1`;
- recommendation is
  `start-app-facing-production-integration-implementation-proposal`;
- next branch is
  `codex/zigeffect-causal-app-facing-production-integration-implementation-proposal`;
- all authority booleans are false, including `app_mutation_enabled`;
- `parseOptions` accepts:
  `--from-fixtures fixtures.json approve --reason reviewed --by codex --policy manual-app-facing-production-integration-readiness --verified-command "zig build test" --out-prefix .zig-cache/causal-artifacts/custom-app-facing`;
- `parseOptions` rejects missing fixture paths, non-json fixture paths, missing
  decisions, unknown decisions, and missing reasons.

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_readiness_review.zig
```

Expected red: file or symbols are missing.

### Green 1: Minimal Parser And Constants

Implement constants, `Decision`, `ReadinessStatus`, `CheckStatus`, `Options`,
`parseOptions`, `parseDecision`, and output path derivation.

Re-run the focused test and keep it failing only on later missing behavior.

### Red 2: Ready And Blocked Report Formatting

Add tests using a sample fixture JSON copied down to the fields the tool needs:

- ready approve path contains:
  - schema;
  - `readiness_status=ready`;
  - `ready_for_implementation_proposal=true`;
  - `app_mutation_enabled=false`;
  - next implementation-proposal branch;
  - required check names.
- reject path contains:
  - `readiness_status=blocked`;
  - `ready_for_implementation_proposal=false`.

Expected red: `formatReports` and readiness evaluation are missing.

### Green 2: Readiness Evaluation And Formatters

Implement:

- JSON parser structs with `ignore_unknown_fields`;
- readiness check appender;
- source contract coverage;
- positive fixture coverage;
- integration surface coverage;
- negative fixture coverage;
- validation check coverage;
- NenDB-only durable direction;
- app mutation disabled;
- telemetry/durable disabled;
- SolidJS/webui renderer direction;
- required verification command evidence;
- JSON formatter;
- text formatter.

Keep the output deterministic and close to
`causal_production_telemetry_readiness_review.zig`.

### Red 3: Specific Boundary Failure Cases

Add tests that prove the review blocks:

- source fixture schema mismatch;
- `app_mutation_enabled=true`;
- a positive fixture with `app_mutation_state` other than `disabled-fixture`;
- a positive fixture with live telemetry or durable write state;
- missing required verification commands.

Expected red: failure cases return ready or lack the named failed checks.

### Green 3: Boundary Checks

Tighten `authorityBoundaryIntact`, `appMutationDisabled`,
`telemetryAndDurableDisabled`, and `verifiedCommandsContainAll` until all
focused tests pass.

### Red 4: Build, Schema, And Backlog Wiring

Add failing checks by updating tests in existing files before production edits:

- `causal_schema_governance.zig`
  - schema count expected becomes 84;
  - inventory includes
    `zigeffect.causal.app-facing-production-integration-readiness-review.v1`;
  - text report includes the schema and `readiness-review`;
  - JSON report includes the schema.
- `causal_production_hardening_backlog.zig`
  - recommendation becomes
    `start-app-facing-production-integration-implementation-proposal`;
  - recommended next branch becomes
    `codex/zigeffect-causal-app-facing-production-integration-implementation-proposal`;
  - backlog contains
    `app-facing-production-integration-readiness-review`;
  - dependency order includes it after fixtures;
  - verification commands include the ready and reject readiness-review CLI
    paths.

Expected red under `zig build test`: updated tests fail until code changes are
made.

### Green 4: Wiring

Update:

- `packages/zigeffect/build.zig`
  - create module for the new tool;
  - add executable;
  - add build step;
  - add test artifact to the global test step.
- `packages/zigeffect/tools/causal_schema_governance.zig`
  - add schema entry.
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - update recommendation constants;
  - add backlog item;
  - add dependency order entry;
  - add verification commands.

Run focused tests after this step.

### Red 5: Documentation Expectations

Add or update doc assertions in existing tests only if the project already has
doc-output tests that make this practical. Otherwise treat docs as verified by
content review plus `git diff --check`.

Docs to edit:

- `packages/zigeffect/docs/app-facing-production-integration-readiness-review.md`
- `packages/zigeffect/docs/app-facing-production-integration-fixtures.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/README.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

### Green 5: Documentation

Document:

- command usage;
- expected JSON/text outputs;
- ready vs blocked semantics;
- required verification commands;
- authority boundaries;
- NenDB-only durable direction;
- SolidJS/webui direction;
- next implementation-proposal branch.

## Implementation Notes

- Prefer copying the shape of
  `causal_production_telemetry_readiness_review.zig` rather than inventing a
  new artifact style.
- Keep the parser structs narrow and use `.ignore_unknown_fields = true`.
- Keep required command matching exact, because this artifact is a review
  record, not a fuzzy command classifier.
- Do not execute verification commands inside the tool.
- Keep command output through `std.debug.print` consistent with existing tools.
- Use `readFileAlloc` with a bounded file size.
- Write both JSON and text artifacts.
- All strings remain ASCII.

## Files To Modify

- Add:
  `packages/zigeffect/tools/causal_app_facing_production_integration_readiness_review.zig`
- Modify:
  `packages/zigeffect/build.zig`
- Modify:
  `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify:
  `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Add:
  `packages/zigeffect/docs/app-facing-production-integration-readiness-review.md`
- Modify:
  `packages/zigeffect/docs/app-facing-production-integration-fixtures.md`
- Modify:
  `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify:
  `packages/zigeffect/docs/schema-governance.md`
- Modify:
  `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify:
  `packages/zigeffect/README.md`
- Modify:
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Verification Commands

Focused:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_readiness_review.zig
zig build causal-app-facing-production-integration-fixtures -- --format json
zig build causal-app-facing-production-integration-fixtures -- validate --format json
zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason "fixtures reviewed for implementation proposal" --verified-command "zig build causal-app-facing-production-integration-fixtures -- validate --format json" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json reject --reason "negative readiness path" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-readiness-review-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Full:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Commit Plan

1. Commit the design spec.
2. Commit this implementation plan.
3. Commit implementation, docs, schema, backlog, and roadmap updates after
   verification.

## Next Handoff

After this branch lands, the next branch should be:

`codex/zigeffect-causal-app-facing-production-integration-implementation-proposal`

That branch should consume a ready readiness-review artifact and produce a
proposal-only implementation plan. It must still keep mutation authority,
production telemetry ingestion, live exporters, durable production writes,
Cockroach adapter work, CI gates, and alternate renderer work disabled.
