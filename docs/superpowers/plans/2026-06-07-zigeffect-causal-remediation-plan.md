# zigeffect Causal Remediation Plan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-remediation-plan -- local [scenario]`, a deterministic non-mutating command that turns local causal diagnosis artifacts into an evidence-bound Markdown remediation plan.

**Architecture:** Create `packages/zigeffect/tools/causal_remediation_plan.zig` as a focused planner. It reads the local dev-loop verdict, diagnosis, advice, query, and compare artifacts; parses stable action/evidence lines; writes `*-remediation-plan.md`; and prints the same report without editing source or executing remediation. Update build wiring, artifact manifest, README, and agent docs so the new artifact is discoverable.

**Tech Stack:** Zig 0.16 build system, Zig std JSON parser, existing `causal_run` scenario registry and artifact directory, Bun repo verification commands.

---

## File Structure

- Create `packages/zigeffect/tools/causal_remediation_plan.zig`
  - Local/default and scenario path helpers.
  - Verdict JSON shape and schema validation.
  - Stable line parser for diagnosis/advice action lines.
  - Remediation posture and strategy mapping.
  - Markdown report formatter.
  - Artifact reader/writer and CLI `main`.
  - Unit tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, run step, tests, and `examples` dependencies.
  - Import `causal_run`.
- Modify `packages/zigeffect/tools/causal_artifacts.zig`
  - Add diagnosis and remediation-plan paths to default and scenario manifest output.
  - Strengthen manifest tests.
- Modify `packages/zigeffect/README.md`
  - Document verdict, dev-agent, diagnosis, and remediation-plan workflow.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Add remediation-plan command after diagnosis.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  - Add remediation-plan command and artifact paths.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Mark remediation planning as delivered after implementation.
- Modify `packages/zigeffect/docs/roadmap.md`
  - Add remediation plan to the delivered causal self-improvement list.

## Task 1: Parser, Posture, And Formatter

**Files:**
- Create: `packages/zigeffect/tools/causal_remediation_plan.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing formatter tests**

Create `packages/zigeffect/tools/causal_remediation_plan.zig` with these initial types, fixtures, and tests:

```zig
const std = @import("std");
const causal_run = @import("causal_run");

const supported_local_schema = "zigeffect.causal.dev-loop-verdict.v1";

const Verdict = struct {
    schema: []const u8,
    schema_version: u32,
    status: []const u8,
    next_action: []const u8,
    json_artifacts: usize,
    baseline_pairs: usize,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
    artifacts: []const VerdictArtifact,
};

const VerdictArtifact = struct {
    json_path: []const u8,
    baseline_path: ?[]const u8,
    advice_report_path: []const u8,
    compare_report_path: ?[]const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
};

const EvidenceAction = struct {
    action: []const u8,
    status: []const u8,
    event_id: u64,
    kind: []const u8,
    label: ?[]const u8 = null,
    subsystem: []const u8,
    fix_category: []const u8,
    diagnosis: []const u8,
    patch_prompt: []const u8,
};

const RemediationPosture = enum {
    do_not_patch,
    investigate,
    patch_candidate,
    regression_candidate,
};

const RemediationInput = struct {
    target: []const u8,
    plan_path: []const u8,
    verdict_path: []const u8,
    diagnosis_path: []const u8,
    verdict: Verdict,
    evidence: []const EvidenceAction,
    compare_guardrail: []const u8,
};

const diagnosis_text =
    \\zigeffect causal diagnosis
    \\mode: local
    \\target: dogfood
    \\diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
    \\verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
    \\status: attention
    \\next_action: inspect-persisting-advice
    \\actions: 2
    \\new_actions: 0
    \\persisting_actions: 2
    \\observed_actions: 0
    \\
    \\summary:
    \\- diagnosis status: attention
    \\- dominant evidence: persisting
    \\- patch posture: existing causal findings remain; do not claim this patch fixed them
    \\- compare posture: no before/after event or finding delta
    \\- query report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt (12 queries)
    \\
    \\evidence:
    \\- action close-resource status=persisting event=4 kind=resource_acquired label=dogfood database
    \\  subsystem: scope_lifecycle
    \\  fix category: resource-finalizer
    \\  diagnosis: an acquired resource lacks matching finalization evidence
    \\  patch prompt: inspect acquireRelease usage and scope ownership; add the missing finalizer or close path
    \\  citations: event=4 advice=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt query=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
    \\- action resolve-scoped-fiber status=persisting event=5 kind=fiber_forked label=dogfood child fiber
    \\  subsystem: fiber_runtime
    \\  fix category: structured-concurrency
    \\  diagnosis: a scoped fiber remains active in captured evidence
    \\  patch prompt: inspect scoped fork, join, and interruption paths before the owning scope closes
    \\  citations: event=5 advice=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt query=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
    \\
