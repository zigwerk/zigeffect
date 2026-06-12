# zigeffect causal app-facing thirteen-level application boundary implementation plan

## Goal

Deliver the next local-only, guarded application-boundary artifact for the
thirteen-level app-facing report and hand off to the thirteen-level policy
branch.

## Steps

1. Confirm branch and merge state.
   - Keep `master` fast-forwarded through the thirteen-level report.
   - Continue work on
     `codex/zigeffect-causal-app-facing-thirteen-level-application-boundary`.

2. Add RED test coverage.
   - Create
     `packages/zigeffect/tools/causal_app_facing_thirteen_level_application_boundary.zig`
     with a constants test before implementation exists.
   - Run
     `zig test tools/causal_app_facing_thirteen_level_application_boundary.zig`
     and confirm the expected compile failure.

3. Implement the boundary tool.
   - Adapt the twelve-level application boundary.
   - Update schema, generator, branch, recommendation, source suffix, output
     suffix, reviewer default, and policy default.
   - Add thirteen-level source report fields.
   - Preserve direct twelve-level evaluator, policy, application boundary,
     report, after digest, after-present flag, and application changes.
   - Preserve eleven-level, ten-level, and nine-level lineage.
   - Require thirteen-level report generator and status.
   - Keep all authority toggles disabled and local-only.

4. Add documentation and fixture coverage.
   - Add `packages/zigeffect/docs/app-facing-thirteen-level-application-boundary.md`.
   - Add
     `packages/zigeffect/test/fixtures/app-facing-thirteen-level-application-boundary-after-safe.txt`.

5. Wire the build.
   - Add executable and test step in `packages/zigeffect/build.zig`.
   - Register the schema in `causal_schema_governance.zig`.
   - Mark the backlog item delivered in
     `causal_production_hardening_backlog.zig`.
   - Update the master roadmap next branch to thirteen-level policy.

6. Generate artifacts.
   - Plan artifact:
     `app-facing-ci-thirteen-level-application-boundary-plan`.
   - Applied artifact:
     `app-facing-ci-thirteen-level-application-boundary`.
   - Blocked source artifact:
     `app-facing-ci-thirteen-level-application-boundary-blocked`.

7. Verify and commit.
   - Run the full milestone verification list from the design doc.
   - Commit as
     `feat(zigeffect): add app-facing thirteen-level application boundary`.
   - Fast-forward `master`.
   - Create
     `codex/zigeffect-causal-app-facing-thirteen-level-policy` for the next
     sequential milestone.
