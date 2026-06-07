# zigeffect Causal Remediation Decision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-remediation-decision -- local approve|reject [scenario] ...`, a deterministic non-mutating command that writes append-only approval or rejection records for local remediation audits.

**Architecture:** Create `packages/zigeffect/tools/causal_remediation_decision.zig` as a focused artifact reader/formatter. It reads `*-remediation-audit.json`, validates the pending audit state, parses approve/reject metadata, and writes `*-remediation-decision.json` plus `*-remediation-decision.txt` without editing source or rewriting the audit. Update build wiring, artifact manifest, README, agent docs, scenario docs, and roadmaps.

**Tech Stack:** Zig 0.16 build system, Zig std JSON parser, existing `causal_run` scenario registry and artifact directory, existing causal remediation audit artifact conventions, Bun repo verification commands.

---

## File Structure

- Create `packages/zigeffect/tools/causal_remediation_decision.zig`
  - Default and scenario path helpers for audit input and decision outputs.
  - Audit JSON shape and schema validation.
  - CLI decision parser for `approve|reject`, optional scenario, `--by`, `--policy`, and `--reason`.
  - Deterministic JSON formatter for `zigeffect.causal.remediation-decision.v1`.
  - Human text report formatter.
  - Artifact reader/writer and CLI `main`.
  - Unit tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, run step, tests, and `examples` dependencies.
  - Import `causal_run`.
- Modify `packages/zigeffect/tools/causal_artifacts.zig`
  - Add default and scenario decision JSON/text paths to the retention manifest.
  - Strengthen manifest tests.
- Modify `packages/zigeffect/README.md`
  - Document the decision command after remediation audit.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Add approved/rejected decision records to the local self-improvement workflow.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  - Add decision command and artifact paths.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Mark remediation decision as delivered after implementation.
- Modify `packages/zigeffect/docs/roadmap.md`
  - Mention the delivered decision artifact after implementation.

## Task 1: Decision Parser, Formatter, And Schema

**Files:**
- Create: `packages/zigeffect/tools/causal_remediation_decision.zig`
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Write failing parser and formatter tests**

Create `packages/zigeffect/tools/causal_remediation_decision.zig` with these
initial types, fixtures, and tests. These tests intentionally reference helpers
that do not exist yet.