;

fn localPlanPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-plan.md";
}

test "remediation plan path is stable for default target" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
        localPlanPath(),
    );
}

test "scenario remediation plan path includes slug" {
    const path = try localPlanPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
        path,
    );
}

test "posture uses clear verdict as do not patch" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "clear",
        .next_action = "none",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{.{
            .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
            .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
            .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
            .actions = 0,
            .new_actions = 0,
            .persisting_actions = 0,
            .observed_actions = 0,
        }},
    };

    try std.testing.expectEqual(RemediationPosture.do_not_patch, remediationPosture(verdict));
}

test "posture prioritizes new evidence as regression candidate" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "attention",
        .next_action = "inspect-new-advice",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 1,
        .new_actions = 1,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{.{
            .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
            .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
            .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
            .actions = 1,
            .new_actions = 1,
            .persisting_actions = 0,
            .observed_actions = 0,
        }},
    };

    try std.testing.expectEqual(RemediationPosture.regression_candidate, remediationPosture(verdict));
}

test "diagnosis parser captures evidence actions and multi word labels" {
    const evidence = try parseDiagnosisEvidence(std.testing.allocator, diagnosis_text);
    defer deinitEvidence(std.testing.allocator, evidence);

    try std.testing.expectEqual(@as(usize, 2), evidence.len);
    try std.testing.expectEqualStrings("close-resource", evidence[0].action);
    try std.testing.expectEqualStrings("persisting", evidence[0].status);
    try std.testing.expectEqual(@as(u64, 4), evidence[0].event_id);
    try std.testing.expectEqualStrings("resource_acquired", evidence[0].kind);
    try std.testing.expectEqualStrings("dogfood database", evidence[0].label.?);
    try std.testing.expectEqualStrings("scope_lifecycle", evidence[0].subsystem);
    try std.testing.expectEqualStrings("resource-finalizer", evidence[0].fix_category);
    try std.testing.expect(std.mem.indexOf(u8, evidence[0].patch_prompt, "acquireRelease") != null);
}

test "remediation formatter writes markdown strategy and guardrails" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "attention",
        .next_action = "inspect-persisting-advice",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 2,
        .new_actions = 0,
        .persisting_actions = 2,
        .observed_actions = 0,
        .artifacts = &.{.{
            .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
            .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
            .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
            .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
            .actions = 2,
            .new_actions = 0,
            .persisting_actions = 2,
            .observed_actions = 0,
        }},
    };
    const evidence = try parseDiagnosisEvidence(std.testing.allocator, diagnosis_text);
    defer deinitEvidence(std.testing.allocator, evidence);

    const report = try formatRemediationPlan(std.testing.allocator, .{
        .target = "dogfood",
        .plan_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        .diagnosis_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
        .verdict = verdict,
        .evidence = evidence,
        .compare_guardrail = "no before/after event or finding delta",
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "# zigeffect causal remediation plan") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "posture: patch-candidate") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event 4 `resource_acquired` status=persisting") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Patch candidate: scope_lifecycle / resource-finalizer") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-dev-loop -- baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Do not claim this patch fixed persisting evidence") != null);
}
```

- [ ] **Step 2: Wire only the test module and verify red**

Modify `packages/zigeffect/build.zig` after `causal_diagnosis_tool_module`:

```zig
    const causal_remediation_plan_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_remediation_plan.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_remediation_plan_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_remediation_plan_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-remediation-plan-tests",
        .root_module = causal_remediation_plan_tool_module,
    });
    const run_causal_remediation_plan_tool_tests = b.addRunArtifact(causal_remediation_plan_tool_tests);
```

Add only the test dependency near the other `examples_step` tool tests:

```zig
    examples_step.dependOn(&run_causal_remediation_plan_tool_tests.step);
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because helpers such as `localPlanPathForScenario`,
`remediationPosture`, `parseDiagnosisEvidence`, `deinitEvidence`, and
`formatRemediationPlan` are not implemented.

- [ ] **Step 3: Implement parser, posture, and formatter**

In `causal_remediation_plan.zig`, add the helpers below. Keep all allocations
owned by the caller and freed through `deinitEvidence`.

