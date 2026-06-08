# zigeffect Guarded Registry Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-registry-apply`, a guarded application boundary that consumes readiness reports and writes registry application JSON/text artifacts without silently mutating source.

**Architecture:** Create `packages/zigeffect/tools/causal_registry_apply.zig` following the existing causal tool pattern. The tool parses readiness JSON, validates mode-specific application checks, formats schema-versioned JSON/text reports, writes deterministic artifacts, and inspects current source state through `causal_run` plus `docs/causal-scenarios.md`.

**Tech Stack:** Zig 0.16, `std.json`, existing `causal_run` registry APIs, Bun repo verification commands.

---

## Files

- Create: `packages/zigeffect/tools/causal_registry_apply.zig`
  - Owns CLI parsing, readiness parsing, application checks, source-state
    inspection, JSON/text formatting, artifact IO, and unit tests.
- Modify: `packages/zigeffect/build.zig`
  - Adds the tool module, tests, executable, `causal-registry-apply` build
    step, and `examples` dependencies.
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
  - Adds registry application JSON/text paths to the artifact manifest and
    tests.
- Modify: `packages/zigeffect/README.md`
  - Documents command usage after registry application readiness.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds agent guidance for plan vs record-applied application artifacts.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Adds command and artifact paths.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks guarded registry application delivered after implementation.
- Modify:
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Updates the M0 progress ledger after the implementation lands.

## Task 0: Design And Plan Checkpoint

**Files:**

- Create:
  `docs/superpowers/specs/2026-06-08-zigeffect-guarded-registry-application-design.md`
- Create:
  `docs/superpowers/plans/2026-06-08-zigeffect-guarded-registry-application.md`

- [ ] Confirm the design states that this first slice does not auto-edit
  source and only records `applied=true` after source state is already updated.
- [ ] Confirm the plan has exact files, commands, and TDD checkpoints.
- [ ] Run:

```sh
git diff --check
printf '%s\n' \
  '\bTB''D\b' \
  '\bTO''DO\b' \
  'implement late''r' \
  'fill in detail''s' \
  'Similar to Tas''k' \
  'appropriate error handlin''g' > /tmp/zigeffect-guarded-registry-application-patterns.txt
rg -n -f /tmp/zigeffect-guarded-registry-application-patterns.txt docs/superpowers/specs/2026-06-08-zigeffect-guarded-registry-application-design.md docs/superpowers/plans/2026-06-08-zigeffect-guarded-registry-application.md
```

Expected: `git diff --check` prints nothing; `rg` exits nonzero with no
matches.

- [ ] Commit:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-guarded-registry-application-design.md docs/superpowers/plans/2026-06-08-zigeffect-guarded-registry-application.md
git commit -m "docs(zigeffect): plan guarded registry application"
```

## Task 1: Options, Modes, And Output Paths

**Files:**

- Create: `packages/zigeffect/tools/causal_registry_apply.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Add a `causal_registry_apply_tool_module` in `build.zig` without adding
  the executable step yet:

```zig
const causal_registry_apply_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_registry_apply.zig"),
    .target = target,
    .optimize = optimize,
});
causal_registry_apply_tool_module.addImport("causal_run", causal_run_tool_module);

const causal_registry_apply_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-registry-apply-tests",
    .root_module = causal_registry_apply_tool_module,
});
const run_causal_registry_apply_tool_tests = b.addRunArtifact(causal_registry_apply_tool_tests);
```

- [ ] Add `run_causal_registry_apply_tool_tests` to `examples_step` after the
  readiness tool tests.
- [ ] Create `causal_registry_apply.zig` with failing tests:

```zig
const std = @import("std");
const causal_run = @import("causal_run");

const readiness_suffix = "-registry-application-readiness.json";
const application_suffix = "-registry-application";
const readiness_schema = "zigeffect.causal.registry-application-readiness.v1";
const application_schema = "zigeffect.causal.registry-application.v1";

const Mode = enum {
    plan,
    record_applied,
};

test "registry apply parses plan mode and metadata" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        "plan",
        "--reason",
        "prepare manual registry application",
        "--by",
        "local-reviewer",
        "--policy",
        "manual-application",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        options.readiness_path,
    );
    try std.testing.expectEqual(Mode.plan, options.mode);
    try std.testing.expectEqualStrings("local-reviewer", options.applied_by);
    try std.testing.expectEqualStrings("manual-application", options.policy);
    try std.testing.expectEqualStrings("prepare manual registry application", options.reason);
    try std.testing.expectEqual(@as(usize, 0), options.verified_commands.len);
}

test "registry apply parses record-applied verification commands" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json",
        "record-applied",
        "--reason",
        "registry and docs updated",
        "--verified-command",
        "zig build causal-run package-tests",
        "--verified-command",
        "zig build examples",
        "--verified-command",
        "zig build test --summary none",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Mode.record_applied, options.mode);
    try std.testing.expectEqual(@as(usize, 3), options.verified_commands.len);
}

test "registry apply rejects missing path reason unknown mode and bad suffix" {
    try std.testing.expectError(error.MissingReadinessPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
    }));
    try std.testing.expectError(error.InvalidReadinessPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/readiness.json",
        "plan",
        "--reason",
        "x",
    }));
    try std.testing.expectError(error.UnknownMode, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        "apply",
        "--reason",
        "x",
    }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        "plan",
    }));
}

test "registry apply output paths derive from readiness path" {
    const paths = try applicationPathsFromReadiness(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application.txt",
        paths.text,
    );
}
```

- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Confirm the build fails because `parseOptions` and
  `applicationPathsFromReadiness` are missing.
- [ ] Implement `Mode`, `Options`, `ApplicationPaths`, `parseOptions`,
  `applicationPathsFromReadiness`, `modeText`, `usage`, and `failUsage`.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/build.zig packages/zigeffect/tools/causal_registry_apply.zig
git commit -m "feat(zigeffect): add registry apply option parsing"
```

## Task 2: Readiness Parsing And Application Checks

**Files:**

- Modify: `packages/zigeffect/tools/causal_registry_apply.zig`

- [ ] Add readiness/application structs:

```zig
const ApplicationStatus = enum {
    planned,
    applied,
    blocked,
    not_applicable,
};

const CheckStatus = enum {
    pass,
    fail,
    skipped,
};

const ReadinessCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8,
};

const ReadinessReport = struct {
    schema: []const u8,
    schema_version: u32,
    source_registry_patch: []const u8,
    decision: []const u8,
    readiness_status: []const u8,
    decided_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    applied: bool,
    target: []const u8,
    scenario_slug: ?[]const u8 = null,
    checks: []const ReadinessCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    guardrails: []const []const u8 = &.{},
};

const ApplicationCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ApplicationInput = struct {
    source_readiness_path: []const u8,
    readiness_json: []const u8,
    mode: Mode,
    applied_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    verified_commands: []const []const u8,
    scenario_docs: []const u8 = "",
};
```

- [ ] Add sample readiness JSON strings for:
  - applicable `package-tests` readiness;
  - blocked readiness;
  - no-op readiness.
- [ ] Add failing tests:

```zig
test "registry apply plan creates planned report for applicable readiness" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json",
        .readiness_json = sample_applicable_readiness_json,
        .mode = .plan,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "prepare manual application",
        .verified_commands = &.{},
        .scenario_docs = "package-tests",
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.planned, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkPassed(result.checks, "readiness-applicable"));
}

test "registry apply blocks blocked readiness" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        .readiness_json = sample_blocked_readiness_json,
        .mode = .plan,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "blocked readiness cannot apply",
        .verified_commands = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.blocked, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkFailed(result.checks, "readiness-applicable"));
}

test "registry apply records no-op readiness as not applicable" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json",
        .readiness_json = sample_noop_readiness_json,
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "no patch applies",
        .verified_commands = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.not_applicable, result.status);
    try std.testing.expect(!result.applied);
}

test "registry apply record-applied requires source and verification evidence" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json",
        .readiness_json = sample_applicable_readiness_json,
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "registry applied",
        .verified_commands = &.{
            "zig build causal-run package-tests",
            "zig build examples",
            "zig build test --summary none",
        },
        .scenario_docs = "package-tests",
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.applied, result.status);
    try std.testing.expect(result.applied);
    try std.testing.expect(checkPassed(result.checks, "source-registry-present"));
    try std.testing.expect(checkPassed(result.checks, "post-verification-recorded"));
}
```

- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Confirm failures are for missing evaluator structs/functions.
- [ ] Implement `validateReadiness`, `evaluateApplication`,
  `requiredCommandsSatisfied`, `scenarioBySlug`, `scenarioHasPlaceholderArgv`,
  `checkPassed`, `checkFailed`, and `allChecksPassed`.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_registry_apply.zig
git commit -m "feat(zigeffect): evaluate registry application evidence"
```

## Task 3: Application JSON/Text Reports

**Files:**

- Modify: `packages/zigeffect/tools/causal_registry_apply.zig`

- [ ] Add failing tests:

```zig
test "registry apply formats planned json and text reports" {
    const reports = try formatApplicationReports(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json",
        .readiness_json = sample_applicable_readiness_json,
        .mode = .plan,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "prepare manual application",
        .verified_commands = &.{},
        .scenario_docs = "package-tests",
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.registry-application.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"application_status\": \"planned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "application_status: planned") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "applied: false") != null);
}

test "registry apply formats applied report with source paths and verification" {
    const reports = try formatApplicationReports(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json",
        .readiness_json = sample_applicable_readiness_json,
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "registry applied",
        .verified_commands = &.{
            "zig build causal-run package-tests",
            "zig build examples",
            "zig build test --summary none",
        },
        .scenario_docs = "package-tests",
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"application_status\": \"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_registry_patch\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "verified commands:") != null);
}
```

- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Confirm failures are for missing `formatApplicationReports`.
- [ ] Implement `ApplicationReports`, `formatApplicationReports`,
  `formatApplicationJson`, `formatApplicationText`, `applicationStatusText`,
  `checkStatusText`, `applicationGuardrails`, `applicationSteps`,
  `appendChecksJson`, `appendStringArray`, and `appendJsonString`.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_registry_apply.zig
git commit -m "feat(zigeffect): format registry application reports"
```

## Task 4: CLI IO And Build Step

**Files:**

- Modify: `packages/zigeffect/tools/causal_registry_apply.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Add executable wiring in `build.zig` after
  `causal-registry-application-readiness`:

```zig
const causal_registry_apply_tool = b.addExecutable(.{
    .name = "zigeffect-causal-registry-apply",
    .root_module = causal_registry_apply_tool_module,
});
const run_causal_registry_apply_tool = b.addRunArtifact(causal_registry_apply_tool);
if (b.args) |args| run_causal_registry_apply_tool.addArgs(args);
const causal_registry_apply_step = b.step("causal-registry-apply", "Write a guarded causal registry application report");
causal_registry_apply_step.dependOn(&run_causal_registry_apply_tool.step);
```

- [ ] Add `causal_registry_apply_tool.step` to `examples_step` after the
  readiness tool.
- [ ] Add artifact IO helpers:

```zig
fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8;
fn readOptionalArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8;
fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void;
fn runFromReadiness(init: std.process.Init, options: Options) !void;
pub fn main(init: std.process.Init) !void;
```

- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Run an integration chain that produces a not-applicable readiness report:

```sh
cd packages/zigeffect
zig build causal-dev-session -- start causal-scoped-fiber
zig build causal-dev-session -- assess causal-scoped-fiber
zig build causal-remediation-decision -- local approve causal-scoped-fiber --reason "registry application no-op check"
zig build causal-patch-proposal -- local approved causal-scoped-fiber --summary "registry application no-op" --file packages/zigeffect/examples/causal_scoped_fiber.zig --change "keep clear scenario as no-op"
zig build causal-audit-chain -- local causal-scoped-fiber
zig build causal-scenario-proposal -- local causal-scoped-fiber
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json
zig build causal-registry-application-readiness -- --from-registry-patch .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json approve --reason "no registry patch applies"
zig build causal-registry-apply -- --from-readiness .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json plan --reason "no registry patch applies"
```

Expected: application report prints `application_status: not-applicable` and
`applied: false`.

- [ ] Commit:

```sh
git add packages/zigeffect/build.zig packages/zigeffect/tools/causal_registry_apply.zig
git commit -m "feat(zigeffect): write registry application artifacts"
```

## Task 5: Artifact Manifest And Documentation

**Files:**

- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify:
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] Add default artifact manifest paths:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application.txt
```

- [ ] Add scenario artifact manifest paths:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-application.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-application.txt
```

- [ ] Add manifest tests for default and `package-tests` paths.
- [ ] Update docs to show:

```sh
zig build causal-registry-apply -- --from-readiness <registry-application-readiness.json> plan --reason "prepare manual registry application"
zig build causal-registry-apply -- --from-readiness <registry-application-readiness.json> record-applied --reason "registry and docs updated" --verified-command "zig build examples"
```

- [ ] Explain that `plan` writes `applied=false` and `record-applied` writes
  `applied=true` only after current source state and verification command
  evidence pass.
- [ ] Mark M0 delivered in package and master roadmaps after the implementation
  verification passes.
- [ ] Run:

```sh
git diff --check
cd packages/zigeffect && zig build causal-artifacts
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
```

- [ ] Commit:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-scenarios.md packages/zigeffect/docs/roadmap.md packages/zigeffect/tools/causal_artifacts.zig
git commit -m "docs(zigeffect): document guarded registry application"
```

## Final Verification

- [ ] Run:

```sh
git status --short --branch
git diff --check
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
bun run check
bun run zig:test
```

- [ ] Confirm the branch contains only intended commits:

```sh
git log --oneline --decorate master..HEAD
```

- [ ] Use the finishing branch workflow to merge, push, or preserve the branch
  according to the user's requested integration path.
