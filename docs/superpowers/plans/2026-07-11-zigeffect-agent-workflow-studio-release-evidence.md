# ZigEffect Agent Workflow Studio Release Evidence

Date: 2026-07-11
Design: `docs/superpowers/specs/2026-07-11-zigeffect-agent-workflow-studio-design.md`
Plan: `docs/superpowers/plans/2026-07-11-zigeffect-agent-workflow-studio.md`

## Acceptance coverage

| Requirement | Executable evidence |
|---|---|
| AWS-001–AWS-005 | `statechart_version_test.zig`, `studio_test.zig`, version-history catalog tests |
| AWS-006 | `plan_test.zig`, CLI compile tests, generated-project matrix |
| AWS-007–AWS-008 | proof completeness/digest tests, flat and hierarchical simulation tests |
| AWS-009–AWS-012 | control-plane, actor-system control, workflow lifecycle control, fleet and migration tests |
| AWS-013 | all-pattern validation plus Debug/ReleaseSafe generated application compilation |
| AWS-014 | strict Studio model tests, Workbench tests/typecheck/build, statechart/XState tests |
| AWS-015 | temporal, deterministic mutation catalog, XState oracle, exact reverse migration and catalog recovery tests |
| AWS-016 | CLI parser/runtime tests for compile, patterns, governance, versions, Studio, fleet and controls |
| AWS-017 | secret rejection, strict schema, digest recomputation, path confinement, allocation failure and full-range u64 tests |
| AWS-018 | release commands below |

## Release commands

| Gate | Command | Result |
|---|---|---|
| Core Debug | `cd packages/zigeffect && zig build test-raw` | passed; 953 tests |
| Core ReleaseSafe | `cd packages/zigeffect && zig build test-raw -Doptimize=ReleaseSafe` | passed; 953 tests |
| Public API | `cd packages/zigeffect && zig build public-api-review` | passed; 8 tests |
| Tool hygiene | `cd packages/zigeffect && bash tools/check_tool_hygiene.sh` | passed; 46 tools |
| Standard library | `cd packages/zigeffect-std && zig build test` | passed; 215 tests |
| Standard-library examples | `cd packages/zigeffect-std && zig build examples` | passed; 12 tests, including Agent Workflow Studio |
| Statechart ReleaseSafe | `cd packages/zigeffect-std && zig build statechart-test -Doptimize=ReleaseSafe` | passed |
| Workbench unit/model | `bun run zigeffect:workbench:test` | passed; 288 tests, 1366 expectations |
| Workbench typecheck | `bun run zigeffect:workbench:typecheck` | passed |
| Workbench production build | `bun run zigeffect:workbench:build` | passed |
| CLI unit | `cd packages/zigeffect-cli && zig build test` | passed; 35 tests |
| Generated projects | `cd packages/zigeffect-cli && zig build integration-test` | passed; all scaffolds Debug/ReleaseSafe and all workflow patterns compile |
| Local release | `bash packages/zigeffect/scripts/check-local-release.sh` | passed; Zig 0.16.0, CLI 0.5.0, all adapters, Workbench production build and 46-tool hygiene gate |

The consolidated local-release command exited successfully after independently
re-running the migration guard, core Debug and ReleaseSafe suites, public API
review, standard library, examples, CLI unit and generated-project integration,
Postgres/QUIC/ZIO/ZIAC/ZGroach adapters, Workbench typecheck/test/build, honesty,
redaction and repository hygiene checks.

## External visual check

The browser verification skill connected to the in-app browser, but after the
previous local Vite process had stopped, the browser URL safety policy blocked
re-navigation to the restarted localhost page. The policy explicitly forbids a
workaround, so visual inspection was not bypassed. Static UI verification is
covered by the Workbench tests, strict typecheck and production build; a human
can reopen `?sample=statechart` and select **Studio** for the remaining visual
sign-off. This is the only unexecuted acceptance activity; it is an external
manual presentation check rather than a missing runtime, model or build gate.