```zig
fn localPlanPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-plan.md",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn remediationPosture(verdict: Verdict) RemediationPosture {
    if (std.mem.eql(u8, verdict.status, "clear") or verdict.actions == 0) return .do_not_patch;
    if (verdict.new_actions > 0) return .regression_candidate;
    if (verdict.observed_actions > 0) return .investigate;
    return .patch_candidate;
}

fn postureText(posture: RemediationPosture) []const u8 {
    return switch (posture) {
        .do_not_patch => "do-not-patch",
        .investigate => "investigate",
        .patch_candidate => "patch-candidate",
        .regression_candidate => "regression-candidate",
    };
}

fn evidencePosture(verdict: Verdict) []const u8 {
    if (verdict.new_actions > 0) return "new";
    if (verdict.observed_actions > 0) return "observed";
    if (verdict.persisting_actions > 0) return "persisting";
    return "none";
}
```

Implement stable line parsing:

```zig
fn parseDiagnosisEvidence(allocator: std.mem.Allocator, diagnosis_report: []const u8) ![]EvidenceAction {
    var evidence = std.ArrayList(EvidenceAction).empty;
    errdefer deinitEvidence(allocator, evidence.items);

    var current: ?EvidenceAction = null;
    var lines = std.mem.splitScalar(u8, diagnosis_report, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "- action ")) {
            if (current) |item| try evidence.append(allocator, item);
            current = try parseActionLine(allocator, line);
        } else if (std.mem.startsWith(u8, line, "  subsystem: ")) {
            if (current) |*item| {
                allocator.free(item.subsystem);
                item.subsystem = try allocator.dupe(u8, line["  subsystem: ".len..]);
            }
        } else if (std.mem.startsWith(u8, line, "  fix category: ")) {
            if (current) |*item| {
                allocator.free(item.fix_category);
                item.fix_category = try allocator.dupe(u8, line["  fix category: ".len..]);
            }
        } else if (std.mem.startsWith(u8, line, "  diagnosis: ")) {
            if (current) |*item| {
                allocator.free(item.diagnosis);
                item.diagnosis = try allocator.dupe(u8, line["  diagnosis: ".len..]);
            }
        } else if (std.mem.startsWith(u8, line, "  patch prompt: ")) {
            if (current) |*item| {
                allocator.free(item.patch_prompt);
                item.patch_prompt = try allocator.dupe(u8, line["  patch prompt: ".len..]);
            }
        }
    }
    if (current) |item| try evidence.append(allocator, item);
    return evidence.toOwnedSlice(allocator);
}
```

Implement `parseActionLine` the same way `causal_diagnosis.zig` preserves
multi-word labels: split the line at `" label="`, tokenize only the prefix, and
duplicate the label remainder.

```zig
fn parseActionLine(allocator: std.mem.Allocator, line: []const u8) !EvidenceAction {
    const label_marker = " label=";
    const action_prefix, const label = if (std.mem.indexOf(u8, line, label_marker)) |label_index|
        .{ line[0..label_index], line[label_index + label_marker.len ..] }
    else
        .{ line, null };

    var tokens = std.mem.splitScalar(u8, action_prefix, ' ');
    _ = tokens.next() orelse return error.InvalidEvidenceActionLine;
    const action_keyword = tokens.next() orelse return error.InvalidEvidenceActionLine;
    if (!std.mem.eql(u8, action_keyword, "action")) return error.InvalidEvidenceActionLine;
    const action = tokens.next() orelse return error.InvalidEvidenceActionLine;

    var status: ?[]const u8 = null;
    var event_id: ?u64 = null;
    var kind: ?[]const u8 = null;
    while (tokens.next()) |token| {
        if (std.mem.startsWith(u8, token, "status=")) {
            status = token["status=".len..];
        } else if (std.mem.startsWith(u8, token, "event=")) {
            event_id = try std.fmt.parseInt(u64, token["event=".len..], 10);
        } else if (std.mem.startsWith(u8, token, "kind=")) {
            kind = token["kind=".len..];
        }
    }

    return .{
        .action = try allocator.dupe(u8, action),
        .status = try allocator.dupe(u8, status orelse return error.InvalidEvidenceActionLine),
        .event_id = event_id orelse return error.InvalidEvidenceActionLine,
        .kind = try allocator.dupe(u8, kind orelse return error.InvalidEvidenceActionLine),
        .label = if (label) |value| try allocator.dupe(u8, value) else null,
        .subsystem = try allocator.dupe(u8, "unknown"),
        .fix_category = try allocator.dupe(u8, "inspect-evidence"),
        .diagnosis = try allocator.dupe(u8, "diagnosis unavailable; inspect cited diagnosis report"),
        .patch_prompt = try allocator.dupe(u8, "inspect evidence before proposing a patch"),
    };
}
```

