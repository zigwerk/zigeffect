# zigeffect Causal CI Verdict Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a structured CI verdict JSON artifact so agents can read one file before inspecting causal advice, compare, and query reports.

**Architecture:** Keep `causal-ci-handoff` as the aggregation point. Add a small verdict formatter to `tools/causal_handoff.zig` that reads generated advice reports, counts action statuses, and writes `zigeffect-causal-ci-verdict.json`. Update the text handoff, artifact manifest, and docs to point at the verdict.

**Tech Stack:** Zig 0.16, existing causal artifact directory, existing handoff/advice/compare tools, Bun test wrapper.

---

## Files

- Modify: `packages/zigeffect/tools/causal_handoff.zig`
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

## Task 1: RED Verdict Formatter Tests

- [ ] **Step 1: Add failing verdict path and formatter tests**

In `packages/zigeffect/tools/causal_handoff.zig`, add:

```zig
pub const verdict_report_path = causal_run.artifact_dir ++ "/zigeffect-causal-ci-verdict.json";

const advice_persisting_text =
    \\zigeffect causal advice report
    \\artifact: .zig-cache/causal-artifacts/persisting.json
    \\actions: 1
    \\- action provide-missing-service status=persisting event=3 kind=service_required label=Config
    \\
;

const advice_new_text =
    \\zigeffect causal advice report
    \\artifact: .zig-cache/causal-artifacts/new.json
    \\actions: 2
    \\- action inspect-command-failure status=new event=9 kind=assertion_recorded label=package-tests
    \\- action close-resource status=observed event=4 kind=resource_acquired label=db
    \\
;

test "verdict summarizes advice action statuses" {
    const artifacts: []const HandoffArtifact = &.{
        .{
            .json_path = ".zig-cache/causal-artifacts/persisting.json",
            .advice_report_path = ".zig-cache/causal-artifacts/persisting-advice.txt",
            .baseline_path = ".zig-cache/causal-artifacts/before.json",
            .compare_report_path = ".zig-cache/causal-artifacts/persisting-ci-compare.txt",
        },
        .{
            .json_path = ".zig-cache/causal-artifacts/new.json",
            .advice_report_path = ".zig-cache/causal-artifacts/new-advice.txt",
        },
    };
    const advice_reports: []const []const u8 = &.{ advice_persisting_text, advice_new_text };
    const verdict = try formatCiVerdictJson(std.testing.allocator, artifacts, advice_reports);
    defer std.testing.allocator.free(verdict);

    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"schema\": \"zigeffect.causal.ci-verdict.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"status\": \"attention\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"next_action\": \"inspect-new-advice\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"json_artifacts\": 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"baseline_pairs\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"actions\": 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"new_actions\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"persisting_actions\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"observed_actions\": 1") != null);
}

test "verdict is clear when no artifacts exist" {
    const verdict = try formatCiVerdictJson(std.testing.allocator, &.{}, &.{});
    defer std.testing.allocator.free(verdict);

    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"status\": \"clear\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"next_action\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"artifacts\": []") != null);
}
```

- [ ] **Step 2: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail with `use of undeclared identifier 'formatCiVerdictJson'`.

## Task 2: Implement Verdict Formatting

- [ ] **Step 1: Add verdict helpers**

In `packages/zigeffect/tools/causal_handoff.zig`, add:

```zig
const ActionCounts = struct {
    actions: usize = 0,
    new_actions: usize = 0,
    persisting_actions: usize = 0,
    observed_actions: usize = 0,
};
```

Add helper functions:

```zig
fn countAdviceActions(advice_report: []const u8) ActionCounts
fn addCounts(total: *ActionCounts, item: ActionCounts) void
fn verdictStatus(counts: ActionCounts) []const u8
fn verdictNextAction(counts: ActionCounts) []const u8
fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void
```

`countAdviceActions` should split by `\n`, inspect lines beginning with
`- action `, and count status substrings.

- [ ] **Step 2: Add `formatCiVerdictJson`**

Add:

```zig
fn formatCiVerdictJson(
    allocator: std.mem.Allocator,
    artifacts: []const HandoffArtifact,
    advice_reports: []const []const u8,
) ![]const u8
```

It must reject mismatched array lengths with `error.MismatchedVerdictInputs`,
aggregate counts, escape path strings, and emit deterministic pretty JSON.

- [ ] **Step 3: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: Write Verdict During Handoff

- [ ] **Step 1: Return generated advice text from report writer**

Change `writeGeneratedReportsForArtifacts` so it returns
`std.ArrayList([]const u8)` containing owned copies of each generated advice
report. Add `deinitAdviceReports` to free them.

- [ ] **Step 2: Write verdict in `main`**

After writing generated advice and compare reports:

```zig
var advice_reports = try writeGeneratedReportsForArtifacts(init.io, allocator, artifacts.items);
defer deinitAdviceReports(allocator, &advice_reports);

const verdict = try formatCiVerdictJson(allocator, artifacts.items, advice_reports.items);
defer allocator.free(verdict);
try writeArtifact(init.io, verdict_report_path, verdict);
```

- [ ] **Step 3: Add handoff header pointer**

Update `formatCiHandoffReport` to print:

```text
verdict: .zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json
```

- [ ] **Step 4: Verify generated artifact**

Run:

```sh
cd packages/zigeffect && rm -rf .zig-cache/causal-artifacts && zig build causal-test && zig build causal-ci-handoff
test -f packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json
```

When running from `packages/zigeffect`, use:

```sh
test -f .zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json
```

Expected: pass.

## Task 4: Manifest And Docs

- [ ] **Step 1: Update artifact manifest**

In `packages/zigeffect/tools/causal_artifacts.zig`, add:

```text
- ci verdict .zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json
```

Update the manifest test to expect the path.

- [ ] **Step 2: Update docs**

In `packages/zigeffect/docs/agent-guide.md` and
`packages/zigeffect/docs/causal-scenarios.md`, tell agents to read
`zigeffect-causal-ci-verdict.json` before the text handoff when present.

- [ ] **Step 3: Update roadmaps**

In the self-improvement roadmap and package roadmap, record that CI now emits a
structured verdict artifact.

## Task 5: Verification And Commit

- [ ] **Step 1: Run causal verification**

Run:

```sh
cd packages/zigeffect && rm -rf .zig-cache/causal-artifacts && zig build causal-test && zig build causal-ci-handoff
rg "\"status\": \"attention\"" packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json
rg "\"observed_actions\": 4" packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json
rg "verdict: .zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json" packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt
```

- [ ] **Step 2: Run full verification**

Run:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
git diff --check
bun run zig:test
```

- [ ] **Step 3: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_handoff.zig \
  packages/zigeffect/tools/causal_artifacts.zig \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/causal-scenarios.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-ci-verdict-design.md \
  docs/superpowers/plans/2026-06-07-zigeffect-causal-ci-verdict.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): add causal ci verdict artifact"
```

## Self-Review

- Spec coverage: The plan covers verdict format, aggregation, handoff
  integration, manifest, docs, verification, and commit.
- Placeholder scan: no placeholder-only instructions remain.
- Type consistency: function names, artifact names, and JSON keys match the
  design.
