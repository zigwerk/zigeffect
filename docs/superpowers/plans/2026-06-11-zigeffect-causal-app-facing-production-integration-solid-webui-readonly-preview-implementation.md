# Zigeffect Causal App-Facing Production Integration SolidJS Read-Only Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the app-facing SolidJS read-only preview artifact and workbench view that consume ready audit/remediation bridge evidence without adding mutation, write, CI, deployment, or live-dashboard authority.

**Architecture:** The milestone has two surfaces. A Zig causal producer consumes a ready `audit-remediation-bridge.v1` artifact and emits a new `solid-webui-readonly-preview.v1` artifact with explicit authority denial fields, required panels, required sections, verification commands, blocked claims, and the next branch recommendation. The existing SolidJS workbench then derives a typed app-facing preview model from either the new preview artifact or the source bridge artifact and renders a read-only `app-preview` tab inside the local `webui-dev/zig-webui` bridge scope.

**Tech Stack:** Zig build tools, `std.json`, existing zigeffect causal artifact conventions, SolidJS, Bun test/typecheck, existing zigeffect workbench/WebUI bridge.

---

## Current Branch And Merge State

- Active branch: `codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview`
- Local `master` merge result on 2026-06-11: `Already up to date.`
- No Git remote is configured in this checkout, so this plan assumes local `master` is the available master source.
- Prior committed design: `docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview-design.md`
- Prior committed source bridge tool: `packages/zigeffect/tools/causal_app_facing_production_integration_audit_remediation_bridge.zig`
- Prior emitted source bridge artifact path:
  `../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-audit-remediation-bridge.json`

## File Structure

- Create `packages/zigeffect/tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig`
  - Owns CLI parsing, source bridge validation, preview evaluation, JSON/text formatting, and unit tests for this milestone.
- Modify `packages/zigeffect/build.zig`
  - Adds `causal-app-facing-production-integration-solid-webui-readonly-preview` executable and test step.
- Modify `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Adds typed app-facing preview model derivation for both preview artifacts and source bridge artifacts.
- Modify `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Adds model derivation tests for ready preview artifacts, ready source bridge artifacts, and blocked authority drift.
- Modify `packages/zigeffect/workbench/src/App.tsx`
  - Adds `app-preview` tab, app-facing preview helpers, and read-only SolidJS panels.
- Modify `packages/zigeffect/workbench/src/App.test.tsx`
  - Adds tab visibility and helper-row tests.
- Modify `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
  - Adds local sample loading coverage for the preview sample.
- Create `packages/zigeffect/workbench/public/sample-app-facing-solid-webui-readonly-preview.json`
  - Stores a ready sample artifact used by the WebUI bridge tests and manual inspection.
- Create `packages/zigeffect/docs/app-facing-production-integration-solid-webui-readonly-preview.md`
  - Documents artifact purpose, CLI usage, authority boundaries, workbench behavior, and next branch.
- Modify `packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md`
  - Links the source bridge to this new preview consumer.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers the new schema and increments the total schema count from 89 to 90.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Marks this branch as delivered and advances the recommendation to the CI advisory remediation report branch.
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks branch 54 delivered and adds branch 55 for `ci-advisory-remediation-report`.

## Milestone Constants

Use these exact constants in the Zig producer and docs:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1";
pub const source_schema = "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1";
pub const tool_name = "causal-app-facing-production-integration-solid-webui-readonly-preview";
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report";
pub const output_suffix = "-solid-webui-readonly-preview";
```

Required preview panels:

```zig
const required_preview_panels = [_][]const u8{
    "status",
    "source-artifacts",
    "authority-boundary",
    "audit-remediation-bridge-records",
    "runtime-remediation-evidence",
    "agent-query-next-queries",
    "solid-webui-preview-state",
    "ci-advisory-state",
    "verification",
    "blocked-claims",
    "non-goals",
    "next-branch",
};
```

Required preview sections:

```zig
const required_preview_sections = [_][]const u8{
    "audit-chain-comparison",
    "remediation-review",
    "runtime-evidence",
    "agent-query-evidence",
    "solid-webui-preview",
    "ci-advisory",
};
```

Required source bridge record ids:

```zig
const required_bridge_record_ids = [_][]const u8{
    "audit-chain-comparison-readiness",
    "remediation-review-readiness",
    "runtime-remediation-evidence",
    "agent-query-next-query-evidence",
    "solid-webui-readonly-preview-handoff",
    "ci-advisory-artifact-preview-handoff",
};
```

Required verification commands:

```text
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
zig build causal-app-facing-production-integration-audit-remediation-bridge
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

## Task 1: Confirm Merge And Source Artifact Readiness

**Files:**
- Read: `packages/zigeffect/tools/causal_app_facing_production_integration_audit_remediation_bridge.zig`
- Read: `packages/zigeffect/build.zig`
- Read: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Read: `packages/zigeffect/workbench/src/App.tsx`
- Read: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`

- [ ] **Step 1: Confirm branch is up to date with local master**

Run:

```sh
git status --short --branch
git merge master
```

Expected:

```text
## codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview
Already up to date.
```

