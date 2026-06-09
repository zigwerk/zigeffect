# zigeffect App Remediation Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a non-mutating app remediation audit artifact for app causal JSON evidence.

**Architecture:** Create a sibling Zig tool, `causal-app-remediation-audit`, that reads one `zigeffect.causal.v1` app artifact, derives app advice through the existing `causal_advice` module, filters app-specific actions, and writes deterministic JSON/text audit reports with `approval_status=pending`, `applied=false`, and `mutation_authority=none`. Add minimal SolidJS workbench governance recognition for the new schema.

**Tech Stack:** Zig tools and `zig build`, existing `causal_advice` module, Bun/SolidJS workbench tests.

---

## File Structure

- Create `packages/zigeffect/tools/causal_app_remediation_audit.zig`
  - Owns CLI parsing, app advice parsing, app action mapping, deterministic JSON/text rendering, bounded string copies, artifact reads/writes, and unit tests.
- Modify `packages/zigeffect/build.zig`
  - Adds the tool module, executable step, test step, and examples-step dependencies.
- Modify `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Adds `app-remediation-audit` to governance schema detection and summary text.
- Modify `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Adds a focused app audit governance recognition test.
- Modify docs:
  - `packages/zigeffect/README.md`
  - `packages/zigeffect/docs/agent-guide.md`
  - `packages/zigeffect/docs/agent-observable-runtime.md`
  - `packages/zigeffect/docs/roadmap.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Task 1: Add App Audit Tool Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_remediation_audit.zig`

- [ ] **Step 1: Write the initial failing tests and constants**

Create `packages/zigeffect/tools/causal_app_remediation_audit.zig` with this test-first skeleton:

```zig
const std = @import("std");

const app_audit_schema = "zigeffect.causal.app-remediation-audit.v1";

const app_advice_text =
    \\zigeffect causal advice report
    \\artifact: .zig-cache/causal-artifacts/app.json
    \\actions: 3
    \\- action fix-app-config status=observed event=2 kind=assertion_recorded label=YACHDEE_ENV
    \\  why: app request is missing required configuration
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json lineage 2
    \\- action wire-app-requirement status=observed event=3 kind=assertion_recorded label=HealthService
    \\  why: app service requirement is missing a provider or binding
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 3
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json requirements 1
    \\- action inspect-app-response-failure status=observed event=4 kind=span_recorded label=app.response
    \\  why: app request recorded a failed response
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4
    \\  run: zig build causal-query -- --file .zig-cache/causal-artifacts/app.json lineage 4
    \\
;

test "usage text names app audit flags" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-app-remediation-audit -- local --artifact <path> --target <name> [--proposer <id>] [--out-prefix <path-prefix>]\n",
        usage(),
    );
}

test "output paths derive from artifact path and out prefix" {
    const defaults = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .artifact_path = ".zig-cache/causal-artifacts/app.json",
        .target = "yachdee-platform",
    });
    defer defaults.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-app-remediation-audit.json",
        defaults.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-app-remediation-audit.txt",
        defaults.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .artifact_path = ".zig-cache/causal-artifacts/app.json",
        .target = "yachdee-platform",
        .out_prefix = ".zig-cache/causal-artifacts/yachdee-platform",
    });
    defer custom.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
        custom.json_path,
    );
}

test "app advice parser keeps only app remediation actions" {
    const incidents = try parseAppAdviceIncidents(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/app.json",
        app_advice_text,
    );
    defer deinitAppIncidents(std.testing.allocator, incidents);

    try std.testing.expectEqual(@as(usize, 3), incidents.len);
    try std.testing.expectEqualStrings("fix-app-config", incidents[0].action);
    try std.testing.expectEqual(@as(u64, 2), incidents[0].event_id);
    try std.testing.expectEqualStrings("config-only", incidents[0].policy_gate);
    try std.testing.expectEqualStrings("app_config", incidents[0].subsystem);
    try std.testing.expectEqualStrings("YACHDEE_ENV", incidents[0].label);
    try std.testing.expectEqual(@as(usize, 2), incidents[0].query_commands.len);
}

test "app audit JSON records pending non-mutating app evidence" {
    const incidents = try parseAppAdviceIncidents(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/app.json",
        app_advice_text,
    );
    defer deinitAppIncidents(std.testing.allocator, incidents);

    const json = try formatAppAuditJson(std.testing.allocator, .{
        .mode = "local",
        .target = "yachdee-platform",
        .proposer = "local-agent",
        .artifact_path = ".zig-cache/causal-artifacts/app.json",
        .incidents = incidents,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.causal.app-remediation-audit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approval_status\": \"pending\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"policy_gates\": [\"config-only\", \"source-only\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "redacted_detail") == null);
}

test "app audit text mirrors policy gates and guardrails" {
    const incidents = try parseAppAdviceIncidents(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/app.json",
        app_advice_text,
    );
    defer deinitAppIncidents(std.testing.allocator, incidents);

    const text = try formatAppAuditText(std.testing.allocator, .{
        .mode = "local",
        .target = "yachdee-platform",
        .proposer = "local-agent",
        .artifact_path = ".zig-cache/causal-artifacts/app.json",
        .incidents = incidents,
    });
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect app remediation audit") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- config-only") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- source-only") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Do not set applied=true") != null);
}
```