Add cleanup:

```zig
fn deinitEvidence(allocator: std.mem.Allocator, evidence: []const EvidenceAction) void {
    for (evidence) |item| {
        allocator.free(item.action);
        allocator.free(item.status);
        allocator.free(item.kind);
        if (item.label) |label| allocator.free(label);
        allocator.free(item.subsystem);
        allocator.free(item.fix_category);
        allocator.free(item.diagnosis);
        allocator.free(item.patch_prompt);
    }
    allocator.free(evidence);
}
```

Add strategy text helpers:

```zig
fn strategyTitle(item: EvidenceAction) []const u8 {
    if (std.mem.eql(u8, item.status, "new")) return "Regression candidate";
    if (std.mem.eql(u8, item.status, "observed")) return "Investigation candidate";
    return "Patch candidate";
}

fn strategyInstruction(action: []const u8) []const u8 {
    if (std.mem.eql(u8, action, "provide-missing-service")) return "Inspect service requirements and provider declarations before wiring a missing provider.";
    if (std.mem.eql(u8, action, "close-resource")) return "Inspect acquire/release ownership around the cited resource event before adding or wiring a finalizer.";
    if (std.mem.eql(u8, action, "resolve-scoped-fiber")) return "Inspect scoped fork, join, interruption, and parent scope close paths.";
    if (std.mem.eql(u8, action, "inspect-retry-exhaustion")) return "Inspect retry policy, failure specificity, and schedule boundaries.";
    if (std.mem.eql(u8, action, "inspect-command-failure")) return "Inspect the failing command output and add a focused regression test or source fix.";
    if (std.mem.eql(u8, action, "inspect-finalizer-failure")) return "Inspect finalizer error handling and cleanup cause preservation.";
    return "Inspect the cited evidence before proposing source changes.";
}
```

Add Markdown formatting:

```zig
fn formatRemediationPlan(allocator: std.mem.Allocator, input: RemediationInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const posture = remediationPosture(input.verdict);
    const artifact = input.verdict.artifacts[0];

    try output.appendSlice(allocator, "# zigeffect causal remediation plan\n\n");
    try output.appendSlice(allocator, "mode: local\n");
    try output.print(allocator, "target: {s}\n", .{input.target});
    try output.print(allocator, "posture: {s}\n", .{postureText(posture)});
    try output.print(allocator, "plan: {s}\n", .{input.plan_path});
    try output.print(allocator, "verdict: {s}\n", .{input.verdict_path});
    try output.print(allocator, "diagnosis: {s}\n\n", .{input.diagnosis_path});

    try output.appendSlice(allocator, "## Summary\n\n");
    try output.print(allocator, "- status: {s}\n", .{input.verdict.status});
    try output.print(allocator, "- next action: {s}\n", .{input.verdict.next_action});
    try output.print(allocator, "- evidence posture: {s}\n", .{evidencePosture(input.verdict)});
    try output.print(allocator, "- compare guardrail: {s}\n\n", .{input.compare_guardrail});

    try output.appendSlice(allocator, "## Evidence\n\n");
    if (input.evidence.len == 0) {
        try output.appendSlice(allocator, "- no causal advice actions selected\n\n");
    } else {
        for (input.evidence) |item| {
            try output.print(allocator, "- event {d} `{s}` status={s}\n", .{ item.event_id, item.kind, item.status });
            try output.print(allocator, "  - subsystem: {s}\n", .{item.subsystem});
            try output.print(allocator, "  - fix category: {s}\n", .{item.fix_category});
            if (item.label) |label| try output.print(allocator, "  - label: {s}\n", .{label});
            try output.print(allocator, "  - citation: {s}\n", .{artifact.advice_report_path});
        }
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "## Proposed Remediation\n\n");
    if (posture == .do_not_patch or input.evidence.len == 0) {
        try output.appendSlice(allocator, "- No patch strategy is proposed because the verdict is clear or no advice actions were selected.\n\n");
    } else {
        for (input.evidence, 0..) |item, index| {
            try output.print(allocator, "{d}. {s}: {s} / {s}\n", .{ index + 1, strategyTitle(item), item.subsystem, item.fix_category });
            try output.print(allocator, "   - {s}\n", .{strategyInstruction(item.action)});
            try output.print(allocator, "   - Diagnosis: {s}\n", .{item.diagnosis});
            try output.print(allocator, "   - Patch prompt: {s}\n", .{item.patch_prompt});
            try output.appendSlice(allocator, "   - Add or select a focused causal scenario before broad runtime changes.\n");
        }
        try output.append(allocator, '\n');
    }

    try appendVerificationCommands(allocator, &output, input.target);
    try appendClaimGuardrails(allocator, &output, input.verdict);
    return output.toOwnedSlice(allocator);
}
```

