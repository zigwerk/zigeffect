# zigeffect Causal Registry Application Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a non-mutating readiness gate that consumes `zigeffect.causal.registry-patch.v1`, records reviewer intent, validates registry/docs/verification evidence, and writes auditable JSON/text readiness artifacts.

**Architecture:** Create `packages/zigeffect/tools/causal_registry_application_readiness.zig` as a focused parser, validator, checker, report formatter, and artifact writer. It follows the existing causal tool pattern: schema-versioned input, deterministic output paths, local registry inspection through `causal_run`, JSON/text outputs, build wiring, artifact manifest entries, and docs updates. It never edits source and always emits `applied=false`.

**Tech Stack:** Zig 0.16, existing `causal_run` registry APIs, Zig std JSON parser, Bun repo verification commands.

---

## Files

- Create: `packages/zigeffect/tools/causal_registry_application_readiness.zig`
  - Owns CLI parsing, registry patch structs, readiness checks, output path
    derivation, JSON/text formatting, artifact IO, and unit tests.
- Modify: `packages/zigeffect/build.zig`
  - Adds the tool module, tests, executable, build step, and examples aggregate
    dependencies.
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
  - Adds registry application-readiness JSON/text paths to the retention
    manifest and manifest tests.
- Modify: `packages/zigeffect/README.md`
  - Documents command usage after `causal-scenario-registry-patch`.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds agent guidance for treating readiness as the next review boundary.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Adds command and artifact paths.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks the readiness gate delivered after implementation.
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Updates the remediation-control roadmap with the readiness gate.
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`
  - Updates Milestone 5 next/delivered text.

## Tasks

### Task 0: Documentation Checkpoint

**Files:**
- Create:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-registry-application-readiness-design.md`
- Create:
  `docs/superpowers/plans/2026-06-07-zigeffect-causal-registry-application-readiness.md`

- [ ] Write the design with command shape, schemas, readiness statuses,
  validation checks, output artifacts, and acceptance criteria.
- [ ] Write this implementation plan with files, scope, TDD checkpoints, and
  verification commands.
- [ ] Run:

```sh
git diff --check
printf '%s\n' \
  '\bTB''D\b' \
  '\bTO''DO\b' \
  'implement late''r' \
  'fill in detail''s' \
  'Similar to Tas''k' \
  'appropriate error handlin''g' > /tmp/zigeffect-registry-readiness-plan-patterns.txt
rg -n -f /tmp/zigeffect-registry-readiness-plan-patterns.txt docs/superpowers/specs/2026-06-07-zigeffect-causal-registry-application-readiness-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-registry-application-readiness.md
```

Expected: `git diff --check` prints nothing; `rg` exits nonzero with no
matches.

- [ ] Commit:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-registry-application-readiness-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-registry-application-readiness.md
git commit -m "docs(zigeffect): plan causal registry application readiness"
```

### Task 1: Options, Paths, And CLI Shape

**Files:**
- Create: `packages/zigeffect/tools/causal_registry_application_readiness.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Add a new tool module in `build.zig` without adding an executable step.
- [ ] Write failing tests:

```zig
test "registry readiness parses approve decision and verified commands" {
    const options = try parseOptions(&.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        "approve",
        "--reason",
        "reviewed registry entry and docs",
        "--by",
        "local-reviewer",
        "--policy",
        "manual-review",
        "--verified-command",
        "zig build causal-run learned-dogfood-service-resolution",
        "--verified-command",
        "zig build examples",
    });

    defer options.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        options.registry_patch_path,
    );
    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings("local-reviewer", options.decided_by);
    try std.testing.expectEqualStrings("manual-review", options.policy);
    try std.testing.expectEqualStrings("reviewed registry entry and docs", options.reason);
    try std.testing.expectEqual(@as(usize, 2), options.verified_commands.len);
}

test "registry readiness rejects missing path reason and unknown flags" {
    try std.testing.expectError(error.MissingRegistryPatchPath, parseOptions(&.{
        "zigeffect-causal-registry-application-readiness",
    }));
    try std.testing.expectError(error.InvalidRegistryPatchPath, parseOptions(&.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        "registry-patch.json",
        "approve",
        "--reason",
        "x",
    }));
    try std.testing.expectError(error.MissingReason, parseOptions(&.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        "reject",
    }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        "approve",
        "--reason",
        "x",
        "--actor",
        "reviewer",
    }));
}

test "registry readiness output paths are derived from registry patch path" {
    const paths = try readinessPathsFromRegistryPatch(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.txt",
        paths.text,
    );
}
```

- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Confirm tests fail because the helper functions are missing.
- [ ] Implement:

```zig
const registry_patch_suffix = "-registry-patch.json";
const readiness_suffix = "-registry-application-readiness";

const Decision = enum { approve, reject };

const Options = struct {
    registry_patch_path: []const u8,
    decision: Decision,
    decided_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-review",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        allocator.free(self.verified_commands);
    }
};

const ReadinessPaths = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ReadinessPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};
```

- [ ] Implement `parseOptions`, `readinessPathsFromRegistryPatch`, `decisionText`,
  `usage`, and `failUsage`.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_registry_application_readiness.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal registry readiness option parsing"
```

### Task 2: Registry Patch Parsing And Readiness Checks

**Files:**
- Modify: `packages/zigeffect/tools/causal_registry_application_readiness.zig`

- [ ] Add sample registry patch JSON strings:

```zig
const sample_add_registry_patch_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-patch.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
    \\  "recommendation": "add-scenario",
    \\  "patch_status": "review-required",
    \\  "target": "dogfood",
    \\  "scenario_slug": "learned-dogfood-service-resolution",
    \\  "scenario_conflict": false,
    \\  "known_invariant_ids": [],
    \\  "new_invariant_ids": ["service-resolution-errors-are-causal"],
    \\  "review_checklist": ["Replace placeholder argv with the smallest reproducing command."],
    \\  "guardrails": ["This registry patch is generated from evidence but requires explicit review."]
    \\}
;

const sample_noop_registry_patch_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-patch.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
    \\  "recommendation": "none",
    \\  "patch_status": "no-op",
    \\  "target": "causal-scoped-fiber",
    \\  "scenario_slug": null,
    \\  "scenario_conflict": false,
    \\  "known_invariant_ids": [],
    \\  "new_invariant_ids": [],
    \\  "review_checklist": ["Confirm no scenario or invariant change is needed for clear evidence."],
    \\  "guardrails": ["Do not apply registry changes for no-op proposals."]
    \\}
;

const sample_refine_existing_registry_patch_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-patch.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
    \\  "recommendation": "refine-scenario",
    \\  "patch_status": "review-required",
    \\  "target": "causal-scoped-fiber",
    \\  "scenario_slug": "causal-scoped-fiber",
    \\  "scenario_conflict": false,
    \\  "known_invariant_ids": ["scoped-fiber-must-finish-before-scope-close"],
    \\  "new_invariant_ids": [],
    \\  "review_checklist": ["Run the scenario after applying the registry patch."],
    \\  "guardrails": ["This registry patch is generated from evidence but requires explicit review."]
    \\}
;
```

- [ ] Write failing tests:

```zig
test "registry readiness marks no-op patches not applicable" {
    const result = try evaluateReadiness(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        .registry_patch_json = sample_noop_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "clear evidence needs no scenario change",
        .verified_commands = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.not_applicable, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkPassed(result.checks, "registry-patch-schema"));
}

