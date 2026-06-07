# zigeffect Causal CI Baseline Compare Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make causal CI handoff compare pull request failure artifacts against exact base-commit causal baselines when those baselines are available.

**Architecture:** Extend `causal_handoff.zig` with an artifact descriptor that can carry an optional baseline and compare report path. Reuse existing `causal_advice.buildAdviceReportWithBaseline` and `causal_compare.runCompare`. Update GitHub Actions to capture base dogfood and package-test baseline artifacts in a temporary worktree for pull requests, then copy those baseline JSON files into the head checkout artifact directory.

**Tech Stack:** Zig 0.16, existing causal tools, GitHub Actions, POSIX shell in Ubuntu CI, Bun repository test wrapper.

---

## Files

- Modify: `packages/zigeffect/tools/causal_handoff.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `.github/workflows/zigeffect-causal.yml`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

## Task 1: RED Baseline Pair Model

- [ ] **Step 1: Add failing path-resolution tests**

In `packages/zigeffect/tools/causal_handoff.zig`, add tests for these exact
expectations before implementing the helpers:

```zig
test "ci baseline path resolves for dogfood and package test artifacts" {
    const dogfood = try baselinePathForJsonArtifact(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    );
    defer if (dogfood) |path| std.testing.allocator.free(path);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-dogfood.json",
        dogfood.?,
    );

    const package_tests = try baselinePathForJsonArtifact(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
    );
    defer if (package_tests) |path| std.testing.allocator.free(path);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json",
        package_tests.?,
    );
}

test "local after artifact resolves to matching before artifact" {
    const before = try baselinePathForJsonArtifact(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json",
    );
    defer if (before) |path| std.testing.allocator.free(path);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-before.json",
        before.?,
    );
}