- [ ] **Step 2: Run tests to verify the build target is missing**

Run:

```sh
cd packages/zigeffect && zig build causal-app-remediation-audit
```

Expected: fail with an unknown build step because `build.zig` does not wire the
new tool yet.

## Task 2: Wire The Tool Into Zig Build

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_app_remediation_audit.zig`

- [ ] **Step 1: Add build module and executable wiring**

In `packages/zigeffect/build.zig`, add a module after `causal_advice_tool_module`:

```zig
const causal_app_remediation_audit_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_remediation_audit.zig"),
    .target = target,
    .optimize = optimize,
});
causal_app_remediation_audit_tool_module.addImport("causal_advice", causal_advice_tool_module);
causal_app_remediation_audit_tool_module.addImport("causal_artifact", causal_artifact_tool_module);
```

Add tests near the other tool tests:

```zig
const causal_app_remediation_audit_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-remediation-audit-tests",
    .root_module = causal_app_remediation_audit_tool_module,
});
const run_causal_app_remediation_audit_tool_tests = b.addRunArtifact(causal_app_remediation_audit_tool_tests);
```

Add the executable near other remediation commands:

```zig
const causal_app_remediation_audit_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-remediation-audit",
    .root_module = causal_app_remediation_audit_tool_module,
});
const run_causal_app_remediation_audit_tool = b.addRunArtifact(causal_app_remediation_audit_tool);
if (b.args) |args| run_causal_app_remediation_audit_tool.addArgs(args);
const causal_app_remediation_audit_step = b.step("causal-app-remediation-audit", "Write a pending app remediation audit from an app causal artifact");
causal_app_remediation_audit_step.dependOn(&run_causal_app_remediation_audit_tool.step);
```

Add examples-step dependencies:

```zig
examples_step.dependOn(&causal_app_remediation_audit_tool.step);
examples_step.dependOn(&run_causal_app_remediation_audit_tool_tests.step);
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```sh
cd packages/zigeffect && zig build causal-app-remediation-audit
```

Expected: compile failure naming missing functions such as `usage`,
`outputPathsForOptions`, or `parseAppAdviceIncidents`.

## Task 3: Implement The App Audit Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_remediation_audit.zig`

- [ ] **Step 1: Implement data types and option parsing**

Add:

```zig
const causal_advice = @import("causal_advice");
const causal_artifact = @import("causal_artifact");

const max_app_incidents: usize = 64;
const max_audit_string_bytes: usize = 256;

const Options = struct {
    mode: []const u8,
    artifact_path: []const u8,
    target: []const u8,
    proposer: []const u8 = "local-agent",
    out_prefix: ?[]const u8 = null,
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

const AppIncident = struct {
    action: []const u8,
    status: []const u8,
    event_id: u64,
    event_kind: []const u8,
    label: []const u8,
    subsystem: []const u8,
    fix_category: []const u8,
    policy_gate: []const u8,
    query_commands: []const []const u8,
};

const AppAuditInput = struct {
    mode: []const u8,
    target: []const u8,
    proposer: []const u8,
    artifact_path: []const u8,
    incidents: []const AppIncident,
};
```

- [ ] **Step 2: Implement parser and mapping helpers**

Implement helpers with these exact signatures:

```zig
fn usage() []const u8
fn parseOptions(args: []const []const u8) !Options
fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths
fn parseAppAdviceIncidents(allocator: std.mem.Allocator, artifact_path: []const u8, advice_report: []const u8) ![]AppIncident
fn deinitAppIncidents(allocator: std.mem.Allocator, incidents: []const AppIncident) void
fn appMapping(action: []const u8) ?struct { subsystem: []const u8, fix_category: []const u8, policy_gate: []const u8 }
```

The mapping must return:

```zig
fix-app-config -> app_config, config-or-secret-binding, config-only
wire-app-requirement -> app_service_layer, service-provider-or-layer, source-only
inspect-app-response-failure -> app_request_path, response-or-handler-failure, source-only
inspect-app-retry-exhaustion -> app_dependency, retry-policy-or-upstream, source-only
close-app-resource -> app_resource_scope, resource-finalizer, source-only
resolve-app-fiber -> app_fiber_runtime, structured-concurrency, source-only
```

- [ ] **Step 3: Implement JSON and text formatting**

Add:

```zig
fn formatAppAuditJson(allocator: std.mem.Allocator, input: AppAuditInput) ![]const u8
fn formatAppAuditText(allocator: std.mem.Allocator, input: AppAuditInput) ![]const u8
fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void
fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void
fn appendPolicyGatesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), incidents: []const AppIncident) !void
fn appendVerificationCommandsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), incidents: []const AppIncident) !void
```