- [ ] **Step 2: Verify source bridge artifact can be generated**

Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-audit-remediation-bridge
```

Expected:

```text
```

The command should exit 0 and write a JSON artifact ending with `-audit-remediation-bridge.json` under `../../.zig-cache/causal-artifacts/`.

- [ ] **Step 3: Inspect source bridge shape**

Run:

```sh
cd packages/zigeffect
rg -n "\"schema\"|\"status\"|\"bridge_records\"|\"solid_webui_preview_enabled\"|\"mutation_authority\"|\"verified_commands\"" ../../.zig-cache/causal-artifacts/*audit-remediation-bridge.json
```

Expected: output includes the source schema, `ready`, `bridge_records`, `solid_webui_preview_enabled`, `mutation_authority`, and `verified_commands`.

## Task 2: Zig Producer Red Test Scaffold

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig`

- [ ] **Step 1: Add the initial failing Zig test file**

Add this file content:

```zig
const std = @import("std");

pub const schema = "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1";
pub const source_schema = "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1";
pub const tool_name = "causal-app-facing-production-integration-solid-webui-readonly-preview";
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report";
pub const output_suffix = "-solid-webui-readonly-preview";

const ExpectedRedFailure = error{ExpectedRedFailure};

test "solid webui preview constants define the milestone boundary" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1", schema);
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1", source_schema);
    try std.testing.expectEqualStrings("causal-app-facing-production-integration-solid-webui-readonly-preview", tool_name);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-ci-advisory-remediation-report", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report", next_branch_if_ready);
    try std.testing.expectEqualStrings("-solid-webui-readonly-preview", output_suffix);
}

test "red test proves the preview evaluator still needs implementation" {
    return ExpectedRedFailure.ExpectedRedFailure;
}
```

- [ ] **Step 2: Run the scaffold test and verify it fails for the intended reason**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig
```

Expected: one test passes and one test fails with `ExpectedRedFailure`.

- [ ] **Step 3: Commit the red scaffold if preserving the TDD checkpoint is useful**

Run:

```sh
git add packages/zigeffect/tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig
git commit -m "test(zigeffect): scaffold app-facing solid webui preview producer"
```

Expected: commit succeeds. If the final milestone is kept as a single implementation commit, skip this commit and preserve the failing step in the working tree only until Task 5.

## Task 3: Zig Parser And Output Path Tests

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig`

- [ ] **Step 1: Replace the red-only test with option parser tests**

Add these types and tests near the top of the Zig file:

```zig
const Decision = enum { approve, reject };

const Options = struct {
    from_bridge: []const u8,
    decision: Decision,
    reason: []const u8,
    out_prefix: ?[]const u8 = null,
    format: []const u8 = "json",
    verified_commands: []const []const u8,
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    _ = allocator;
    _ = args;
    return error.NotImplemented;
}

test "parseOptions accepts approve command with bridge path and verification commands" {
    const args = [_][]const u8{
        "causal-app-facing-production-integration-solid-webui-readonly-preview",
        "--from-bridge",
        "../../.zig-cache/causal-artifacts/source-audit-remediation-bridge.json",
        "approve",
        "--reason",
        "ready app-facing audit remediation bridge reviewed for SolidJS read-only preview",
        "--verified-command",
        "bun run zigeffect:workbench:typecheck",
        "--verified-command",
        "zig build test",
    };

    const options = try parseOptions(std.testing.allocator, &args);
    defer std.testing.allocator.free(options.verified_commands);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/source-audit-remediation-bridge.json", options.from_bridge);
    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings("ready app-facing audit remediation bridge reviewed for SolidJS read-only preview", options.reason);
    try std.testing.expectEqual(@as(usize, 2), options.verified_commands.len);
    try std.testing.expectEqualStrings("bun run zigeffect:workbench:typecheck", options.verified_commands[0]);
    try std.testing.expectEqualStrings("zig build test", options.verified_commands[1]);
}

test "parseOptions rejects non-json bridge inputs" {
    const args = [_][]const u8{
        "causal-app-facing-production-integration-solid-webui-readonly-preview",
        "--from-bridge",
        "source.txt",
        "approve",
        "--reason",
        "ready",
    };

    try std.testing.expectError(error.InvalidBridgePath, parseOptions(std.testing.allocator, &args));
}
```

- [ ] **Step 2: Add output path tests**

Add:

```zig
const OutputPaths = struct {
    json: []const u8,
    text: []const u8,
};

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    _ = allocator;
    _ = options;
    return error.NotImplemented;
}

test "outputPathsForOptions derives solid webui readonly preview suffix from source bridge path" {
    const commands = [_][]const u8{"zig build test"};
    const options = Options{
        .from_bridge = "../../.zig-cache/causal-artifacts/source-audit-remediation-bridge.json",
        .decision = .approve,
        .reason = "ready",
        .verified_commands = &commands,
    };

    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer std.testing.allocator.free(paths.json);
    defer std.testing.allocator.free(paths.text);

    try std.testing.expect(std.mem.endsWith(u8, paths.json, "-solid-webui-readonly-preview.json"));
    try std.testing.expect(std.mem.endsWith(u8, paths.text, "-solid-webui-readonly-preview.txt"));
}
```

- [ ] **Step 3: Run parser/path tests and confirm they fail on missing implementation**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig
```

Expected: failures come from `error.NotImplemented` and `error.InvalidBridgePath` once the error set is introduced.

## Task 4: Zig Evaluator Tests

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig`

- [ ] **Step 1: Add compact source bridge fixtures**

Add fixture helpers:

```zig
const good_bridge_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
    \\  "status": "ready",
    \\  "decision": "approve",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "audit_remediation_bridge_mode": true,
    \\  "mutation_proof_claim_enabled": false,
    \\  "auto_apply_enabled": false,
    \\  "production_health_claim_enabled": false,
    \\  "solid_webui_preview_enabled": false,
    \\  "app_runtime_integration_enabled": false,
    \\  "agent_query_live_projection_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "nendb_adapter_execution_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "deployment_mutation_enabled": false,
    \\  "app_config_write_enabled": false,
    \\  "app_data_write_enabled": false,
    \\  "checks": [
    \\    {"name":"bridge-schema","status":"pass","detail":"source bridge schema"},
    \\    {"name":"authority-boundary","status":"pass","detail":"no mutation authority"}
    \\  ],
    \\  "validation_checks": [
    \\    "source-bridge-ready",
    \\    "source-authority-disabled",
    \\    "solid-webui-readonly-preview-next-only"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-app-facing-production-integration-audit-remediation-bridge",
    \\    "zig build test"
    \\  ],
    \\  "bridge_records": [
    \\    {"id":"audit-chain-comparison-readiness","status":"ready","source_ref":"audit-chain-ref","target_ref":"comparison-ref"},
    \\    {"id":"remediation-review-readiness","status":"ready","source_ref":"review-ref","target_ref":"review-target"},
    \\    {"id":"runtime-remediation-evidence","status":"ready","source_ref":"runtime-ref","target_ref":"runtime-target"},
    \\    {"id":"agent-query-next-query-evidence","status":"ready","source_ref":"agent-query-ref","target_ref":"next-query-target"},
    \\    {"id":"solid-webui-readonly-preview-handoff","status":"ready","source_ref":"solid-webui-ref","target_ref":"solid-view-target"},
    \\    {"id":"ci-advisory-artifact-preview-handoff","status":"ready","source_ref":"ci-ref","target_ref":"ci-target"}
    \\  ],
    \\  "recommendation": "start-app-facing-production-integration-solid-webui-readonly-preview",
    \\  "next_branch_if_ready": "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview"
    \\}
;

const bridge_with_app_data_write =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
    \\  "status": "ready",
    \\  "decision": "approve",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "audit_remediation_bridge_mode": true,
    \\  "app_data_write_enabled": true,
    \\  "bridge_records": [],
    \\  "checks": [],
    \\  "validation_checks": [],
    \\  "verified_commands": []
    \\}
;

const bridge_with_solid_preview_enabled =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
    \\  "status": "ready",
    \\  "decision": "approve",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "audit_remediation_bridge_mode": true,
    \\  "solid_webui_preview_enabled": true,
    \\  "bridge_records": [],
    \\  "checks": [],
    \\  "validation_checks": [],
    \\  "verified_commands": []
    \\}
;
```

- [ ] **Step 2: Add evaluator result types and ready report test**

Add:

```zig
const PreviewResult = struct {
    status: []const u8,
    decision: []const u8,
    applied: bool,
    mutation_authority: []const u8,
    read_only_preview: bool,
    solid_webui_enabled: bool,
    solid_webui_renderer: []const u8,
    webui_bridge: []const u8,
    hosted_live_dashboard_enabled: bool,
    app_mutation_controls_enabled: bool,
    react_renderer_enabled: bool,
    alternate_renderer_enabled: bool,
    nendb_write_enabled: bool,
    nendb_adapter_execution_enabled: bool,
    durable_write_enabled: bool,
    deployment_mutation_enabled: bool,
    checks: []const PreviewCheck,
    preview_panels: []const []const u8,
    app_preview_sections: []const PreviewSection,
    verified_commands: []const []const u8,
};

const PreviewCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8,
};

const PreviewSection = struct {
    id: []const u8,
    title: []const u8,
    evidence_refs: []const []const u8,
    blocked_authority: []const []const u8,
};

fn evaluatePreview(allocator: std.mem.Allocator, bridge_json: []const u8, options: Options) !PreviewResult {
    _ = allocator;
    _ = bridge_json;
    _ = options;
    return error.NotImplemented;
}

test "evaluatePreview emits ready SolidJS read-only preview authority from approved bridge" {
    const commands = [_][]const u8{
        "bun run zigeffect:workbench:typecheck",
        "bun run zigeffect:workbench:test",
        "zig build causal-app-facing-production-integration-audit-remediation-bridge",
        "zig build causal-schema-governance -- --format json",
        "zig build causal-production-hardening-backlog -- --format json",
        "zig build examples",
        "zig build test",
    };
    const options = Options{
        .from_bridge = "source-audit-remediation-bridge.json",
        .decision = .approve,
        .reason = "ready app-facing audit remediation bridge reviewed for SolidJS read-only preview",
        .verified_commands = &commands,
    };

    const result = try evaluatePreview(std.testing.allocator, good_bridge_json, options);
    defer freePreviewResult(std.testing.allocator, result);

    try std.testing.expectEqualStrings("ready", result.status);
    try std.testing.expectEqualStrings("approve", result.decision);
    try std.testing.expect(!result.applied);
    try std.testing.expectEqualStrings("none", result.mutation_authority);
    try std.testing.expect(result.read_only_preview);
    try std.testing.expect(result.solid_webui_enabled);
    try std.testing.expectEqualStrings("solidjs", result.solid_webui_renderer);
    try std.testing.expectEqualStrings("webui-dev/zig-webui", result.webui_bridge);
    try std.testing.expect(!result.hosted_live_dashboard_enabled);
    try std.testing.expect(!result.app_mutation_controls_enabled);
    try std.testing.expect(!result.react_renderer_enabled);
    try std.testing.expect(!result.alternate_renderer_enabled);
    try std.testing.expect(!result.nendb_write_enabled);
    try std.testing.expect(!result.nendb_adapter_execution_enabled);
    try std.testing.expect(!result.durable_write_enabled);
    try std.testing.expect(!result.deployment_mutation_enabled);
    try std.testing.expect(hasPanel(result.preview_panels, "solid-webui-preview-state"));
    try std.testing.expect(hasSection(result.app_preview_sections, "solid-webui-preview"));
    try std.testing.expect(hasCheck(result.checks, "solid-webui-readonly", "pass"));
}
```

- [ ] **Step 3: Add rejection and drift tests**

Add tests:

```zig
test "evaluatePreview rejects command decision without claiming preview readiness" {
    const commands = [_][]const u8{"zig build test"};
    const options = Options{
        .from_bridge = "source-audit-remediation-bridge.json",
        .decision = .reject,
        .reason = "review rejected preview handoff",
        .verified_commands = &commands,
    };

    const result = try evaluatePreview(std.testing.allocator, good_bridge_json, options);
    defer freePreviewResult(std.testing.allocator, result);

    try std.testing.expectEqualStrings("blocked", result.status);
    try std.testing.expectEqualStrings("reject", result.decision);
    try std.testing.expect(hasCheck(result.checks, "decision-approved", "fail"));
}

test "evaluatePreview blocks if source bridge already enables app data writes" {
    const commands = [_][]const u8{"zig build test"};
    const options = Options{ .from_bridge = "source.json", .decision = .approve, .reason = "ready", .verified_commands = &commands };

    const result = try evaluatePreview(std.testing.allocator, bridge_with_app_data_write, options);
    defer freePreviewResult(std.testing.allocator, result);

    try std.testing.expectEqualStrings("blocked", result.status);
    try std.testing.expect(hasCheck(result.checks, "authority-boundary", "fail"));
}

test "evaluatePreview blocks if source bridge already enables SolidJS preview" {
    const commands = [_][]const u8{"zig build test"};
    const options = Options{ .from_bridge = "source.json", .decision = .approve, .reason = "ready", .verified_commands = &commands };

    const result = try evaluatePreview(std.testing.allocator, bridge_with_solid_preview_enabled, options);
    defer freePreviewResult(std.testing.allocator, result);

    try std.testing.expectEqualStrings("blocked", result.status);
    try std.testing.expect(hasCheck(result.checks, "source-authority-disabled", "fail"));
}
```

- [ ] **Step 4: Run evaluator tests and confirm they fail on missing implementation**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig
```

Expected: failures come from `error.NotImplemented` and missing helper implementations.

## Task 5: Zig Producer Implementation

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig`

- [ ] **Step 1: Implement parser errors and CLI option parsing**

Implement these errors and parser behavior:

```zig
const CliError = error{
    MissingFromBridge,
    MissingDecision,
    MissingReason,
    InvalidDecision,
    InvalidBridgePath,
    MissingVerifiedCommand,
    UnsupportedFormat,
};
```

Rules:

- `--from-bridge <path>` is required.
- `<path>` must end with `.json`.
- decision is required and must be `approve` or `reject`.
- `--reason <text>` is required and must not be empty.
- `--verified-command <command>` may repeat.
- `--out-prefix <path>` overrides derived output paths.
- `--format json` and `--format text` are accepted.
- unknown flags return `error.InvalidArgument`.

Use `std.ArrayList([]const u8)` for verified command accumulation and return an owned slice.

- [ ] **Step 2: Implement output path derivation**

Rules:

- If `options.out_prefix` is present, output JSON is `<out_prefix>.json` and text is `<out_prefix>.txt`.
- Otherwise strip the trailing `.json` from `options.from_bridge`.
- Strip one trailing `-audit-remediation-bridge` from the stem when present.
- Append `-solid-webui-readonly-preview.json` and `-solid-webui-readonly-preview.txt`.

- [ ] **Step 3: Implement JSON readers**

Use the same `std.json.parseFromSlice` pattern used by the nearby source bridge tools. Read fields defensively:

```zig
fn stringField(object: std.json.ObjectMap, key: []const u8, default: []const u8) []const u8
fn boolField(object: std.json.ObjectMap, key: []const u8, default: bool) bool
fn stringArrayField(allocator: std.mem.Allocator, object: std.json.ObjectMap, key: []const u8) ![]const []const u8
fn checksPassed(object: std.json.ObjectMap) bool
fn verifiedCommandsRecorded(object: std.json.ObjectMap) bool
fn bridgeRecordIdsPresent(object: std.json.ObjectMap) bool
```

Required source assertions:

- `schema == source_schema`
- `status == "ready"`
- `decision == "approve"`
- `applied == false`
- `mutation_authority == "none"`
- `audit_remediation_bridge_mode == true`
- `mutation_proof_claim_enabled == false`
- `auto_apply_enabled == false`
- `production_health_claim_enabled == false`
- `solid_webui_preview_enabled == false`
- `app_runtime_integration_enabled == false`
- `agent_query_live_projection_enabled == false`
- `nendb_write_enabled == false`
- `nendb_adapter_execution_enabled == false`
- `durable_write_enabled == false`
- `deployment_mutation_enabled == false`
- `app_config_write_enabled == false`
- `app_data_write_enabled == false`
- every source check has status `pass`
- source `verified_commands` length is greater than 0
- all six required bridge records are present

- [ ] **Step 4: Implement preview checks**

Emit check names exactly:

```text
bridge-schema
bridge-status
bridge-decision-approved
preview-decision
decision-approved
authority-boundary
source-chain-linked
bridge-checks-passed
bridge-verification-recorded
bridge-catalog-present
preview-panels-present
preview-sections-present
solid-webui-readonly
solid-renderer
webui-bridge-scope
app-mutation-controls-disabled
hosted-live-dashboard-disabled
react-renderer-disabled
alternate-renderer-disabled
preview-verification-recorded
nendb-write-disabled
nendb-adapter-execution-disabled
durable-write-disabled
deployment-mutation-disabled
auto-apply-disabled
mutation-proof-disabled
production-health-claim-disabled
nendb-only-scope
```

Status is `ready` only when all checks pass and `options.decision == .approve`. Otherwise status is `blocked`.

- [ ] **Step 5: Implement output formatting**

JSON output must include these top-level fields:

```json
{
  "schema": "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1",
  "source_schema": "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
  "tool": "causal-app-facing-production-integration-solid-webui-readonly-preview",
  "source_branch": "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview",
  "status": "ready",
  "decision": "approve",
  "reason": "ready app-facing audit remediation bridge reviewed for SolidJS read-only preview",
  "applied": false,
  "mutation_authority": "none",
  "read_only_preview": true,
  "solid_webui_enabled": true,
  "solid_webui_renderer": "solidjs",
  "webui_bridge": "webui-dev/zig-webui",
  "hosted_live_dashboard_enabled": false,
  "app_mutation_controls_enabled": false,
  "production_telemetry_ingestion": false,
  "live_exporter_enabled": false,
  "network_send_enabled": false,
  "collector_endpoint_configured": false,
  "otlp_serialization_enabled": false,
  "durable_write_enabled": false,
  "app_mutation_enabled": false,
  "ci_gate_enabled": false,
  "raw_payload_capture_enabled": false,
  "app_config_write_enabled": false,
  "app_data_write_enabled": false,
  "deployment_mutation_enabled": false,
  "nendb_write_enabled": false,
  "nendb_adapter_execution_enabled": false,
  "app_runtime_integration_enabled": false,
  "agent_query_live_projection_enabled": false,
  "mutation_proof_claim_enabled": false,
  "auto_apply_enabled": false,
  "production_health_claim_enabled": false,
  "react_renderer_enabled": false,
  "alternate_renderer_enabled": false,
  "preview_panels": [],
  "app_preview_sections": [],
  "bridge_records": [],
  "checks": [],
  "validation_checks": [],
  "blocked_claims": [],
  "non_goals": [],
  "required_verification_commands": [],
  "verified_commands": [],
  "recommendation": "start-app-facing-production-integration-ci-advisory-remediation-report",
  "next_branch_if_ready": "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report"
}
```

Fill arrays with the concrete values from this plan and source bridge records. Text output must include at least:

```text
status: ready
decision: approve
read only preview: true
solid webui enabled: true
solid webui renderer: solidjs
webui bridge: webui-dev/zig-webui
app mutation controls enabled: false
hosted live dashboard enabled: false
react renderer enabled: false
alternate renderer enabled: false
nendb adapter execution enabled: false
recommendation: start-app-facing-production-integration-ci-advisory-remediation-report
next branch: codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report
```

- [ ] **Step 6: Implement `run` and `main`**

Behavior:

- Read the bridge JSON from `options.from_bridge`.
- Evaluate preview.
- Create output parent directory as needed.
- Write JSON and text artifacts.
- Print the selected output path for the selected format.
- Return nonzero only for IO/parser errors, not for a review `reject` decision.

- [ ] **Step 7: Run the Zig producer tests**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig
```

Expected: all tests in the new producer pass.

## Task 6: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Inspect adjacent causal build step patterns**

Run:

```sh
cd packages/zigeffect
rg -n "causal-app-facing-production-integration-audit-remediation-bridge|causal-production-telemetry-workbench-readonly-preview|addExecutable|addRunArtifact" build.zig
```

Expected: output shows the existing executable/test-step pattern.

- [ ] **Step 2: Add the executable and build step**

Add a step named:

```text
causal-app-facing-production-integration-solid-webui-readonly-preview
```

Its root source file must be:

```text
tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig
```

Mirror the source bridge and production telemetry preview build-step wiring, including the test step if this build file maintains one causal tool test per executable.

- [ ] **Step 3: Verify the build step is discoverable**

Run:

```sh
cd packages/zigeffect
zig build --help | rg "causal-app-facing-production-integration-solid-webui-readonly-preview"
```

Expected: the new step name appears.

- [ ] **Step 4: Generate approved and rejected artifacts**

Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-solid-webui-readonly-preview -- \
  --from-bridge ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-audit-remediation-bridge.json \
  approve \
  --reason "ready app-facing audit remediation bridge reviewed for SolidJS read-only preview" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-audit-remediation-bridge" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"

zig build causal-app-facing-production-integration-solid-webui-readonly-preview -- \
  --from-bridge ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-audit-remediation-bridge.json \
  reject \
  --reason "negative fixture keeps preview blocked after reviewer rejection" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-solid-webui-readonly-preview-negative \
  --verified-command "zig build test"
```

Expected:

- approved JSON path ends in `-solid-webui-readonly-preview.json`
- rejected JSON path is `../../.zig-cache/causal-artifacts/app-facing-production-integration-solid-webui-readonly-preview-negative.json`
- approved status is `ready`
- rejected status is `blocked`

## Task 7: Workbench Model TDD

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`

- [ ] **Step 1: Add model imports**

Modify the test imports:

```ts
import {
  deriveAppFacingPreviewModel,
  deriveProductionTelemetryPreviewModel,
  parseArtifactJson,
} from "./causalArtifact";
```

If the current import shape differs, add only `deriveAppFacingPreviewModel` to the existing import block.

- [ ] **Step 2: Add sample preview object in `causalArtifact.test.ts`**

Add:

```ts
const sampleAppFacingSolidWebuiPreview = {
  schema: "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1",
  source_schema: "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
  tool: "causal-app-facing-production-integration-solid-webui-readonly-preview",
  status: "ready",
  decision: "approve",
  reason: "ready app-facing audit remediation bridge reviewed for SolidJS read-only preview",
  applied: false,
  mutation_authority: "none",
  read_only_preview: true,
  solid_webui_enabled: true,
  solid_webui_renderer: "solidjs",
  webui_bridge: "webui-dev/zig-webui",
  hosted_live_dashboard_enabled: false,
  app_mutation_controls_enabled: false,
  react_renderer_enabled: false,
  alternate_renderer_enabled: false,
  nendb_write_enabled: false,
  nendb_adapter_execution_enabled: false,
  durable_write_enabled: false,
  deployment_mutation_enabled: false,
  app_runtime_integration_enabled: false,
  agent_query_live_projection_enabled: false,
  preview_panels: ["status", "source-artifacts", "authority-boundary", "solid-webui-preview-state", "verification"],
  app_preview_sections: [
    {
      id: "solid-webui-preview",
      title: "SolidJS WebUI preview",
      evidence_refs: ["solid-view-target"],
      blocked_authority: ["app_mutation_controls", "hosted_live_dashboard", "react_renderer", "alternate_renderer"],
    },
  ],
  bridge_records: [
    {
      id: "solid-webui-readonly-preview-handoff",
      status: "ready",
      source_ref: "solid-webui-ref",
      target_ref: "solid-view-target",
    },
  ],
  checks: [
    { name: "solid-webui-readonly", status: "pass", detail: "preview is read-only SolidJS inside webui-dev/zig-webui" },
    { name: "react-renderer-disabled", status: "pass", detail: "React renderer is not enabled for this branch" },
  ],
  validation_checks: ["solid-webui-readonly", "solidjs-renderer-only", "cockroach-scope-rejected"],
  blocked_claims: ["applied=true", "production-health", "mutation-proof", "cockroach-adapter"],
  non_goals: ["hosted live dashboard", "app mutation controls", "NenDB production writes"],
  required_verification_commands: ["bun run zigeffect:workbench:typecheck", "bun run zigeffect:workbench:test"],
  verified_commands: ["bun run zigeffect:workbench:typecheck", "bun run zigeffect:workbench:test"],
  recommendation: "start-app-facing-production-integration-ci-advisory-remediation-report",
  next_branch_if_ready: "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report",
};
```

- [ ] **Step 3: Add derivation tests**

Add tests:

```ts
test("deriveAppFacingPreviewModel reads ready SolidJS WebUI preview artifacts", () => {
  const preview = deriveAppFacingPreviewModel(sampleAppFacingSolidWebuiPreview, {
    artifactPath: "/tmp/app-preview.json",
  });

  expect(preview?.schema).toBe("zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1");
  expect(preview?.status).toBe("ready");
  expect(preview?.decision).toBe("approve");
  expect(preview?.authority.readOnlyPreview).toBe(true);
  expect(preview?.authority.solidWebuiEnabled).toBe(true);
  expect(preview?.authority.solidWebuiRenderer).toBe("solidjs");
  expect(preview?.authority.webuiBridge).toBe("webui-dev/zig-webui");
  expect(preview?.authority.appMutationControlsEnabled).toBe(false);
  expect(preview?.authority.hostedLiveDashboardEnabled).toBe(false);
  expect(preview?.authority.reactRendererEnabled).toBe(false);
  expect(preview?.authority.alternateRendererEnabled).toBe(false);
  expect(preview?.bridgeRecords.map((record) => record.id)).toContain("solid-webui-readonly-preview-handoff");
  expect(preview?.sections.map((section) => section.id)).toContain("solid-webui-preview");
  expect(preview?.blockedClaims).toContain("applied=true");
});

test("deriveAppFacingPreviewModel adapts ready audit remediation bridge artifacts into source preview mode", () => {
  const sourceBridge = {
    schema: "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1",
    status: "ready",
    decision: "approve",
    applied: false,
    mutation_authority: "none",
    solid_webui_preview_enabled: false,
    bridge_records: sampleAppFacingSolidWebuiPreview.bridge_records,
    checks: [{ name: "authority-boundary", status: "pass", detail: "no mutation authority" }],
    validation_checks: ["solid-webui-readonly-preview-next-only"],
    verified_commands: ["zig build causal-app-facing-production-integration-audit-remediation-bridge"],
    recommendation: "start-app-facing-production-integration-solid-webui-readonly-preview",
    next_branch_if_ready: "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview",
  };

  const preview = deriveAppFacingPreviewModel(sourceBridge, { artifactPath: "/tmp/source-bridge.json" });

  expect(preview?.sourceMode).toBe("audit-remediation-bridge");
  expect(preview?.status).toBe("ready");
  expect(preview?.authority.readOnlyPreview).toBe(false);
  expect(preview?.authority.solidWebuiEnabled).toBe(false);
  expect(preview?.authority.appMutationControlsEnabled).toBe(false);
  expect(preview?.nextBranch).toBe("codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview");
});

test("deriveAppFacingPreviewModel keeps authority drift visible instead of hiding blocked artifacts", () => {
  const preview = deriveAppFacingPreviewModel(
    {
      ...sampleAppFacingSolidWebuiPreview,
      status: "blocked",
      app_mutation_controls_enabled: true,
      checks: [{ name: "app-mutation-controls-disabled", status: "fail", detail: "mutation controls are enabled" }],
    },
    { artifactPath: "/tmp/app-preview-blocked.json" },
  );

  expect(preview?.status).toBe("blocked");
  expect(preview?.authority.appMutationControlsEnabled).toBe(true);
  expect(preview?.checks[0]).toMatchObject({ name: "app-mutation-controls-disabled", status: "fail" });
});
```

- [ ] **Step 4: Run tests and verify failure**

Run:

```sh
cd packages/zigeffect
bun test workbench/src/causalArtifact.test.ts
```

Expected: fails because `deriveAppFacingPreviewModel` is not exported.

- [ ] **Step 5: Add model types and derivation implementation**

Add exported types in `causalArtifact.ts` near the production telemetry preview types:

```ts
export type AppFacingPreviewAuthority = {
  applied: boolean;
  mutationAuthority: string;
  readOnlyPreview: boolean;
  solidWebuiEnabled: boolean;
  solidWebuiRenderer: string;
  webuiBridge: string;
  hostedLiveDashboardEnabled: boolean;
  appMutationControlsEnabled: boolean;
  reactRendererEnabled: boolean;
  alternateRendererEnabled: boolean;
  nendbWriteEnabled: boolean;
  nendbAdapterExecutionEnabled: boolean;
  durableWriteEnabled: boolean;
  deploymentMutationEnabled: boolean;
  appRuntimeIntegrationEnabled: boolean;
  agentQueryLiveProjectionEnabled: boolean;
};

export type AppFacingPreviewCheck = {
  name: string;
  status: string;
  detail: string;
};

export type AppFacingBridgeRecord = {
  id: string;
  status: string;
  sourceRef: string;
  targetRef: string;
};

export type AppFacingPreviewSection = {
  id: string;
  title: string;
  evidenceRefs: string[];
  blockedAuthority: string[];
};

export type AppFacingPreviewModel = {
  schema: string;
  sourceMode: "solid-webui-readonly-preview" | "audit-remediation-bridge";
  artifactPath: string;
  status: string;
  decision: string;
  reason: string;
  authority: AppFacingPreviewAuthority;
  previewPanels: string[];
  sections: AppFacingPreviewSection[];
  bridgeRecords: AppFacingBridgeRecord[];
  checks: AppFacingPreviewCheck[];
  validationChecks: string[];
  blockedClaims: string[];
  nonGoals: string[];
  requiredVerificationCommands: string[];
  verifiedCommands: string[];
  recommendation: string;
  nextBranch: string;
};
```

Add `deriveAppFacingPreviewModel(raw, options)`:

```ts
export function deriveAppFacingPreviewModel(raw: unknown, options: WorkbenchOptions): AppFacingPreviewModel | null {
  const value = objectRecord(raw);
  if (!value) return null;
  const schema = stringValue(value.schema);

  if (schema === "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1") {
    return {
      schema,
      sourceMode: "solid-webui-readonly-preview",
      artifactPath: options.artifactPath,
      status: stringValue(value.status),
      decision: stringValue(value.decision),
      reason: stringValue(value.reason),
      authority: appFacingAuthority(value, true),
      previewPanels: stringArray(value.preview_panels),
      sections: appFacingSections(value.app_preview_sections),
      bridgeRecords: appFacingBridgeRecords(value.bridge_records),
      checks: appFacingChecks(value.checks),
      validationChecks: stringArray(value.validation_checks),
      blockedClaims: stringArray(value.blocked_claims),
      nonGoals: stringArray(value.non_goals),
      requiredVerificationCommands: stringArray(value.required_verification_commands),
      verifiedCommands: stringArray(value.verified_commands),
      recommendation: stringValue(value.recommendation),
      nextBranch: stringValue(value.next_branch_if_ready),
    };
  }

  if (schema === "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1") {
    return {
      schema,
      sourceMode: "audit-remediation-bridge",
      artifactPath: options.artifactPath,
      status: stringValue(value.status),
      decision: stringValue(value.decision),
      reason: stringValue(value.reason),
      authority: appFacingAuthority(value, false),
      previewPanels: [],
      sections: [],
      bridgeRecords: appFacingBridgeRecords(value.bridge_records),
      checks: appFacingChecks(value.checks),
      validationChecks: stringArray(value.validation_checks),
      blockedClaims: stringArray(value.blocked_claims),
      nonGoals: stringArray(value.non_goals),
      requiredVerificationCommands: stringArray(value.required_verification_commands),
      verifiedCommands: stringArray(value.verified_commands),
      recommendation: stringValue(value.recommendation),
      nextBranch: stringValue(value.next_branch_if_ready),
    };
  }

  return null;
}
```

Implement helpers with the existing helper style in the file:

- `appFacingAuthority`
- `appFacingChecks`
- `appFacingBridgeRecords`
- `appFacingSections`
- use existing `objectRecord`, `stringValue`, `booleanValue`, and `stringArray` helpers if present; otherwise add narrow local helpers matching current style.

- [ ] **Step 6: Run model tests**

Run:

```sh
cd packages/zigeffect
bun test workbench/src/causalArtifact.test.ts
```

Expected: app-facing model tests pass and existing tests remain green.

## Task 8: Workbench UI TDD

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.test.tsx`
- Modify: `packages/zigeffect/workbench/src/App.tsx`

- [ ] **Step 1: Add tab visibility tests**

Update `workbenchTabsForArtifact` tests:

```ts
test("workbenchTabsForArtifact exposes app preview only for app-facing preview artifacts", () => {
  expect(workbenchTabsForArtifact(false).map((tab) => tab.id)).not.toContain("app-preview");
  expect(workbenchTabsForArtifact(false, false).map((tab) => tab.id)).not.toContain("app-preview");
  expect(workbenchTabsForArtifact(false, true).map((tab) => tab.id)).toContain("app-preview");
  expect(workbenchTabsForArtifact(true, true).map((tab) => tab.id)).toEqual(
    expect.arrayContaining(["telemetry", "app-preview"]),
  );
});
```

- [ ] **Step 2: Add helper-row tests**

Add imports and tests:

```ts
import {
  appFacingPreviewAuthorityRows,
  appFacingPreviewStatusMetrics,
  appFacingPreviewVerificationCommands,
  workbenchTabsForArtifact,
} from "./App";

test("appFacingPreviewAuthorityRows highlight SolidJS read-only boundaries", () => {
  const rows = appFacingPreviewAuthorityRows({
    applied: false,
    mutationAuthority: "none",
    readOnlyPreview: true,
    solidWebuiEnabled: true,
    solidWebuiRenderer: "solidjs",
    webuiBridge: "webui-dev/zig-webui",
    hostedLiveDashboardEnabled: false,
    appMutationControlsEnabled: false,
    reactRendererEnabled: false,
    alternateRendererEnabled: false,
    nendbWriteEnabled: false,
    nendbAdapterExecutionEnabled: false,
    durableWriteEnabled: false,
    deploymentMutationEnabled: false,
    appRuntimeIntegrationEnabled: false,
    agentQueryLiveProjectionEnabled: false,
  });

  expect(rows).toContainEqual({ label: "renderer", value: "solidjs", safe: true });
  expect(rows).toContainEqual({ label: "webui bridge", value: "webui-dev/zig-webui", safe: true });
  expect(rows).toContainEqual({ label: "app mutation controls", value: "false", safe: true });
  expect(rows).toContainEqual({ label: "hosted live dashboard", value: "false", safe: true });
  expect(rows).toContainEqual({ label: "react renderer", value: "false", safe: true });
  expect(rows).toContainEqual({ label: "alternate renderer", value: "false", safe: true });
});

test("appFacingPreviewVerificationCommands combine required and verified commands", () => {
  const commands = appFacingPreviewVerificationCommands({
    requiredVerificationCommands: ["bun run zigeffect:workbench:typecheck"],
    verifiedCommands: ["bun run zigeffect:workbench:test"],
  });

  expect(commands.map((command) => command.label)).toEqual(["required 1", "verified 1"]);
  expect(commands.map((command) => command.command)).toEqual([
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
  ]);
});
```

This matches the existing `QueryCommand` shape in `causalArtifact.ts`: `{ label: string; command: string }`.

- [ ] **Step 3: Run UI tests and verify failure**

Run:

```sh
cd packages/zigeffect
bun test workbench/src/App.test.tsx
```

Expected: fails because the app-facing helper exports and tab id do not exist.

- [ ] **Step 4: Add imports, tab, and parsed memo**

In `App.tsx`, import:

```ts
import {
  deriveAppFacingPreviewModel,
  type AppFacingPreviewAuthority,
  type AppFacingPreviewCheck,
  type AppFacingPreviewModel,
  type AppFacingPreviewSection,
  type AppFacingBridgeRecord,
} from "./causalArtifact";
```

Extend the tab id union:

```ts
type Tab = "timeline" | "findings" | "live" | "graph" | "visual-graph" | "chain" | "telemetry" | "app-preview" | "queries" | "metadata";
```

Add the tab:

```ts
const tabs: WorkbenchTab[] = [
  { id: "timeline", label: "Timeline" },
  { id: "findings", label: "Findings" },
  { id: "live", label: "Live" },
  { id: "graph", label: "Graph" },
  { id: "visual-graph", label: "Visual Graph" },
  { id: "chain", label: "Chain" },
  { id: "telemetry", label: "Telemetry" },
  { id: "app-preview", label: "App Preview" },
  { id: "queries", label: "Queries" },
  { id: "metadata", label: "Metadata" },
];
```

Change the helper signature:

```ts
export function workbenchTabsForArtifact(hasProductionTelemetry: boolean, hasAppFacingPreview = false): WorkbenchTab[] {
  return tabs.filter((tab) => {
    if (tab.id === "telemetry") return hasProductionTelemetry;
    if (tab.id === "app-preview") return hasAppFacingPreview;
    return true;
  });
}
```

In the parsed artifact memo, derive:

```ts
appFacingPreview: deriveAppFacingPreviewModel(raw, { artifactPath }),
```

Update tab calculation:

```ts
const workbenchTabs = createMemo(() =>
  workbenchTabsForArtifact(Boolean(productionTelemetry()), Boolean(appFacingPreview())),
);
```

- [ ] **Step 5: Add helper exports**

Add helper functions:

```ts
export function appFacingPreviewStatusMetrics(preview: AppFacingPreviewModel): TelemetryMetricRow[] {
  return [
    { label: "status", value: preview.status, tone: preview.status === "ready" ? "ok" : "warn" },
    { label: "decision", value: preview.decision, tone: preview.decision === "approve" ? "ok" : "warn" },
    { label: "mode", value: preview.sourceMode },
    { label: "bridge records", value: String(preview.bridgeRecords.length) },
    { label: "checks", value: String(preview.checks.length) },
    { label: "next", value: preview.nextBranch },
  ];
}

export function appFacingPreviewAuthorityRows(authority: AppFacingPreviewAuthority): TelemetryAuthorityRow[] {
  return [
    { label: "applied", value: String(authority.applied), safe: authority.applied === false },
    { label: "mutation authority", value: authority.mutationAuthority, safe: authority.mutationAuthority === "none" },
    { label: "read-only preview", value: String(authority.readOnlyPreview), safe: authority.readOnlyPreview === true },
    { label: "solid webui", value: String(authority.solidWebuiEnabled), safe: authority.solidWebuiEnabled === true },
    { label: "renderer", value: authority.solidWebuiRenderer, safe: authority.solidWebuiRenderer === "solidjs" },
    { label: "webui bridge", value: authority.webuiBridge, safe: authority.webuiBridge === "webui-dev/zig-webui" },
    { label: "app mutation controls", value: String(authority.appMutationControlsEnabled), safe: authority.appMutationControlsEnabled === false },
    { label: "hosted live dashboard", value: String(authority.hostedLiveDashboardEnabled), safe: authority.hostedLiveDashboardEnabled === false },
    { label: "react renderer", value: String(authority.reactRendererEnabled), safe: authority.reactRendererEnabled === false },
    { label: "alternate renderer", value: String(authority.alternateRendererEnabled), safe: authority.alternateRendererEnabled === false },
    { label: "nendb writes", value: String(authority.nendbWriteEnabled), safe: authority.nendbWriteEnabled === false },
    { label: "nendb adapter execution", value: String(authority.nendbAdapterExecutionEnabled), safe: authority.nendbAdapterExecutionEnabled === false },
    { label: "durable writes", value: String(authority.durableWriteEnabled), safe: authority.durableWriteEnabled === false },
    { label: "deployment mutation", value: String(authority.deploymentMutationEnabled), safe: authority.deploymentMutationEnabled === false },
  ];
}

export function appFacingPreviewVerificationCommands(preview: Pick<AppFacingPreviewModel, "requiredVerificationCommands" | "verifiedCommands">): QueryCommand[] {
  return [
    ...preview.requiredVerificationCommands.map((command, index) => ({ label: `required ${index + 1}`, command })),
    ...preview.verifiedCommands.map((command, index) => ({ label: `verified ${index + 1}`, command })),
  ];
}
```

- [ ] **Step 6: Add read-only view components**

Add components modeled on the production telemetry view:

```tsx
export function AppFacingPreviewView(props: {
  preview: AppFacingPreviewModel | null;
  copiedCommand: string | null;
  onCopy: (command: string) => void;
}) {
  const preview = () => props.preview;
  return (
    <Show
      when={preview()}
      fallback={<EmptyState label="Loaded artifact has no app-facing SolidJS preview" />}
    >
      {(model) => (
        <div class="view-stack">
          <section class="chain-panel">
            <h2>App preview</h2>
            <div class="chain-status telemetry-status">
              <For each={appFacingPreviewStatusMetrics(model())}>
                {(metric) => <Metric label={metric.label} value={metric.value} tone={metric.tone} />}
              </For>
            </div>
          </section>
          <section class="chain-panel">
            <div class="lane-section-head">
              <h3>Authority boundary</h3>
              <span>read-only</span>
            </div>
            <div class="telemetry-authority-grid">
              <For each={appFacingPreviewAuthorityRows(model().authority)}>
                {(flag) => <Metric label={flag.label} value={flag.value} tone={flag.safe ? "ok" : "warn"} />}
              </For>
            </div>
          </section>
          <AppFacingBridgeRecords records={model().bridgeRecords} />
          <AppFacingPreviewSections sections={model().sections} />
          <TelemetryChecks checks={model().checks} />
          <section class="chain-panel">
            <h3>Verification</h3>
            <CommandList commands={appFacingPreviewVerificationCommands(model())} copiedCommand={props.copiedCommand} onCopy={props.onCopy} compact />
          </section>
          <div class="telemetry-grid">
            <TelemetryStringPanel title="Blocked claims" values={model().blockedClaims} chip tone="blocked" />
            <TelemetryStringPanel title="Non-goals" values={model().nonGoals} />
          </div>
        </div>
      )}
    </Show>
  );
}
```

Use existing local helper components in `App.tsx`: `Metric`, `CommandList`, `TelemetryChecks`, `TelemetryStringPanel`, and `EmptyState`. Do not add a second design system.

Add bridge records and sections:

```tsx
function AppFacingBridgeRecords(props: { records: AppFacingBridgeRecord[] }) {
  return (
    <section class="chain-panel">
      <div class="lane-section-head">
        <h3>Bridge records</h3>
        <span>{props.records.length}</span>
      </div>
      <For each={props.records}>
        {(record) => (
          <article class="telemetry-fixture-card">
            <strong>{record.id}</strong>
            <span>{record.status}</span>
            <small>{record.sourceRef} -> {record.targetRef}</small>
          </article>
        )}
      </For>
    </section>
  );
}

function AppFacingPreviewSections(props: { sections: AppFacingPreviewSection[] }) {
  return (
    <section class="chain-panel">
      <div class="lane-section-head">
        <h3>Preview sections</h3>
        <span>{props.sections.length}</span>
      </div>
      <For each={props.sections}>
        {(section) => (
          <article class="telemetry-fixture-card">
            <strong>{section.title}</strong>
            <span>{section.id}</span>
            <small>{section.evidenceRefs.join(", ")}</small>
          </article>
        )}
      </For>
    </section>
  );
}
```

- [ ] **Step 7: Render tab content**

In the tab switch, add:

```tsx
<Match when={activeTab() === "app-preview"}>
  <AppFacingPreviewView preview={appFacingPreview()} copiedCommand={copiedCommand()} onCopy={copyCommand} />
</Match>
```

Use the same copy callback already passed to `ProductionTelemetryView`.

- [ ] **Step 8: Run UI tests**

Run:

```sh
cd packages/zigeffect
bun test workbench/src/App.test.tsx
```

Expected: app-facing UI tests pass and existing UI helper tests remain green.

## Task 9: Workbench Sample And WebUI Bridge Test

**Files:**
- Create: `packages/zigeffect/workbench/public/sample-app-facing-solid-webui-readonly-preview.json`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`

- [ ] **Step 1: Copy generated approved artifact into public sample**

Run:

```sh
cp .zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-solid-webui-readonly-preview.json packages/zigeffect/workbench/public/sample-app-facing-solid-webui-readonly-preview.json
```

If the generated path has a slightly different prefix, locate it with:

```sh
rg -l "\"schema\": \"zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1\"" .zig-cache/causal-artifacts
```

Then copy that exact ready artifact into the public sample path.

- [ ] **Step 2: Add WebUI bridge sample route**

In `workbenchBridge.ts`, extend `sampleNameFromSearch`:

```ts
if (sample === "app-preview") return "sample-app-facing-solid-webui-readonly-preview.json";
```

- [ ] **Step 3: Add WebUI bridge sample test**

In `workbenchBridge.test.ts`, add:

```ts
test("loadPayloadFromBridge can load the app-facing SolidJS read-only preview sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => {
      expect(sampleName).toBe("sample-app-facing-solid-webui-readonly-preview.json");
      return JSON.stringify({ schema: "zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1" });
    },
    "?sample=app-preview",
  );

  expect(payload.session?.artifact_path).toBe("sample-app-facing-solid-webui-readonly-preview.json");
  expect(payload.artifactJson).toContain("app-facing-production-integration-solid-webui-readonly-preview");
});
```

- [ ] **Step 4: Run workbench bridge tests**

Run:

```sh
cd packages/zigeffect
bun test workbench/src/workbenchBridge.test.ts
```

Expected: bridge tests pass.

## Task 10: Governance, Backlog, Docs, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-solid-webui-readonly-preview.md`
- Modify: `packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Register schema governance**

In `causal_schema_governance.zig`:

- increment schema count from 89 to 90;
- add schema id `zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1`;
- consumed by agents, reviewers, local SolidJS workbench, and future CI advisory remediation report;
- explicitly state no app writes, no NenDB production writes, no NenDB adapter execution, no Cockroach scope, no deployment mutation, no required CI status check enforcement.

Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: schema governance tests pass.

- [ ] **Step 2: Advance production hardening backlog**

In `causal_production_hardening_backlog.zig`:

- set recommendation to `start-app-facing-production-integration-ci-advisory-remediation-report`;
- set recommended branch to `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report`;
- mark this SolidJS read-only preview branch as delivered;
- add next branch guidance for CI advisory remediation report;
- preserve the No Cockroach/NenDB-only scope.

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: backlog tests pass.

- [ ] **Step 3: Add preview docs**

Create `packages/zigeffect/docs/app-facing-production-integration-solid-webui-readonly-preview.md` with these sections:

```md
# App-Facing Production Integration SolidJS Read-Only Preview

## Purpose

## Input Contract

## Output Artifact

## Authority Boundary

## SolidJS And webui-dev/zig-webui Scope

## Workbench View

## Commands

## Verification

## Non-Goals

## Next Branch
```

The docs must state:

- read-only SolidJS local preview only;
- webui bridge is `webui-dev/zig-webui`;
- no React renderer or alternate renderer;
- no hosted live dashboard;
- no app mutation controls;
- no app config/data writes;
- no NenDB production writes or adapter execution;
- no durable writes;
- no deployment mutation;
- no CI enforcement or required status checks;
- no Cockroach scope;
- no `applied=true`, production health, mutation-proof, or auto-apply claims.

- [ ] **Step 4: Link source bridge docs**

In `packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md`, add a short section named:

```md
## SolidJS Read-Only Preview Consumer
```

The section must link this bridge to the new tool and state that it is still record-only until the preview producer validates the source artifact.

- [ ] **Step 5: Update master roadmap**

In `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`:

- mark branch 54 `codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview` as delivered;
- add branch 55 `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report`;
- make the next-branch note match the backlog recommendation.

- [ ] **Step 6: Spot-check generated governance/backlog JSON**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json | rg "schema_count|solid-webui-readonly-preview|app-facing-production-integration-ci-advisory-remediation-report"
zig build causal-production-hardening-backlog -- --format json | rg "start-app-facing-production-integration-ci-advisory-remediation-report|codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report|solid-webui-readonly-preview"
```

Expected: schema count is 90 and the new recommendation appears.

## Task 11: Full Verification

**Files:**
- All modified files in this plan

- [ ] **Step 1: Run focused Zig producer verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig
```

Expected: all tests pass.

- [ ] **Step 2: Run focused workbench verification**

Run:

```sh
cd packages/zigeffect
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
```

Expected: typecheck exits 0 and workbench tests pass.

- [ ] **Step 3: Run zigeffect build verification**

Run:

```sh
cd packages/zigeffect
zig build test
zig build examples
zig build causal-app-facing-production-integration-solid-webui-readonly-preview
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: every command exits 0.

- [ ] **Step 4: Run root verification**

Run:

```sh
bun run check
bun run zig:test
git diff --check
```

Expected:

- `bun run check` exits 0;
- `bun run zig:test` exits 0;
- `git diff --check` exits 0.

## Task 12: Commit And Handoff

**Files:**
- Stage all files modified by this milestone.

- [ ] **Step 1: Review diff**

Run:

```sh
git status --short
git diff --stat
git diff -- packages/zigeffect/tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig
git diff -- packages/zigeffect/workbench/src/causalArtifact.ts
git diff -- packages/zigeffect/workbench/src/App.tsx
```

Expected: diff is limited to the files listed in this plan.

- [ ] **Step 2: Commit milestone**

Run:

```sh
git add docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview-implementation.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/workbench/src/causalArtifact.ts \
  packages/zigeffect/workbench/src/causalArtifact.test.ts \
  packages/zigeffect/workbench/src/App.tsx \
  packages/zigeffect/workbench/src/App.test.tsx \
  packages/zigeffect/workbench/src/workbenchBridge.test.ts \
  packages/zigeffect/workbench/public/sample-app-facing-solid-webui-readonly-preview.json \
  packages/zigeffect/docs/app-facing-production-integration-solid-webui-readonly-preview.md \
  packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git diff --cached --check
git commit -m "feat(zigeffect): add app-facing solid webui readonly preview"
```

Expected: commit succeeds.

- [ ] **Step 3: Prepare next branch**

After commit and only when the working tree is clean, create the next branch:

```sh
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report
```

Expected: branch creation succeeds and `git status --short --branch` shows the new branch with no pending changes.