```zig
const std = @import("std");
const causal_run = @import("causal_run");

const audit_schema = "zigeffect.causal.remediation-audit.v1";
const decision_schema = "zigeffect.causal.remediation-decision.v1";

const AuditSource = struct {
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8,
};

const AuditRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    proposer: []const u8,
    approval_status: []const u8,
    applied: bool,
    posture: []const u8,
    source: AuditSource,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
};

const DecisionKind = enum {
    approved,
    rejected,
};

const DecisionOptions = struct {
    mode: []const u8,
    kind: DecisionKind,
    scenario_slug: ?[]const u8 = null,
    decided_by: []const u8 = "local-reviewer",
    policy: []const u8 = "none",
    reason: []const u8,
};

const DecisionInput = struct {
    audit_path: []const u8,
    audit: AuditRecord,
    options: DecisionOptions,
};

const approved_audit_json =
    \\{
    \\  "schema": "zigeffect.causal.remediation-audit.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "proposer": "local-agent",
    \\  "approval_status": "pending",
    \\  "applied": false,
    \\  "posture": "patch-candidate",
    \\  "source": {
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt"
    \\  },
    \\  "event_ids": [3, 4, 5, 6],
    \\  "verification_commands": ["zig build causal-dev-loop -- baseline", "zig build causal-dev-loop -- after", "zig build causal-diagnosis -- local", "zig build test --summary none"],
    \\  "claim_guardrails": ["Do not claim this patch fixed persisting evidence unless the after verdict is clear or the compare report shows fewer findings."]
    \\}
;

test "decision output paths are stable for default and scenario targets" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json",
        localDecisionJsonPath(),
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.txt",
        localDecisionTextPath(),
    );

    const scenario_json = try localDecisionJsonPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_json);
    const scenario_text = try localDecisionTextPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_text);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json",
        scenario_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.txt",
        scenario_text,
    );
}

test "parse options accepts approve defaults and optional metadata" {
    const args = [_][]const u8{
        "zigeffect-causal-remediation-decision",
        "local",
        "approve",
        "--by",
        "local-reviewer",
        "--policy",
        "manual-review",
    };

    const options = try parseDecisionOptions(args[0..]);
    try std.testing.expectEqual(DecisionKind.approved, options.kind);
    try std.testing.expect(options.scenario_slug == null);
    try std.testing.expectEqualStrings("local-reviewer", options.decided_by);
    try std.testing.expectEqualStrings("manual-review", options.policy);
    try std.testing.expectEqualStrings("reviewed local remediation audit", options.reason);
}

test "parse options accepts reject scenario and requires reason" {
    const args = [_][]const u8{
        "zigeffect-causal-remediation-decision",
        "local",
        "reject",
        "causal-scoped-fiber",
        "--reason",
        "clear verdict",
    };

    const options = try parseDecisionOptions(args[0..]);
    try std.testing.expectEqual(DecisionKind.rejected, options.kind);
    try std.testing.expectEqualStrings("causal-scoped-fiber", options.scenario_slug.?);
    try std.testing.expectEqualStrings("clear verdict", options.reason);

    const missing_reason = [_][]const u8{
        "zigeffect-causal-remediation-decision",
        "local",
        "reject",
    };
    try std.testing.expectError(error.MissingRejectionReason, parseDecisionOptions(missing_reason[0..]));
}

test "audit validation rejects non pending or applied audits" {
    var parsed = try std.json.parseFromSlice(AuditRecord, std.testing.allocator, approved_audit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try validateAuditRecord(parsed.value);

    var non_pending = parsed.value;
    non_pending.approval_status = "approved";
    try std.testing.expectError(error.AuditAlreadyDecided, validateAuditRecord(non_pending));

    var applied = parsed.value;
    applied.applied = true;
    try std.testing.expectError(error.AuditAlreadyApplied, validateAuditRecord(applied));
}

test "decision JSON records approval without applying source changes" {
    var parsed = try std.json.parseFromSlice(AuditRecord, std.testing.allocator, approved_audit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const json = try formatDecisionJson(std.testing.allocator, .{
        .audit_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        .audit = parsed.value,
        .options = .{
            .mode = "local",
            .kind = .approved,
            .decided_by = "local-reviewer",
            .policy = "manual-review",
            .reason = "reviewed local remediation audit",
        },
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.remediation-decision.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"decision\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approval_status\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"audit\": \".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"event_ids\": [3, 4, 5, 6]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"Approval does not apply source changes.\"") != null);
}

test "decision text records rejection reason and guardrails" {
    var parsed = try std.json.parseFromSlice(AuditRecord, std.testing.allocator, approved_audit_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const text = try formatDecisionText(std.testing.allocator, .{
        .audit_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        .audit = parsed.value,
        .options = .{
            .mode = "local",
            .kind = .rejected,
            .decided_by = "local-reviewer",
            .policy = "none",
            .reason = "intentional fixture",
        },
    });
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect causal remediation decision") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "decision: rejected") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "reason: intentional fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Rejected proposals must not be used as permission for source edits.") != null);
}
```

- [x] **Step 2: Wire only the test module and verify red**

Modify `packages/zigeffect/build.zig` after `causal_remediation_audit_tool_module`:

```zig
    const causal_remediation_decision_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_remediation_decision.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_remediation_decision_tool_module.addImport("causal_run", causal_run_tool_module);

    const causal_remediation_decision_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-remediation-decision-tests",
        .root_module = causal_remediation_decision_tool_module,
    });
    const run_causal_remediation_decision_tool_tests = b.addRunArtifact(causal_remediation_decision_tool_tests);
```

Add only the test dependency near the other `examples_step` causal tool tests:

```zig
    examples_step.dependOn(&run_causal_remediation_decision_tool_tests.step);
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because path helpers, option parsing, audit validation, and
formatters are missing.

- [x] **Step 3: Implement parser, validation, and deterministic formatters**

Implement these helpers in `causal_remediation_decision.zig`:

```zig
fn localAuditJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.json";
}

fn localAuditJsonPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn localDecisionJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-decision.json";
}