The JSON must include `schema`, `schema_version`, `mode`, `target`,
`proposer`, `source`, `approval_status`, `applied`, `mutation_authority`,
`incident_count`, `incidents`, `policy_gates`, `verification_commands`, and
`claim_guardrails` in deterministic order.

- [ ] **Step 4: Implement main command**

`main` must:

1. parse CLI options;
2. read `options.artifact_path` with a 1 MiB ceiling;
3. call `causal_artifact.appendArtifactCompatibilityWarnings` indirectly by
   letting `causal_advice.buildAdviceReport` parse/report compatibility;
4. call `causal_advice.buildAdviceReport`;
5. parse app incidents;
6. fail with `NoAppRemediationActions` if none exist;
7. write JSON and text artifacts;
8. print the text report.

Usage errors must call:

```zig
fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-remediation-audit error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}
```

- [ ] **Step 5: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build causal-app-remediation-audit -- local --artifact .zig-cache/causal-artifacts/app.json --target yachdee-platform
cd packages/zigeffect && zig build examples
```

Expected: the first command may fail with `MissingAppArtifact` when no local app
artifact exists; `zig build examples` must pass and run the tool tests.

## Task 4: Add Workbench Governance Recognition

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [ ] **Step 1: Write failing workbench test**

Add to `causalArtifact.test.ts`:

```ts
test("deriveGovernanceModel detects app remediation audit artifacts", () => {
  const governance = deriveGovernanceModel({
    schema: "zigeffect.causal.app-remediation-audit.v1",
    schema_version: 1,
    target: "yachdee-platform",
    applied: false,
    mutation_authority: "none",
    incident_count: 2,
  }, { artifactPath: "app-audit.json" });

  expect(governance?.kind).toBe("app-remediation-audit");
  expect(governance?.summary).toContain("2 app incidents");
  expect(governance?.applied).toBe(false);
  expect(governance?.mutationAuthority).toBe("none");
});
```

- [ ] **Step 2: Verify RED**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: fail because `app-remediation-audit` is not in
`GovernanceArtifactKind`.

- [ ] **Step 3: Implement recognition**

In `causalArtifact.ts`:

```ts
export type GovernanceArtifactKind =
  | "audit-chain"
  | "remediation-audit"
  | "app-remediation-audit"
  | "remediation-decision"
  | "patch-proposal"
  | "registry-readiness"
  | "registry-application"
  | "policy-decision";
```

Add to `governanceKindForSchema`:

```ts
case "zigeffect.causal.app-remediation-audit.v1":
  return "app-remediation-audit";
```

Adjust `deriveGovernanceModel` summary:

```ts
const incidentCount = numberValue(artifact.incident_count);
const summary = kind === "app-remediation-audit" && incidentCount !== null
  ? `${incidentCount} app incidents for ${target}`
  : chain
    ? `${chain.assessment} audit chain for ${target}`
    : `${kind} for ${target}`;
```

Add helper:

```ts
function numberValue(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}
```

- [ ] **Step 4: Verify GREEN**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

Expected: both pass.

## Task 5: Update Documentation And Roadmaps

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Document command usage**

Add concise docs that name:

```sh
zig build causal-app-remediation-audit -- local --artifact <causal-json> --target <app-target>
```

and state that the artifact preserves `approval_status=pending`,
`applied=false`, and `mutation_authority=none`.

- [ ] **Step 2: Update roadmap status**

Update M8 evidence from "remediation artifacts not started" to "app
remediation audit artifacts exist; policy gates and app patch proposals remain
next".

- [ ] **Step 3: Verify docs**

Run:

```sh
rg -n "causal-app-remediation-audit|app-remediation-audit|app remediation audit" packages/zigeffect/README.md packages/zigeffect/docs docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git diff --check
```

Expected: command and schema are findable; no whitespace errors.

## Task 6: Full Verification And Commit

**Files:**
- All files touched in this branch.

- [ ] **Step 1: Format**

Run:

```sh
cd packages/zigeffect && zig fmt tools/causal_app_remediation_audit.zig build.zig
```

- [ ] **Step 2: Full verification**

Run:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run check
bun run zig:test
git diff --check
```

Expected: all pass. Note any intentionally argument-gated command behavior.

- [ ] **Step 3: Commit**

Stage only intended files:

```sh
git add \
  docs/superpowers/plans/2026-06-09-zigeffect-app-remediation-audit.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/tools/causal_app_remediation_audit.zig \
  packages/zigeffect/workbench/src/causalArtifact.test.ts \
  packages/zigeffect/workbench/src/causalArtifact.ts
git commit -m "feat(zigeffect): add app remediation audit artifacts"
```

Do not stage unrelated untracked files.

## Self-Review

- Spec coverage: the plan covers the app audit command, schema, bounded output,
  app action mapping, workbench detection, docs, and verification.
- Placeholder scan: no `TBD`, `TODO`, "implement later", or unspecified tests
  are used as work items.
- Type consistency: the plan consistently uses
  `zigeffect.causal.app-remediation-audit.v1`,
  `causal-app-remediation-audit`, `AppIncident`, `AppAuditInput`, and
  `mutation_authority=none`.
