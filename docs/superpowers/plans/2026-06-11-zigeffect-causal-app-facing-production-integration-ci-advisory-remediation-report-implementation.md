# Zigeffect Causal App-Facing Production Integration CI Advisory Remediation Report Implementation

## Success Criteria

- A new Zig producer consumes a ready SolidJS read-only preview artifact and
  emits a deterministic advisory CI remediation report.
- The report is useful to agents and reviewers while preserving no-mutation,
  no-enforcement authority.
- Build wiring, schema governance, backlog, docs, roadmap, workbench sample, and
  tests are updated.
- Full verification passes and the branch is committed.

## Steps

1. Add failing Zig tests for the new report contract:
   - option parsing;
   - output path suffixing;
   - ready source approval;
   - blocked/rejected source;
   - disabled authority validation;
   - advisory bridge preservation;
   - denied CI claims.
2. Implement
   `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report.zig`.
3. Add the executable and test step to `packages/zigeffect/build.zig`.
4. Generate approved and rejected local artifacts from the existing preview
   artifact path.
5. Add workbench model support, sample route, public sample JSON, and rendering
   tests.
6. Register the schema in `causal_schema_governance.zig`.
7. Advance the production hardening backlog recommendation.
8. Add user-facing docs and update the master roadmap.
9. Refresh generated governance/backlog docs.
10. Run full verification.
11. Commit the milestone and prepare the next branch.