fn localDecisionTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-decision.txt";
}
```

Also add scenario variants for decision JSON and text paths using
`zigeffect-causal-dev-loop-<scenario>-remediation-decision.{json,txt}`.

Implement `parseDecisionOptions(args)` with these rules:

- `args[1]` must be `local`;
- `args[2]` must be `approve` or `reject`;
- one optional non-flag token is the scenario slug;
- supported flags are `--by <actor>`, `--policy <policy>`, and `--reason <reason>`;
- approve defaults reason to `reviewed local remediation audit`;
- reject requires `--reason`;
- duplicate scenario or missing flag value returns usage-style errors.

Implement `validateAuditRecord`:

```zig
fn validateAuditRecord(audit: AuditRecord) !void {
    if (!std.mem.eql(u8, audit.schema, audit_schema)) return error.UnsupportedAuditSchema;
    if (audit.schema_version != 1) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.mode, "local")) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.approval_status, "pending")) return error.AuditAlreadyDecided;
    if (audit.applied) return error.AuditAlreadyApplied;
}
```

Implement JSON/text formatting with a local `appendJsonString` helper matching
the escaping behavior in `causal_remediation_audit.zig`. Use deterministic field
order from the design spec.

Decision guardrails:

- approved: `Approval does not apply source changes.`, `Run required verification after any future patch before claiming a fix.`
- rejected: `Rejected proposals must not be used as permission for source edits.`, `Create a new audit if evidence changes.`

- [x] **Step 4: Run green verification for Task 1**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_remediation_decision.zig build.zig
zig build examples
```

Expected: PASS.

- [x] **Step 5: Commit Task 1**

Run:

```sh
git add packages/zigeffect/tools/causal_remediation_decision.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "feat(zigeffect): add causal remediation decision formatter"
```

## Task 2: CLI Artifact Reader And Build Step

**Files:**
- Modify: `packages/zigeffect/tools/causal_remediation_decision.zig`
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add failing CLI/path tests**

Add tests for usage text, local input paths, and scenario path validation:

```zig
test "usage names local decision shape" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-remediation-decision -- local approve|reject [scenario] [--by <actor>] [--policy <policy>] [--reason <reason>]\n",
        usage(),
    );
}

test "audit paths are stable for default and scenario targets" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        localAuditJsonPath(),
    );

    const scenario = try localAuditJsonPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
        scenario,
    );
}
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because CLI helpers or executable wiring are still incomplete.

- [x] **Step 2: Implement artifact IO and `runLocal`**

Add IO helpers:

```zig
fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingRemediationDecisionInput,
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

`runLocal` must:

1. Resolve default or scenario audit path from parsed options.
2. Read audit JSON.
3. Parse `AuditRecord` with `.ignore_unknown_fields = true`.
4. Validate schema/version/local/pending/not-applied.
5. Format decision JSON and text.
6. Write both decision artifacts.
7. Print the text report.

- [x] **Step 3: Implement CLI `main` and usage errors**

Add:

```zig
fn usage() []const u8 {
    return "usage: zig build causal-remediation-decision -- local approve|reject [scenario] [--by <actor>] [--policy <policy>] [--reason <reason>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-remediation-decision error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}
```

`main` must:

- parse args with `parseDecisionOptions`;
- validate `options.scenario_slug` with `causal_run.scenarioByName` when present;
- map usage-style errors to exit code `2`.

Usage-style errors:

```zig
error.MissingMode,
error.UnknownMode,
error.MissingDecision,
error.UnknownDecision,
error.TooManyArguments,
error.DuplicateScenarioArgument,
error.UnknownFlag,
error.MissingFlagValue,
error.MissingRejectionReason,
error.MissingRemediationDecisionInput,
error.UnsupportedAuditSchema,
error.AuditAlreadyDecided,
error.AuditAlreadyApplied,
error.InvalidArtifactPath,
```

- [x] **Step 4: Wire executable build step**

Modify `packages/zigeffect/build.zig` after the audit executable:

```zig
    const causal_remediation_decision_tool = b.addExecutable(.{
        .name = "zigeffect-causal-remediation-decision",
        .root_module = causal_remediation_decision_tool_module,
    });
    const run_causal_remediation_decision_tool = b.addRunArtifact(causal_remediation_decision_tool);
    if (b.args) |args| run_causal_remediation_decision_tool.addArgs(args);
    const causal_remediation_decision_step = b.step("causal-remediation-decision", "Approve or reject a pending causal remediation audit");
    causal_remediation_decision_step.dependOn(&run_causal_remediation_decision_tool.step);
```

Add the executable dependency to `examples_step`:

```zig
    examples_step.dependOn(&causal_remediation_decision_tool.step);
```