Implement `appendVerificationCommands` so the dogfood target omits a scenario
argument and scenario targets include it:

```zig
fn appendVerificationCommands(allocator: std.mem.Allocator, output: *std.ArrayList(u8), target: []const u8) !void {
    try output.appendSlice(allocator, "## Required Verification\n\n");
    if (std.mem.eql(u8, target, "dogfood")) {
        try output.appendSlice(allocator, "- `zig build causal-dev-loop -- baseline`\n");
        try output.appendSlice(allocator, "- `zig build causal-dev-loop -- after`\n");
        try output.appendSlice(allocator, "- `zig build causal-diagnosis -- local`\n");
    } else {
        try output.print(allocator, "- `zig build causal-dev-loop -- baseline {s}`\n", .{target});
        try output.print(allocator, "- `zig build causal-dev-loop -- after {s}`\n", .{target});
        try output.print(allocator, "- `zig build causal-diagnosis -- local {s}`\n", .{target});
    }
    try output.appendSlice(allocator, "- `zig build test --summary none`\n\n");
}

fn appendClaimGuardrails(allocator: std.mem.Allocator, output: *std.ArrayList(u8), verdict: Verdict) !void {
    try output.appendSlice(allocator, "## Claim Guardrails\n\n");
    if (verdict.new_actions > 0) {
        try output.appendSlice(allocator, "- Treat status=new evidence as a possible regression until compare/verdict output proves otherwise.\n");
    } else if (verdict.persisting_actions > 0) {
        try output.appendSlice(allocator, "- Do not claim this patch fixed persisting evidence unless the after verdict is clear or the compare report shows fewer findings.\n");
    } else if (verdict.observed_actions > 0) {
        try output.appendSlice(allocator, "- Do not claim a before/after improvement without capturing a baseline and rerunning the dev loop.\n");
    } else {
        try output.appendSlice(allocator, "- Do not patch unrelated subsystems when the causal verdict is clear.\n");
    }
    try output.appendSlice(allocator, "- Cite event ids from the remediation evidence section in the patch summary.\n");
    try output.appendSlice(allocator, "- Treat this plan as guidance, not permission to edit unrelated subsystems.\n");
}
```

- [ ] **Step 4: Run green check and commit**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_remediation_plan.zig build.zig
zig build examples
```

Expected: PASS.

Commit:

```sh
git add packages/zigeffect/tools/causal_remediation_plan.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal remediation formatter"
```

## Task 2: CLI Artifact Reader And Writer

**Files:**
- Modify: `packages/zigeffect/tools/causal_remediation_plan.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add failing validation and usage tests**

Add tests to `causal_remediation_plan.zig`:

```zig
test "usage names local mode" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-remediation-plan -- local [scenario]\n",
        usage(),
    );
}

test "unsupported verdict schema is rejected" {
    const verdict = Verdict{
        .schema = "zigeffect.causal.other.v1",
        .schema_version = 1,
        .status = "clear",
        .next_action = "none",
        .json_artifacts = 0,
        .baseline_pairs = 0,
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{},
    };

    try std.testing.expectError(error.UnsupportedVerdictSchema, validateLocalVerdict(verdict));
}

test "empty verdict artifacts are rejected" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "clear",
        .next_action = "none",
        .json_artifacts = 0,
        .baseline_pairs = 0,
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{},
    };

    try std.testing.expectError(error.EmptyVerdictArtifacts, validateLocalVerdict(verdict));
}
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because `usage` and `validateLocalVerdict` are missing.

- [ ] **Step 2: Implement validation, local paths, and compare guardrail parsing**

Add path helpers:

```zig
fn localVerdictPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-verdict.json";
}

fn localVerdictPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-verdict.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localDiagnosisPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-diagnosis.txt";
}

