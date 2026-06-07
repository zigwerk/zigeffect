# zigeffect Causal CI Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-ci-handoff`, a CI failure handoff artifact that points agents at exact causal follow-up commands.

**Architecture:** Add one focused Zig tool that formats a text handoff report from existing causal JSON artifact paths, writes that report under `.zig-cache/causal-artifacts/`, and is invoked by CI on failure before artifact upload.

**Tech Stack:** Zig 0.16, existing `causal_run` path registry, GitHub Actions, Bun repository scripts.

---

## Files

- Create: `packages/zigeffect/tools/causal_handoff.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `.github/workflows/zigeffect-causal.yml`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

## Task 1: RED Tool Contract

- [ ] **Step 1: Create the failing tool**

Create `packages/zigeffect/tools/causal_handoff.zig` with
`formatCiHandoffReport` intentionally unimplemented and tests expecting:

```text
zigeffect causal CI handoff
handoff: .zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt
json artifacts: 2
zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot
no causal JSON artifacts found
```

- [ ] **Step 2: Wire build step**

Add `causal-ci-handoff` executable and tests to `packages/zigeffect/build.zig`,
importing `causal_run`.

- [ ] **Step 3: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because `formatCiHandoffReport` is not implemented.

## Task 2: Implement Handoff Formatting

- [ ] **Step 1: Add report formatter**

Implement:

```zig
pub const handoff_report_path = causal_run.artifact_dir ++ "/zigeffect-causal-ci-handoff.txt";

pub fn formatCiHandoffReport(
    allocator: std.mem.Allocator,
    json_artifact_paths: []const []const u8,
) ![]const u8
```

The formatter prints a header, artifact dir, handoff path, JSON artifact count,
and per-artifact advice/query commands.

- [ ] **Step 2: Add candidate collection**

Build candidate JSON paths from dogfood, default dev-loop before/after, scenario
artifact paths, and scenario dev-loop before/after paths.

- [ ] **Step 3: Add executable main**

`main` should:

1. build candidate paths;
2. read each candidate to detect existence;
3. format a handoff report from existing JSON paths;
4. write the report to `handoff_report_path`;
5. print the report.

Missing JSON artifacts should be skipped. Other read/write errors should
propagate.

- [ ] **Step 4: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: CI And Docs

- [ ] **Step 1: Update CI workflow**

Add before the upload step:

```yaml
- name: Write causal CI handoff
  if: ${{ failure() }}
  working-directory: packages/zigeffect
  run: zig build causal-ci-handoff
```

- [ ] **Step 2: Update docs**

Document:

- `zig build causal-ci-handoff`;
- output path;
- the handoff path in `zig build causal-artifacts`;
- CI runs it on failure;
- uploaded handoff report is the first artifact agents should read.

## Task 4: Verification And Commit

- [ ] **Step 1: Run verification**

Run:

```sh
cd packages/zigeffect && zig build causal-test
cd packages/zigeffect && zig build causal-ci-handoff
cd packages/zigeffect && test -f .zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/zigeffect-causal.yml"); puts "workflow yaml parsed"'
bun run zig:test
git diff --check
```

- [ ] **Step 2: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_handoff.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_artifacts.zig \
  .github/workflows/zigeffect-causal.yml \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-ci-handoff-design.md \
  docs/superpowers/plans/2026-06-07-zigeffect-causal-ci-handoff.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/causal-scenarios.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): add causal ci handoff"
```

## Self-Review

- Spec coverage: The plan covers command, report path, CI step, docs, tests, and
  verification.
- Placeholder scan: no placeholder-only steps remain.
- Type consistency: command names, artifact path, and function names are stable.
