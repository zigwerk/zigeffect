# zigeffect Causal CI Generated Advice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `zig build causal-ci-handoff` so CI failure bundles include generated causal advice reports for existing JSON artifacts.

**Architecture:** Reuse the existing `causal_advice` module from the handoff tool. Convert each existing JSON artifact path into a deterministic `*-advice.txt` path, write advice reports for existing artifacts, and list those generated report paths in the handoff artifact.

**Tech Stack:** Zig 0.16, existing `causal_advice`, existing causal artifact directory, GitHub Actions upload globs.

---

## Files

- Modify: `packages/zigeffect/tools/causal_handoff.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

## Task 1: RED Handoff Advice Tests

- [ ] **Step 1: Add failing path and handoff expectations**

In `packages/zigeffect/tools/causal_handoff.zig`, add tests expecting:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt
advice report: .zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt
```

- [ ] **Step 2: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because the handoff report does not list generated advice report
paths yet.

## Task 2: Generate Advice Reports

- [ ] **Step 1: Import causal_advice**

Add `causal_advice` as an import for the handoff tool in `build.zig`.

- [ ] **Step 2: Implement path transform**

Add:

```zig
fn adviceReportPathForJsonArtifact(allocator: std.mem.Allocator, json_path: []const u8) ![]const u8
```

It must replace a final `.json` suffix with `-advice.txt`.

- [ ] **Step 3: Add generated advice report paths to handoff output**

`formatCiHandoffReport` should print:

```text
  advice report: <generated-advice-path>
```

for every listed JSON artifact.

- [ ] **Step 4: Write advice reports in main**

For each existing JSON artifact:

1. read the JSON file;
2. call `causal_advice.buildAdviceReport`;
3. write the result to the generated advice path.

- [ ] **Step 5: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: Docs And Verification

- [ ] **Step 1: Update docs**

Document that CI handoff now includes generated `*-advice.txt` reports.

- [ ] **Step 2: Run full verification**

Run:

```sh
cd packages/zigeffect && zig build causal-test
cd packages/zigeffect && zig build causal-ci-handoff
cd packages/zigeffect && test -f .zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
bun run zig:test
git diff --check
```

- [ ] **Step 3: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_handoff.zig \
  packages/zigeffect/build.zig \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-ci-generated-advice-design.md \
  docs/superpowers/plans/2026-06-07-zigeffect-causal-ci-generated-advice.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): generate ci causal advice reports"
```

## Self-Review

- Spec coverage: The plan covers tests, implementation, docs, verification, and
  commit.
- Placeholder scan: no placeholder-only steps remain.
- Type consistency: command, function, and artifact names match the design.