fn localDiagnosisPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-diagnosis.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn queryReportPathForJson(allocator: std.mem.Allocator, json_path: []const u8) ![]const u8 {
    if (std.mem.endsWith(u8, json_path, "-after.json")) {
        return std.fmt.allocPrint(allocator, "{s}-queries.txt", .{json_path[0 .. json_path.len - "-after.json".len]});
    }
    if (!std.mem.endsWith(u8, json_path, ".json")) return error.InvalidVerdictArtifactPath;
    return std.fmt.allocPrint(allocator, "{s}-queries.txt", .{json_path[0 .. json_path.len - ".json".len]});
}
```

Add validation and guardrail parsing:

```zig
fn validateLocalVerdict(verdict: Verdict) !void {
    if (!std.mem.eql(u8, verdict.schema, supported_local_schema)) return error.UnsupportedVerdictSchema;
    if (verdict.schema_version != 1) return error.UnsupportedVerdictSchema;
    if (verdict.artifacts.len == 0) return error.EmptyVerdictArtifacts;
}

fn parseCompareGuardrail(diagnosis_report: []const u8) []const u8 {
    var lines = std.mem.splitScalar(u8, diagnosis_report, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "- compare posture: ")) {
            return line["- compare posture: ".len..];
        }
    }
    return "compare report unavailable or unreadable";
}
```

- [ ] **Step 3: Implement file IO and `main`**

Add usage and IO helpers:

```zig
fn usage() []const u8 {
    return "usage: zig build causal-remediation-plan -- local [scenario]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-remediation-plan error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingRemediationInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}
```

Add local runner and CLI:

```zig
fn runLocal(init: std.process.Init, scenario_slug: ?[]const u8) !void {
    const allocator = init.gpa;
    const verdict_path = if (scenario_slug) |slug| try localVerdictPathForScenario(allocator, slug) else localVerdictPath();
    defer if (scenario_slug != null) allocator.free(verdict_path);
    const diagnosis_path = if (scenario_slug) |slug| try localDiagnosisPathForScenario(allocator, slug) else localDiagnosisPath();
    defer if (scenario_slug != null) allocator.free(diagnosis_path);
    const plan_path = if (scenario_slug) |slug| try localPlanPathForScenario(allocator, slug) else localPlanPath();
    defer if (scenario_slug != null) allocator.free(plan_path);
    const target = scenario_slug orelse "dogfood";

    const verdict_json = try readArtifact(init.io, allocator, verdict_path);
    defer allocator.free(verdict_json);
    var parsed = try std.json.parseFromSlice(Verdict, allocator, verdict_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try validateLocalVerdict(parsed.value);

    const diagnosis_report = try readArtifact(init.io, allocator, diagnosis_path);
    defer allocator.free(diagnosis_report);
    const artifact = parsed.value.artifacts[0];
    const advice_report = try readArtifact(init.io, allocator, artifact.advice_report_path);
    defer allocator.free(advice_report);
    _ = advice_report;
    const query_report_path = try queryReportPathForJson(allocator, artifact.json_path);
    defer allocator.free(query_report_path);
    const query_report = try readArtifact(init.io, allocator, query_report_path);
    defer allocator.free(query_report);
    _ = query_report;
    const compare_report = if (artifact.compare_report_path) |path| try readArtifact(init.io, allocator, path) else "";
    defer if (artifact.compare_report_path != null) allocator.free(compare_report);
    _ = compare_report;

    const evidence = try parseDiagnosisEvidence(allocator, diagnosis_report);
    defer deinitEvidence(allocator, evidence);

    const report = try formatRemediationPlan(allocator, .{
        .target = target,
        .plan_path = plan_path,
        .verdict_path = verdict_path,
        .diagnosis_path = diagnosis_path,
        .verdict = parsed.value,
        .evidence = evidence,
        .compare_guardrail = parseCompareGuardrail(diagnosis_report),
    });
    defer allocator.free(report);

    try writeArtifact(init.io, plan_path, report);
    std.debug.print("{s}", .{report});
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) failUsage(error.MissingMode);
    if (args.len > 3) failUsage(error.TooManyArguments);
    if (!std.mem.eql(u8, args[1], "local")) failUsage(error.UnknownMode);

    const scenario_slug: ?[]const u8 = if (args.len == 3) blk: {
        _ = causal_run.scenarioByName(args[2]) catch |err| failUsage(err);
        break :blk args[2];
    } else null;

    runLocal(init, scenario_slug) catch |err| switch (err) {
        error.MissingRemediationInput,
        error.UnsupportedVerdictSchema,
        error.EmptyVerdictArtifacts,
        error.InvalidVerdictArtifactPath,
        error.InvalidArtifactPath,
        => failUsage(err),
        else => return err,
    };
}
```

The `advice_report`, `query_report`, and `compare_report` reads are intentional
even when the first planner only parses diagnosis text: they verify the full
local bundle is present before emitting a remediation plan.

- [ ] **Step 4: Wire executable and build step**

Modify `packages/zigeffect/build.zig` after the `causal_remediation_plan_tool_tests`
wiring from Task 1:

```zig
    const causal_remediation_plan_tool = b.addExecutable(.{
        .name = "zigeffect-causal-remediation-plan",
        .root_module = causal_remediation_plan_tool_module,
    });
    const run_causal_remediation_plan_tool = b.addRunArtifact(causal_remediation_plan_tool);
    if (b.args) |args| run_causal_remediation_plan_tool.addArgs(args);
    const causal_remediation_plan_step = b.step("causal-remediation-plan", "Write a causal remediation plan from local dev-loop reports");
    causal_remediation_plan_step.dependOn(&run_causal_remediation_plan_tool.step);
```

Add executable dependency to `examples_step` next to diagnosis:

```zig
    examples_step.dependOn(&causal_remediation_plan_tool.step);
```

- [ ] **Step 5: Verify and commit**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_remediation_plan.zig build.zig
zig build examples
```

Expected: PASS.

Commit:

```sh
git add packages/zigeffect/tools/causal_remediation_plan.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): wire causal remediation plan command"
```

## Task 3: Manifest And Docs Catch-Up

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

- [ ] **Step 1: Update artifact manifest tests first**

In `packages/zigeffect/tools/causal_artifacts.zig`, extend the first test:

```zig
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md") != null);
```

Extend the second test:

```zig
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-diagnosis.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-plan.md") != null);
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because the manifest does not list diagnosis or remediation-plan
paths yet.

- [ ] **Step 2: Update manifest output**

In `appendDefaultLoopArtifacts`, add:

```zig
    try output.print(allocator, "- dev-loop diagnosis {s}/zigeffect-causal-dev-loop-diagnosis.txt\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop remediation plan {s}/zigeffect-causal-dev-loop-remediation-plan.md\n", .{causal_run.artifact_dir});
```

In `appendScenarioLoopArtifacts`, add:

```zig
    try output.print(allocator, "  loop diagnosis: {s}/zigeffect-causal-dev-loop-{s}-diagnosis.txt\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop remediation plan: {s}/zigeffect-causal-dev-loop-{s}-remediation-plan.md\n", .{ causal_run.artifact_dir, slug });
```

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_artifacts.zig
zig build examples
```

Expected: PASS.

- [ ] **Step 3: Update README workflow**

In `packages/zigeffect/README.md`, update the dev-loop paragraph so the after
phase names verdict and diagnosis/remediation follow-up. Replace the paragraph
that starts with "The baseline phase writes" with this text:

```markdown
The baseline phase writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json` and runs the
package-test gate. The after phase writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json`, reruns the
package-test gate, and prints the report paths. Scenario targets use
slug-specific before, after, compare, query-report, advice-report, and verdict
paths under `.zig-cache/causal-artifacts/`.
```

After the advice section, add:

````markdown
Read the local verdict and generate agent-facing follow-up artifacts:

```bash
zig build causal-dev-agent -- local
zig build causal-diagnosis -- local
zig build causal-remediation-plan -- local
```

For scenario targets, pass the same scenario slug:

```bash
zig build causal-dev-agent -- local causal-scoped-fiber
zig build causal-diagnosis -- local causal-scoped-fiber
zig build causal-remediation-plan -- local causal-scoped-fiber
```

`causal-dev-agent` prints the inspection order, `causal-diagnosis` writes
`*-diagnosis.txt`, and `causal-remediation-plan` writes
`*-remediation-plan.md`. All three are deterministic and non-mutating.
````

- [ ] **Step 4: Update agent guide**

In `packages/zigeffect/docs/agent-guide.md`, after the `causal-diagnosis`
paragraph, add:

````markdown
To convert the diagnosis into a bounded, reviewable engineering plan, run:

```sh
zig build causal-remediation-plan -- local
zig build causal-remediation-plan -- local causal-scoped-fiber
```

The command writes `*-remediation-plan.md` with evidence ids, remediation
posture, proposed patch strategy, verification commands, and claim guardrails.
It does not edit source or execute remediation.
````

- [ ] **Step 5: Update scenario docs**

In `packages/zigeffect/docs/causal-scenarios.md`, add the command near
`causal-diagnosis`:

````markdown
Write a reviewable remediation plan from saved dev-loop artifacts:

```sh
zig build causal-remediation-plan -- local [scenario]
```
````

Add artifact paths to the development-loop artifact lists:

```markdown
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-plan.md`
```

Add a short paragraph after the diagnosis paragraph:

```markdown
Then run `zig build causal-remediation-plan -- local [scenario]` when the agent
needs an implementation plan with evidence ids, verification commands, and claim
guardrails. The plan is non-mutating and should be reviewed before source edits.
```

- [ ] **Step 6: Update roadmaps**

In `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`,
add to Milestone 7 delivered slices:

```markdown
- `zig build causal-remediation-plan -- local [scenario]`, which turns local
  diagnosis artifacts into non-mutating remediation plans with evidence ids,
  verification commands, and claim guardrails.
```

In `packages/zigeffect/docs/roadmap.md`, add near the delivered dev-agent and
diagnosis bullets:

```markdown
- Delivered: `zig build causal-remediation-plan -- local [scenario]` writes
  evidence-bound, non-mutating remediation plans from local dev-loop artifacts.
```

- [ ] **Step 7: Verify and commit docs**

Run:

```sh
cd packages/zigeffect
zig build examples
cd ../..
git diff --check
```

Expected: both commands exit zero.

Commit:

```sh
git add packages/zigeffect/tools/causal_artifacts.zig \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/causal-scenarios.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "docs(zigeffect): document causal remediation planning"
```

## Task 4: Integration Verification

**Files:**
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-causal-remediation-plan.md`

- [ ] **Step 1: Verify default remediation plan**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig build causal-diagnosis -- local
zig build causal-remediation-plan -- local
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
rg "# zigeffect causal remediation plan" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
rg "target: dogfood" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
rg "posture: patch-candidate" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
rg 'event 4 `resource_acquired` status=persisting' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
```

Expected: PASS. The plan should preserve multi-word labels in its evidence
section and include dogfood verification commands without a scenario slug.

- [ ] **Step 2: Verify scenario remediation plan**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
zig build causal-diagnosis -- local causal-scoped-fiber
zig build causal-remediation-plan -- local causal-scoped-fiber
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md
rg "target: causal-scoped-fiber" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md
rg "posture: do-not-patch" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md
rg "zig build causal-dev-loop -- baseline causal-scoped-fiber" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md
```

Expected: PASS.

- [ ] **Step 3: Verify missing input failure**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
output=$(zig build causal-remediation-plan -- local 2>&1)
exit_code=$?
printf "%s\n" "$output"
test "$exit_code" -ne 0
printf "%s\n" "$output" | rg "causal-remediation-plan error: MissingRemediationInput"
printf "%s\n" "$output" | rg "usage: zig build causal-remediation-plan -- local \\[scenario\\]"
```

Expected: PASS.

- [ ] **Step 4: Verify manifest paths**

Run:

```sh
cd packages/zigeffect
zig build causal-artifacts > /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-diagnosis.txt" /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-remediation-plan.md" /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt" /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md" /tmp/zigeffect-causal-artifacts.txt
```

Expected: PASS.

- [ ] **Step 5: Run final verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test --summary none
cd ../..
git diff --check
bun run zig:test
```

Expected: all commands exit zero.

- [ ] **Step 6: Commit plan checklist update**

After all verification steps pass, mark Task 4 checklist items complete in this
plan file and commit:

```sh
git add docs/superpowers/plans/2026-06-07-zigeffect-causal-remediation-plan.md
git commit -m "docs(zigeffect): complete causal remediation plan checklist"
```

## Completion Checklist

- [ ] `zig build causal-remediation-plan -- local` works after a default
  after-phase and diagnosis run.
- [ ] `zig build causal-remediation-plan -- local causal-scoped-fiber` works
  after a scenario after-phase and diagnosis run.
- [ ] Remediation plan artifacts are written to stable default and scenario
  paths.
- [ ] Missing inputs fail with clean usage text.
- [ ] Reports cite event ids and artifact paths.
- [ ] Reports preserve `new`, `observed`, and `persisting` semantics in posture
  and claim guardrails.
- [ ] Reports include required verification commands.
- [ ] `zig build causal-artifacts` lists diagnosis and remediation-plan paths.
- [ ] README and agent docs document the command as non-mutating.
- [ ] `zig build examples` includes the new tests and executable.
- [ ] `zig build test --summary none` passes in `packages/zigeffect`.
- [ ] `bun run zig:test` passes at the repo root.