test "registry readiness blocks approved add scenario when source is not applied" {
    const result = try evaluateReadiness(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        .registry_patch_json = sample_add_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "reviewed generated draft",
        .verified_commands = &.{
            "zig build causal-run learned-dogfood-service-resolution",
            "zig build examples",
            "zig build test --summary none",
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.blocked, result.status);
    try std.testing.expect(checkFailed(result.checks, "scenario-present"));
    try std.testing.expect(checkFailed(result.checks, "invariant-catalog-consistent"));
}

test "registry readiness approves existing refined scenario with evidence" {
    const result = try evaluateReadiness(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        .registry_patch_json = sample_refine_existing_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "existing scenario and invariant are reviewed",
        .verified_commands = &.{
            "zig build causal-run causal-scoped-fiber",
            "zig build examples",
            "zig build test --summary none",
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.applicable, result.status);
    try std.testing.expect(checkPassed(result.checks, "scenario-present"));
    try std.testing.expect(checkPassed(result.checks, "placeholder-argv-replaced"));
    try std.testing.expect(checkPassed(result.checks, "invariant-catalog-consistent"));
    try std.testing.expect(checkPassed(result.checks, "required-verification-recorded"));
}

test "registry readiness rejects unsupported schema and missing reason" {
    var parsed = try std.json.parseFromSlice(RegistryPatch, std.testing.allocator, sample_refine_existing_registry_patch_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var bad_schema = parsed.value;
    bad_schema.schema = "other.schema";
    try std.testing.expectError(error.UnsupportedRegistryPatchSchema, validateRegistryPatch(bad_schema));

    try std.testing.expectError(error.MissingReason, evaluateReadiness(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        .registry_patch_json = sample_refine_existing_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "",
        .verified_commands = &.{},
    }));
}
```

- [ ] Implement:

```zig
const readiness_schema = "zigeffect.causal.registry-application-readiness.v1";
const registry_patch_schema = "zigeffect.causal.registry-patch.v1";

const ReadinessStatus = enum { applicable, blocked, not_applicable };
const CheckStatus = enum { pass, fail, skipped };

const RegistryPatch = struct {
    schema: []const u8,
    schema_version: u32,
    source_proposal: []const u8,
    recommendation: []const u8,
    patch_status: []const u8,
    target: []const u8,
    scenario_slug: ?[]const u8 = null,
    scenario_conflict: bool,
    known_invariant_ids: []const []const u8 = &.{},
    new_invariant_ids: []const []const u8 = &.{},
    review_checklist: []const []const u8 = &.{},
    guardrails: []const []const u8 = &.{},
};

const ReadinessCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ReadinessInput = struct {
    source_registry_patch_path: []const u8,
    registry_patch_json: []const u8,
    decision: Decision,
    decided_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    verified_commands: []const []const u8,
    scenario_docs: []const u8 = "",
};
```

- [ ] Implement `validateRegistryPatch`, `evaluateReadiness`, `requiredVerificationCommands`,
  `scenarioHasPlaceholderArgv`, `appendCheck`, `checkPassed`, `checkFailed`,
  and `statusText`.
- [ ] Implement docs check from `ReadinessInput.scenario_docs`. Task 4 reads
  `packages/zigeffect/docs/causal-scenarios.md` and passes its contents into
  the evaluator.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_registry_application_readiness.zig
git commit -m "feat(zigeffect): evaluate causal registry readiness"
```

### Task 3: Readiness Report Formatting

**Files:**
- Modify: `packages/zigeffect/tools/causal_registry_application_readiness.zig`

- [ ] Write failing tests:

```zig
test "registry readiness formats blocked approval reports" {
    const reports = try formatReadinessReports(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        .registry_patch_json = sample_add_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "reviewed generated draft",
        .verified_commands = &.{
            "zig build causal-run learned-dogfood-service-resolution",
            "zig build examples",
            "zig build test --summary none",
        },
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.registry-application-readiness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"readiness_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "readiness_status: blocked") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "scenario-present: fail") != null);
}

test "registry readiness formats applicable approval reports" {
    const reports = try formatReadinessReports(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        .registry_patch_json = sample_refine_existing_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "existing scenario and invariant are reviewed",
        .verified_commands = &.{
            "zig build causal-run causal-scoped-fiber",
            "zig build examples",
            "zig build test --summary none",
        },
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"readiness_status\": \"applicable\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "required verification:") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zig build causal-run causal-scoped-fiber") != null);
}

test "registry readiness formats rejection as blocked" {
    const reports = try formatReadinessReports(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        .registry_patch_json = sample_refine_existing_registry_patch_json,
        .decision = .reject,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "reviewer chose not to apply registry coverage",
        .verified_commands = &.{},
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"decision\": \"reject\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"readiness_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "reviewer chose not to apply registry coverage") != null);
}
```

- [ ] Implement `ReadinessReports`, `formatReadinessReports`,
  `formatReadinessJson`, `formatReadinessText`, JSON escaping, check array
  formatting, and command array formatting.
- [ ] Run `cd packages/zigeffect && zig build examples`.
- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_registry_application_readiness.zig
git commit -m "feat(zigeffect): format causal registry readiness reports"
```

### Task 4: CLI Artifact IO And Integration

**Files:**
- Modify: `packages/zigeffect/tools/causal_registry_application_readiness.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] Add executable build step:

```zig
const causal_registry_application_readiness_tool = b.addExecutable(.{
    .name = "zigeffect-causal-registry-application-readiness",
    .root_module = causal_registry_application_readiness_tool_module,
});
const run_causal_registry_application_readiness_tool = b.addRunArtifact(causal_registry_application_readiness_tool);
if (b.args) |args| run_causal_registry_application_readiness_tool.addArgs(args);
const causal_registry_application_readiness_step = b.step("causal-registry-application-readiness", "Write a policy-controlled causal registry application readiness report");
causal_registry_application_readiness_step.dependOn(&run_causal_registry_application_readiness_tool.step);
```

- [ ] Add the executable and test run to the `examples` aggregate.
- [ ] Implement `readRequiredArtifact`, `writeArtifact`, `runFromRegistryPatch`,
  and `main`.
- [ ] Run blocked default integration:

```sh
cd packages/zigeffect
zig build causal-dev-session -- start
zig build causal-dev-session -- assess
zig build causal-remediation-decision -- local approve --reason "Registry readiness integration check"
zig build causal-patch-proposal -- local approved --summary "Registry readiness integration proposal" --file packages/zigeffect/tools/causal_registry_application_readiness.zig --change "Gate registry patch application readiness"
zig build causal-audit-chain -- local
zig build causal-scenario-proposal -- local
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json
zig build causal-registry-application-readiness -- --from-registry-patch .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json approve --reason "reviewed registry patch draft" --verified-command "zig build causal-run learned-dogfood-service-resolution" --verified-command "zig build examples" --verified-command "zig build test --summary none"
```

Expected: text report includes `readiness_status: blocked` and a failed
`scenario-present` check because the generated scenario has not been manually
added to `tools/causal_run.zig`.

- [ ] Run no-op integration:

```sh
cd packages/zigeffect
zig build causal-dev-session -- start causal-scoped-fiber
zig build causal-dev-session -- assess causal-scoped-fiber
zig build causal-remediation-decision -- local approve causal-scoped-fiber --reason "Registry readiness no-op check"
zig build causal-patch-proposal -- local approved causal-scoped-fiber --summary "Registry readiness no-op scenario" --file packages/zigeffect/examples/causal_scoped_fiber.zig --change "Keep clear scenario as no-op"
zig build causal-audit-chain -- local causal-scoped-fiber
zig build causal-scenario-proposal -- local causal-scoped-fiber
zig build causal-scenario-registry-patch -- --from-proposal .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json
zig build causal-registry-application-readiness -- --from-registry-patch .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json approve --reason "no registry patch applies"
```

Expected: text report includes `readiness_status: not-applicable`.

- [ ] Commit:

```sh
git add packages/zigeffect/tools/causal_registry_application_readiness.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): write causal registry readiness artifacts"
```

### Task 5: Manifest, Docs, Roadmaps, And Verification

**Files:**
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify:
  `docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md`

- [ ] Add default readiness artifact paths:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.txt
```

- [ ] Add scenario readiness artifact paths:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-application-readiness.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-registry-application-readiness.txt
```

- [ ] Document:

```sh
zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> approve --reason <reason> [--verified-command <command>]...
zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> reject --reason <reason>
```

- [ ] Mark the policy-controlled readiness slice delivered in the roadmaps.
- [ ] Verify:

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
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md docs/superpowers/specs/2026-06-07-zigeffect-self-improving-dev-harness-roadmap.md packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/causal-scenarios.md packages/zigeffect/docs/roadmap.md packages/zigeffect/tools/causal_artifacts.zig
git commit -m "docs(zigeffect): document causal registry readiness gate"
```

## Self-Review

- Spec coverage: tasks cover command shape, schema, status handling, registry
  checks, docs checks, verification command recording, output artifacts, CLI IO,
  build wiring, manifest entries, docs, and final verification.
- Scope check: automatic source editing, arbitrary command execution, durable
  history, and app-facing adapters are out of scope. The tool emits readiness
  evidence only.
- TDD check: Tasks 1, 2, and 3 require red tests before helper, validation, and
  formatter implementation; Task 4 performs integration after tested behavior
  exists.
- Type consistency: command name is `causal-registry-application-readiness`;
  schema is `zigeffect.causal.registry-application-readiness.v1`; artifact
  suffix is `registry-application-readiness`.