test "unpaired artifact has no baseline path" {
    const baseline = try baselinePathForJsonArtifact(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json",
    );
    try std.testing.expectEqual(@as(?[]const u8, null), baseline);
}
```

- [ ] **Step 2: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail with `use of undeclared identifier 'baselinePathForJsonArtifact'`.

## Task 2: Implement Pair Resolution

- [ ] **Step 1: Add artifact descriptor types**

In `packages/zigeffect/tools/causal_handoff.zig`, add:

```zig
const HandoffArtifact = struct {
    json_path: []const u8,
    advice_report_path: []const u8,
    baseline_path: ?[]const u8 = null,
    compare_report_path: ?[]const u8 = null,
};
```

- [ ] **Step 2: Implement baseline path derivation**

Add:

```zig
fn baselinePathForJsonArtifact(allocator: std.mem.Allocator, json_path: []const u8) !?[]const u8 {
    const dir = causal_run.artifact_dir ++ "/";
    if (std.mem.eql(u8, json_path, dir ++ "zigeffect-causal-dogfood.json")) {
        return try std.fmt.allocPrint(allocator, "{s}zigeffect-causal-ci-baseline-dogfood.json", .{dir});
    }
    if (std.mem.eql(u8, json_path, dir ++ "zigeffect-causal-package-tests.json")) {
        return try std.fmt.allocPrint(allocator, "{s}zigeffect-causal-ci-baseline-package-tests.json", .{dir});
    }
    if (std.mem.endsWith(u8, json_path, "-after.json")) {
        return try std.fmt.allocPrint(
            allocator,
            "{s}-before.json",
            .{json_path[0 .. json_path.len - "-after.json".len]},
        );
    }
    return null;
}
```

- [ ] **Step 3: Implement compare path derivation**

Add:

```zig
fn compareReportPathForJsonArtifact(allocator: std.mem.Allocator, json_path: []const u8) ![]const u8 {
    if (std.mem.endsWith(u8, json_path, "-after.json")) {
        return std.fmt.allocPrint(
            allocator,
            "{s}-compare.txt",
            .{json_path[0 .. json_path.len - "-after.json".len]},
        );
    }
    if (!std.mem.endsWith(u8, json_path, ".json")) return error.InvalidJsonArtifactPath;
    return std.fmt.allocPrint(allocator, "{s}-ci-compare.txt", .{json_path[0 .. json_path.len - ".json".len]});
}
```

- [ ] **Step 4: Build descriptors only for existing baselines**

Create a helper that takes existing JSON paths and returns owned
`HandoffArtifact` values. It must only set `baseline_path` and
`compare_report_path` when the derived baseline file exists:

```zig
fn describeArtifacts(
    io: std.Io,
    allocator: std.mem.Allocator,
    json_artifact_paths: []const []const u8,
) !std.ArrayList(HandoffArtifact)
```

Each descriptor should own its `json_path`, `advice_report_path`,
`baseline_path`, and `compare_report_path` strings. Add a matching
`deinitArtifacts` helper that frees every owned field.

- [ ] **Step 5: Verify GREEN for path tests**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: RED Paired Handoff Output

- [ ] **Step 1: Convert report formatting test to descriptors**

Change the existing `formatCiHandoffReport` test to pass descriptors. Include
one paired artifact and one unpaired artifact:

```zig
const artifacts: []const HandoffArtifact = &.{
    .{
        .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
        .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-package-tests-advice.txt",
        .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json",
        .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-package-tests-ci-compare.txt",
    },
    .{
        .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json",
        .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail-advice.txt",
    },
};
```

Expect the report to contain:

```text
baseline pairs: 1
baseline: .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json
compare report: .zig-cache/causal-artifacts/zigeffect-causal-package-tests-ci-compare.txt
zig build causal-compare -- .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json .zig-cache/causal-artifacts/zigeffect-causal-package-tests.json
zig build causal-advice -- --before .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json --file .zig-cache/causal-artifacts/zigeffect-causal-package-tests.json
zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json
```

- [ ] **Step 2: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because report formatting still accepts only JSON paths and does
not emit paired baseline details.

## Task 4: Generate Baseline-Aware Advice And Compare Reports

- [ ] **Step 1: Import causal_compare into the handoff tool**

In `packages/zigeffect/build.zig`, add:

```zig
causal_handoff_tool_module.addImport("causal_compare", causal_compare_tool_module);
```

In `packages/zigeffect/tools/causal_handoff.zig`, add:

```zig
const causal_compare = @import("causal_compare");
```

- [ ] **Step 2: Update report formatting**

Change:

```zig
pub fn formatCiHandoffReport(allocator: std.mem.Allocator, json_artifact_paths: []const []const u8) ![]const u8
```

to:

```zig
pub fn formatCiHandoffReport(allocator: std.mem.Allocator, artifacts: []const HandoffArtifact) ![]const u8
```

Print `json artifacts: {d}` from `artifacts.len`, compute `baseline pairs` by
counting descriptors with `baseline_path != null`, and emit paired or unpaired
commands according to the design.

- [ ] **Step 3: Update generated report writing**

Replace `writeAdviceReportsForArtifacts` with:

```zig
fn writeGeneratedReportsForArtifacts(
    io: std.Io,
    allocator: std.mem.Allocator,
    artifacts: []const HandoffArtifact,
) !void
```

For each unpaired artifact, read `json_path` and call
`causal_advice.buildAdviceReport`.

For each paired artifact, read `baseline_path.?` and `json_path`, call
`causal_compare.runCompare`, write `compare_report_path.?`, then call
`causal_advice.buildAdviceReportWithBaseline` and write `advice_report_path`.

- [ ] **Step 4: Update main**

The main flow should become:

```zig
var existing_paths = std.ArrayList([]const u8).empty;
defer existing_paths.deinit(allocator);
for (candidates.items) |path| {
    if (try artifactExists(init.io, path)) {
        try existing_paths.append(allocator, path);
    }
}

var artifacts = try describeArtifacts(init.io, allocator, existing_paths.items);
defer deinitArtifacts(allocator, &artifacts);

try writeGeneratedReportsForArtifacts(init.io, allocator, artifacts.items);