- [x] **Step 5: Run green verification for Task 2**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_remediation_decision.zig build.zig
zig build examples
```

Expected: PASS.

- [x] **Step 6: Commit Task 2**

Run:

```sh
git add packages/zigeffect/tools/causal_remediation_decision.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "feat(zigeffect): wire causal remediation decision command"
```

## Task 3: Manifest And Documentation Catch-Up

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

- [x] **Step 1: Write failing manifest expectations**

In `packages/zigeffect/tools/causal_artifacts.zig`, extend the default manifest
test with:

```zig
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.txt") != null);
```

Extend the scenario manifest test with:

```zig
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-decision.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-remediation-decision.txt") != null);
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because the manifest does not print decision paths yet.

- [x] **Step 2: Add decision paths to manifest output**

In `appendDefaultLoopArtifacts`, print:

```zig
    try output.print(allocator, "- dev-loop remediation decision json {s}/zigeffect-causal-dev-loop-remediation-decision.json\n", .{causal_run.artifact_dir});
    try output.print(allocator, "- dev-loop remediation decision text {s}/zigeffect-causal-dev-loop-remediation-decision.txt\n", .{causal_run.artifact_dir});
```

In `appendScenarioLoopArtifacts`, print:

```zig
    try output.print(allocator, "  loop remediation decision json: {s}/zigeffect-causal-dev-loop-{s}-remediation-decision.json\n", .{ causal_run.artifact_dir, slug });
    try output.print(allocator, "  loop remediation decision text: {s}/zigeffect-causal-dev-loop-{s}-remediation-decision.txt\n", .{ causal_run.artifact_dir, slug });
```

- [x] **Step 3: Update docs**

Update `packages/zigeffect/README.md`, `packages/zigeffect/docs/agent-guide.md`,
and `packages/zigeffect/docs/causal-scenarios.md` so the local workflow reads:

```sh
zig build causal-dev-loop -- baseline [scenario]
zig build causal-dev-loop -- after [scenario]
zig build causal-dev-agent -- local [scenario]
zig build causal-diagnosis -- local [scenario]
zig build causal-remediation-plan -- local [scenario]
zig build causal-remediation-audit -- local [scenario]
zig build causal-remediation-decision -- local approve|reject [scenario] ...
```

Document the new artifacts:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.txt
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-decision.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-decision.txt
```

Update both roadmap files:

- mark remediation decision as delivered;
- keep patch proposal artifacts, policy engine, application command, and
  app-facing loops as remaining work.

- [x] **Step 4: Run green verification for Task 3**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_artifacts.zig
zig build examples
```

Expected: PASS.

- [x] **Step 5: Commit Task 3**

Run:

```sh
git add packages/zigeffect/tools/causal_artifacts.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-scenarios.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/docs/roadmap.md
git diff --cached --check
git commit -m "docs(zigeffect): document causal remediation decision"
```

## Task 4: Integration Verification And Checklist Close

**Files:**
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-causal-remediation-decision.md`

- [x] **Step 1: Verify default approval flow**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig build causal-diagnosis -- local
zig build causal-remediation-plan -- local
zig build causal-remediation-audit -- local
zig build causal-remediation-decision -- local approve --by local-reviewer --policy manual-review
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.txt
rg '"schema": "zigeffect.causal.remediation-decision.v1"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
rg '"decision": "approved"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
rg '"approval_status": "approved"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
rg '"applied": false' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
rg '"policy": "manual-review"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
rg '"event_ids": \\[3, 4, 5, 6\\]' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
rg 'Approval does not apply source changes' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.txt
```

Expected: all commands exit zero. If the dogfood event ids change because the
fixture changes, inspect the generated audit and update only the exact event-id
assertion to match the new deterministic fixture.

