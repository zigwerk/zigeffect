# zigeffect Causal App-Facing Fourteen-Level Report Implementation Plan

## Milestone

Implement `causal-app-facing-fourteen-level-report` as the next sequential ladder step after `causal-app-facing-thirteen-level-evaluator`.

## Tasks

1. Add the RED test shell for `packages/zigeffect/tools/causal_app_facing_fourteen_level_report.zig`.
   - Verify the missing constants failure.

2. Promote the thirteen-level report implementation.
   - Update constants, aliases, default paths, usage text, reviewed-by defaults, and tests from thirteen-level report to fourteen-level report.
   - Consume thirteen-level evaluator artifacts and output fourteen-level report artifacts.

3. Preserve direct thirteen-level source evidence.
   - Add direct `source_thirteen_level_evaluator`, policy, application-boundary, report, digest, and application-change fields.
   - Keep twelve-level evaluator and lower lineage carryover visible.
   - Gate readiness on thirteen-level source evidence and the inherited lineage.

4. Update local documentation.
   - Add `packages/zigeffect/docs/app-facing-fourteen-level-report.md`.
   - Document usage, status rules, generated artifact paths, and disabled authority posture.

5. Wire build and governance surfaces.
   - Add the `causal-app-facing-fourteen-level-report` build target and unit test target.
   - Add the schema governance registry entry and increment expected schema count.
   - Update governance tests.

6. Update production backlog and roadmap.
   - Mark `app-facing-fourteen-level-report` delivered.
   - Update the recommended next branch to `codex/zigeffect-causal-app-facing-fourteen-level-application-boundary`.
   - Add ready/advisory/blocked fourteen-level report commands.
   - Update roadmap item 118 as delivered and add item 119 for the fourteen-level application boundary.

7. Generate artifacts and verify.
   - Emit ready, advisory, and blocked fourteen-level report artifacts from thirteen-level evaluator artifacts.
   - Run targeted Zig tests, build target help, governance/backlog tests, examples, package tests, root Bun checks, and `git diff --check`.

8. Finish branch hygiene.
   - Commit the milestone.
   - Fast-forward local `master`.
   - Create `codex/zigeffect-causal-app-facing-fourteen-level-application-boundary` for the next milestone.

## Verification Commands

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_fourteen_level_report.zig
zig build causal-app-facing-fourteen-level-report -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