const report = try formatCiHandoffReport(allocator, artifacts.items);
```

- [ ] **Step 5: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 5: CI Base Capture

- [ ] **Step 1: Add PR-only baseline capture step**

In `.github/workflows/zigeffect-causal.yml`, after Zig setup and before
printing the manifest, add:

```yaml
      - name: Capture PR base causal baselines
        if: ${{ github.event_name == 'pull_request' }}
        shell: bash
        run: |
          set -euo pipefail
          git fetch --no-tags --depth=1 origin "${{ github.event.pull_request.base.sha }}"
          git worktree add ../zigeffect-causal-base "${{ github.event.pull_request.base.sha }}"

          pushd ../zigeffect-causal-base/packages/zigeffect
          zig build causal-test
          zig build causal-dev-loop -- baseline package-tests
          popd

          mkdir -p packages/zigeffect/.zig-cache/causal-artifacts
          cp ../zigeffect-causal-base/packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json \
            packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-dogfood.json
          cp ../zigeffect-causal-base/packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json \
            packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json
```

- [ ] **Step 2: Keep upload globs unchanged**

Do not broaden artifact upload paths. The existing upload list should remain:

```yaml
            packages/zigeffect/.zig-cache/causal-artifacts/*.txt
            packages/zigeffect/.zig-cache/causal-artifacts/*.json
            packages/zigeffect/.zig-cache/causal-artifacts/*.dot
```

- [ ] **Step 3: Verify workflow text**

Run:

```sh
rg -n "Capture PR base causal baselines|zigeffect-causal-ci-baseline-dogfood|zigeffect-causal-ci-baseline-package-tests|causal-ci-handoff" .github/workflows/zigeffect-causal.yml
```

Expected: all four strings are present.

## Task 6: Artifact Manifest And Docs

- [ ] **Step 1: Update the artifact manifest**

In `packages/zigeffect/tools/causal_artifacts.zig`, list the new baseline JSON
artifacts under default artifacts:

```text
- ci baseline dogfood .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-dogfood.json
- ci baseline package-tests .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json
```

Update `artifact manifest lists CI upload globs and default artifacts` to check
for both names.

- [ ] **Step 2: Update agent docs**

In `packages/zigeffect/docs/agent-guide.md` and
`packages/zigeffect/docs/causal-scenarios.md`, document that PR CI baseline
capture lets handoff mark advice as `status=persisting` or `status=new`.

- [ ] **Step 3: Update roadmap docs**

In `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
and `packages/zigeffect/docs/roadmap.md`, mark this slice as the next CI
baseline comparison milestone.

## Task 7: End-To-End Verification And Commit

- [ ] **Step 1: Run handoff without baselines**

Run:

```sh
cd packages/zigeffect && rm -rf .zig-cache/causal-artifacts && zig build causal-test && zig build causal-ci-handoff
```

Expected: handoff succeeds, generated dogfood advice uses `status=observed`,
and no compare report is listed for dogfood.

- [ ] **Step 2: Run handoff with CI baseline files**

Run:

```sh
cd packages/zigeffect
cp .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-dogfood.json
zig build causal-ci-handoff
test -f .zig-cache/causal-artifacts/zigeffect-causal-dogfood-ci-compare.txt
rg "baseline: .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-dogfood.json" .zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt
rg "status=persisting" .zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt
```

Expected: pass.

- [ ] **Step 3: Run package verification**

Run:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
git diff --check
bun run zig:test
```

Expected: all commands exit zero.

- [ ] **Step 4: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_handoff.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_artifacts.zig \
  .github/workflows/zigeffect-causal.yml \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-ci-baseline-compare-design.md \
  docs/superpowers/plans/2026-06-07-zigeffect-causal-ci-baseline-compare.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/causal-scenarios.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): compare ci causal baselines"
```

## Self-Review

- Spec coverage: The plan covers pair resolution, generated reports, CI base
  capture, docs, verification, and commit.
- Placeholder scan: no placeholder-only tasks remain.
- Type consistency: helper names, artifact names, report names, and command
  names are consistent with the design.