- [x] **Step 2: Verify scenario rejection flow**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
zig build causal-diagnosis -- local causal-scoped-fiber
zig build causal-remediation-plan -- local causal-scoped-fiber
zig build causal-remediation-audit -- local causal-scoped-fiber
zig build causal-remediation-decision -- local reject causal-scoped-fiber --reason "clear verdict"
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.txt
rg '"target": "causal-scoped-fiber"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json
rg '"decision": "rejected"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json
rg '"approval_status": "rejected"' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json
rg '"event_ids": \\[\\]' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json
rg 'Rejected proposals must not be used as permission for source edits' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.txt
```

Expected: all commands exit zero.

- [x] **Step 3: Verify rejection requires reason and missing audit fails**

Run:

```sh
cd packages/zigeffect
output=$(zig build causal-remediation-decision -- local reject causal-scoped-fiber 2>&1)
exit_code=$?
printf "%s\n" "$output"
test "$exit_code" -ne 0
printf "%s\n" "$output" | rg "causal-remediation-decision error: MissingRejectionReason"
printf "%s\n" "$output" | rg "usage: zig build causal-remediation-decision -- local approve\\|reject"

rm -rf .zig-cache/causal-artifacts
output=$(zig build causal-remediation-decision -- local approve 2>&1)
exit_code=$?
printf "%s\n" "$output"
test "$exit_code" -ne 0
printf "%s\n" "$output" | rg "causal-remediation-decision error: MissingRemediationDecisionInput"
```

Expected: both command groups exit zero because the commands fail as intended
and the assertions match the stable error output.

- [x] **Step 4: Verify already-decided audit is rejected**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig build causal-diagnosis -- local
zig build causal-remediation-plan -- local
zig build causal-remediation-audit -- local
perl -0pi -e 's/"approval_status": "pending"/"approval_status": "approved"/' .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
output=$(zig build causal-remediation-decision -- local approve 2>&1)
exit_code=$?
printf "%s\n" "$output"
test "$exit_code" -ne 0
printf "%s\n" "$output" | rg "causal-remediation-decision error: AuditAlreadyDecided"
```

Expected: command exits nonzero and reports `AuditAlreadyDecided`.

- [x] **Step 5: Verify manifest paths**

Run:

```sh
cd packages/zigeffect
zig build causal-artifacts > /tmp/zigeffect-causal-artifacts.txt 2>&1
rg "zigeffect-causal-dev-loop-remediation-decision.json" /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-remediation-decision.txt" /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json" /tmp/zigeffect-causal-artifacts.txt
rg "zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.txt" /tmp/zigeffect-causal-artifacts.txt
```

Expected: all commands exit zero.

- [x] **Step 6: Run full verification**

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

- [x] **Step 7: Mark this implementation plan complete**

Update every completed checkbox in this file from `- [ ]` to `- [x]`.

- [x] **Step 8: Commit final checklist update**

Run:

```sh
git add docs/superpowers/plans/2026-06-07-zigeffect-causal-remediation-decision.md
git diff --cached --check
git commit -m "docs(zigeffect): complete causal remediation decision checklist"
```

## Completion Checklist

- [x] `causal-remediation-decision` writes default approval JSON and text
  decision artifacts.
- [x] `causal-remediation-decision` writes scenario rejection JSON and text
  decision artifacts.
- [x] Decision JSON uses schema `zigeffect.causal.remediation-decision.v1`.
- [x] Decision JSON and text show `applied=false`.
- [x] Approved decisions show `approval_status=approved`.
- [x] Rejected decisions show `approval_status=rejected` and a required reason.
- [x] Decision artifacts cite source audit, verdict, diagnosis, remediation plan,
  advice, query, and compare paths.
- [x] Decision artifacts copy event ids, verification commands, and claim
  guardrails from the audit.
- [x] Decision artifacts include decision guardrails.
- [x] Reject without `--reason` fails with stable usage text.
- [x] Missing audit input fails with stable usage text.
- [x] Non-pending audit input fails with `AuditAlreadyDecided`.
- [x] Manifest, README, agent guide, causal scenarios, and roadmap docs mention
  the decision command and artifacts.
- [x] `zig build examples` passes in `packages/zigeffect`.
- [x] `zig build test --summary none` passes in `packages/zigeffect`.
- [x] `bun run zig:test` passes at the repo root.

## Self-Review

- Spec coverage: this plan implements every requirement in
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-remediation-decision-design.md`:
  command shape, append-only artifacts, schema, parsing rules, pending audit
  validation, docs, manifest, default approval, scenario rejection, missing
  input failure, missing rejection reason, and non-pending audit rejection.
- Placeholder scan: no placeholder tokens or vague incomplete instructions
  remain.
- Type consistency: `AuditSource`, `AuditRecord`, `DecisionKind`,
  `DecisionOptions`, and `DecisionInput` are used consistently across parser,
  formatter, CLI, and integration tasks.
