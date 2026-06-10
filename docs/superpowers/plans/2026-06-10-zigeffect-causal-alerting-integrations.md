# zigeffect Causal Alerting Integrations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic, record-only alerting and external integration contract for zigeffect causal production hardening.

**Architecture:** Add one focused Zig report tool that emits text and JSON for alert channel contracts, severity/routing/escalation policy, payload fields, preview fixtures, negative fixtures, and verification commands. Wire it through `build.zig`, register the schema in schema governance, mark the backlog item delivered, and update docs so the next branch becomes the SolidJS live dashboard streaming workbench.

**Tech Stack:** Zig report tools and tests, zigeffect build graph, Markdown docs, Bun top-level verification.

---

## Files

- Create: `packages/zigeffect/tools/causal_alerting_integrations.zig`
- Create: `packages/zigeffect/docs/alerting-integrations.md`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/tools/causal_performance_budget.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/docs/m9-completion-audit.md`
- Modify: `packages/zigeffect/docs/performance-budget.md`
- Modify: `packages/zigeffect/README.md`

## Task 1: Red Tests For Alerting Tool

**Files:**
- Create: `packages/zigeffect/tools/causal_alerting_integrations.zig`

- [ ] **Step 1: Add the initial failing test shell**

Create `packages/zigeffect/tools/causal_alerting_integrations.zig` with this test-first shell:

```zig
const std = @import("std");

test "alerting integrations metadata names schema source contracts and next branch" {
    try std.testing.expectEqualStrings("zigeffect.causal.alerting-integrations.v1", alerting_integrations_schema);
    try std.testing.expectEqual(@as(u32, 1), alerting_integrations_schema_version);
    try expectSourceContract("zigeffect.causal.production-artifact-aggregation.v1");
    try expectSourceContract("zigeffect.causal.production-deployment-runbooks.v1");
    try expectSourceContract("zigeffect.causal.artifact-access-control.v1");
    try expectSourceContract("zigeffect.causal.encryption-at-rest-policy.v1");
    try expectSourceContract("zigeffect.causal.agent-query.v1");
    try std.testing.expectEqualStrings("start-live-dashboard-streaming-workbench", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-live-dashboard-streaming-workbench", recommended_next_branch);
}

test "alerting integrations preserves channels severity routing fixtures and non-goals" {
    try expectChannel("slack");
    try expectChannel("linear");
    try expectChannel("jira");
    try expectChannel("siem");
    try expectChannel("paging");
    try expectSeverity("critical");
    try expectRoutingClass("production-incident");
    try expectPayloadField("alert_record_id");
    try expectPayloadField("dedupe_key");
    try expectFixture("slack-ci-failure-preview");
    try expectFixture("linear-release-gate-preview");
    try expectFixture("jira-production-incident-preview");
    try expectFixture("siem-security-review-preview");
    try expectFixture("paging-critical-incident-handoff");
    try expectNegativeFixture("unredacted-payload-blocked");
    try expectNegativeFixture("paging-without-human-approval-denied");
    try expectNegativeFixture("agent-live-delivery-denied");
    try expectNonGoal("live Slack Linear Jira SIEM paging delivery");
    try expectNonGoal("network calls");
    try expectNonGoal("production mutation authority");
}

test "alerting integrations text report includes boundaries" {
    const report = try formatAlertingIntegrationsText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.alerting-integrations.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "integration channels:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "paging-critical-incident-handoff") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "delivery state: not-sent") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
}

test "alerting integrations json report is machine readable" {
    const report = try formatAlertingIntegrationsJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.alerting-integrations.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"integration_channels\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"severity_policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"routing_policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"negative_fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
}

test "alerting integrations json report parses" {
    const ReportEnvelope = struct {
        schema: []const u8,
        schema_version: u32,
        mutation_authority: []const u8,
        recommended_next_branch: []const u8,
    };

    const report = try formatAlertingIntegrationsJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    var parsed = try std.json.parseFromSlice(ReportEnvelope, std.testing.allocator, report, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings(alerting_integrations_schema, parsed.value.schema);
    try std.testing.expectEqual(alerting_integrations_schema_version, parsed.value.schema_version);
    try std.testing.expectEqualStrings("none", parsed.value.mutation_authority);
    try std.testing.expectEqualStrings(recommended_next_branch, parsed.value.recommended_next_branch);
}

test "alerting integrations parses text json and errors" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-alerting-integrations"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format", "" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--json" }));
}
```

- [ ] **Step 2: Run the red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_alerting_integrations.zig
```

Expected: fail with undeclared identifiers such as `alerting_integrations_schema`, `expectChannel`, `formatAlertingIntegrationsText`, and `OutputFormat`.

## Task 2: Implement Alerting Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_alerting_integrations.zig`

- [ ] **Step 1: Add constants and structs**

Add:

```zig
pub const alerting_integrations_schema = "zigeffect.causal.alerting-integrations.v1";
pub const alerting_integrations_schema_version: u32 = 1;
pub const recommendation = "start-live-dashboard-streaming-workbench";
pub const recommended_next_branch = "codex/zigeffect-causal-live-dashboard-streaming-workbench";

const OutputFormat = enum { text, json };
const generated_by = "causal-alerting-integrations";

const IntegrationChannel = struct {
    id: []const u8,
    payload_class: []const u8,
    required_evidence: []const u8,
    redaction_posture: []const u8,
    delivery_mode: []const u8,
    mutation_posture: []const u8,
};

const SeverityPolicy = struct {
    severity: []const u8,
    meaning: []const u8,
    allowed_routes: []const []const u8,
    escalation_gate: []const u8,
};

const RoutingPolicy = struct {
    routing_class: []const u8,
    default_channels: []const []const u8,
    required_context: []const u8,
    blocked_without: []const u8,
};

const PayloadField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const IntegrationFixture = struct {
    id: []const u8,
    channel: []const u8,
    severity: []const u8,
    routing_class: []const u8,
    payload_class: []const u8,
    delivery_state: []const u8,
    mutation_authority: []const u8,
    evidence_refs: []const []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    attempted_channel: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};
```

- [ ] **Step 2: Add deterministic policy arrays**

Add arrays with these exact ids:

```zig
const source_contracts: []const []const u8 = &.{
    "zigeffect.causal.production-artifact-aggregation.v1",
    "zigeffect.causal.production-deployment-runbooks.v1",
    "zigeffect.causal.artifact-access-control.v1",
    "zigeffect.causal.encryption-at-rest-policy.v1",
    "zigeffect.causal.agent-query.v1",
};

const channels: []const IntegrationChannel = &.{
    .{ .id = "slack", .payload_class = "chat-summary-preview", .required_evidence = "redacted finding ids and runbook gate", .redaction_posture = "redacted-summary-only", .delivery_mode = "record-only not-sent", .mutation_posture = "no message sent" },
    .{ .id = "linear", .payload_class = "work-item-preview", .required_evidence = "release gate or incident finding ids", .redaction_posture = "redacted issue summary", .delivery_mode = "record-only not-created", .mutation_posture = "no issue created" },
    .{ .id = "jira", .payload_class = "ticket-preview", .required_evidence = "incident runbook and reviewed evidence refs", .redaction_posture = "redacted ticket fields", .delivery_mode = "record-only not-created", .mutation_posture = "no ticket created" },
    .{ .id = "siem", .payload_class = "security-event-preview", .required_evidence = "security-review routing and redacted event refs", .redaction_posture = "id-only security summary", .delivery_mode = "record-only not-forwarded", .mutation_posture = "no SIEM event sent" },
    .{ .id = "paging", .payload_class = "critical-handoff-preview", .required_evidence = "critical severity, incident owner review, human approval evidence", .redaction_posture = "minimal incident summary", .delivery_mode = "record-only not-paged", .mutation_posture = "no page sent" },
};

const severity_names: []const []const u8 = &.{ "info", "warning", "error", "critical" };
const routing_class_names: []const []const u8 = &.{ "dev-loop", "ci-failure", "release-gate", "production-incident", "security-review" };
```

Then define `severity_policy`, `routing_policy`, `payload_fields`, `escalation_policy`, `dedupe_rules`, `integration_fixtures`, `negative_fixtures`, `authority_boundaries`, `non_goals`, and `verification_commands`. Include the required ids from the red tests and these non-goals:

```zig
"live Slack Linear Jira SIEM paging delivery",
"network calls",
"credential or token loading",
"secret storage",
"ticket or issue mutation",
"paging humans from deterministic tests",
"production telemetry ingestion",
"Cockroach adapter work",
"React workbench support",
"production mutation authority",
```

- [ ] **Step 3: Add formatters and helpers**

Implement:

```zig
fn usage() []const u8
fn parseOptions(args: []const []const u8) !OutputFormat
pub fn formatAlertingIntegrationsText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8
pub fn formatAlertingIntegrationsJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8
fn appendJsonStringProperty(...)
fn appendJsonBoolProperty(...)
fn appendJsonU32Property(...)
fn appendJsonStringArrayProperty(...)
fn appendJsonString(...)
fn failUsage(err: anyerror) noreturn
pub fn main(init: std.process.Init) !void
```

Use the same manual JSON style as `causal_encryption_at_rest_policy.zig`. Ensure all JSON is parseable with `std.json.parseFromSlice`.

- [ ] **Step 4: Add test helper functions**

Implement:

```zig
fn expectSourceContract(schema: []const u8) !void
fn expectChannel(id: []const u8) !void
fn expectSeverity(name: []const u8) !void
fn expectRoutingClass(name: []const u8) !void
fn expectPayloadField(name: []const u8) !void
fn expectFixture(id: []const u8) !void
fn expectNegativeFixture(id: []const u8) !void
fn expectNonGoal(value: []const u8) !void
```

- [ ] **Step 5: Run green test**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_alerting_integrations.zig
zig test tools/causal_alerting_integrations.zig
```

Expected: all alerting integration tests pass.

## Task 3: Build Target

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Verify build target is missing**

Run:

```sh
cd packages/zigeffect
zig build causal-alerting-integrations
```

Expected: fail with no step named `causal-alerting-integrations`.

- [ ] **Step 2: Add build target**

Add the build target near the other production-hardening tools:

```zig
const causal_alerting_integrations_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_alerting_integrations.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_alerting_integrations_tool = b.addExecutable(.{
    .name = "zigeffect-causal-alerting-integrations",
    .root_module = causal_alerting_integrations_tool_module,
});
const run_causal_alerting_integrations_tool = b.addRunArtifact(causal_alerting_integrations_tool);
if (b.args) |args| run_causal_alerting_integrations_tool.addArgs(args);
const causal_alerting_integrations_step = b.step("causal-alerting-integrations", "Print causal alerting integrations report");
causal_alerting_integrations_step.dependOn(&run_causal_alerting_integrations_tool.step);

const causal_alerting_integrations_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-alerting-integrations-tests",
    .root_module = causal_alerting_integrations_tool_module,
});
const run_causal_alerting_integrations_tool_tests = b.addRunArtifact(causal_alerting_integrations_tool_tests);
test_step.dependOn(&run_causal_alerting_integrations_tool_tests.step);
```

- [ ] **Step 3: Verify build target**

Run:

```sh
cd packages/zigeffect
zig fmt build.zig
zig build causal-alerting-integrations
zig build causal-alerting-integrations -- --format json
```

Expected: both commands exit 0; JSON includes `"recommended_next_branch": "codex/zigeffect-causal-live-dashboard-streaming-workbench"`.

## Task 4: Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Write failing schema governance expectations**

In `causal_schema_governance.zig` tests:

- change expected schema count from `42` to `43`;
- add `try expectSchema(entries, "zigeffect.causal.alerting-integrations.v1");`;
- add text assertion for `zigeffect.causal.alerting-integrations.v1`;
- add JSON assertion for `"schema": "zigeffect.causal.alerting-integrations.v1"`.

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: schema governance tests fail because the new schema is not registered.

- [ ] **Step 2: Add schema entry**

Add this entry after `zigeffect.causal.encryption-at-rest-policy.v1`:

```zig
.{
    .schema = "zigeffect.causal.alerting-integrations.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-alerting-integrations"},
    .consumed_by = &.{ "deployment runbooks", "rollout guardrails", "human-agent feedback loop", "live dashboard planning", "agents" },
    .compatibility = &.{"record-only"},
    .governance_requirements = &.{ "alerting integration tests", "negative fixtures", "operations docs", "roadmap update" },
},
```

- [ ] **Step 3: Update schema docs**

Add `zigeffect.causal.alerting-integrations.v1` to `packages/zigeffect/docs/schema-governance.md` under Production Hardening. State that it defines channel contracts, severity/routing/escalation policy, payload fields, preview fixtures, negative fixtures, and authority boundaries without sending notifications or mutating external systems.

- [ ] **Step 4: Verify schema governance**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_schema_governance.zig
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

Expected: schema count is 43 and the alerting schema appears in text and JSON.

## Task 5: Backlog Advancement

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Write failing backlog expectations**

In `causal_production_hardening_backlog.zig` tests, change:

```zig
"start-alerting-integrations"
"codex/zigeffect-causal-alerting-integrations"
```

to:

```zig
"start-live-dashboard-streaming-workbench"
"codex/zigeffect-causal-live-dashboard-streaming-workbench"
```

Add an expectation that the alerting item exists and that text/JSON reports mention the live dashboard branch.

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: fail because constants and item status still point at alerting.

- [ ] **Step 2: Update backlog implementation**

Change top-level constants:

```zig
pub const recommendation = "start-live-dashboard-streaming-workbench";
pub const recommended_next_branch = "codex/zigeffect-causal-live-dashboard-streaming-workbench";
```

Update `alerting-integrations`:

- `status = "delivered"`;
- summary says it defines record-only alerting and integration event contracts;
- evidence sources include `packages/zigeffect/tools/causal_alerting_integrations.zig`, `packages/zigeffect/docs/alerting-integrations.md`, and `packages/zigeffect/docs/schema-governance.md`;
- verification commands include `zig build causal-alerting-integrations` and `zig build causal-alerting-integrations -- --format json`.

Keep `live-dashboard-streaming-workbench` planned.

- [ ] **Step 3: Update backlog docs**

In `production-hardening-backlog.md`:

- update recommendation to `start-live-dashboard-streaming-workbench`;
- mark `alerting-integrations` delivered in dependency order;
- add a short `alerting-integrations.md` authority-boundary paragraph;
- add alerting commands to the verification suite.

- [ ] **Step 4: Verify backlog**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_production_hardening_backlog.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

Expected: backlog recommends `codex/zigeffect-causal-live-dashboard-streaming-workbench`.

## Task 6: Docs And README

**Files:**
- Create: `packages/zigeffect/docs/alerting-integrations.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/docs/m9-completion-audit.md`
- Modify: `packages/zigeffect/docs/performance-budget.md`
- Modify: `packages/zigeffect/tools/causal_performance_budget.zig`
- Modify: `packages/zigeffect/README.md`

- [ ] **Step 1: Create alerting docs**

Create `packages/zigeffect/docs/alerting-integrations.md` with sections:

- Command
- Source Contracts
- Policy Boundary
- Integration Channels
- Severity And Routing
- Escalation Policy
- Payload Fields
- Preview Fixtures
- Negative Fixtures
- Authority Boundaries
- Verification Suite

Include the exact statement that the contract does not send alerts, page humans, create tickets, call networks, read secrets, mutate external systems, add Cockroach, or switch the workbench to React.

- [ ] **Step 2: Update operations docs**

Add an `Alerting Integrations` section after `Encryption At Rest Policy`. The section should include the two build commands, schema name, source contracts, and non-goals.

In the `Production Gaps` list, replace `alerting, paging, Slack, Linear, Jira, or SIEM integrations` with `live alert delivery, live ticket creation, SIEM forwarding, or paging execution`.

- [ ] **Step 3: Update roadmap and M9 audit docs**

In `roadmap.md`, add a delivered bullet for `causal-alerting-integrations` and update the backlog next branch bullet to `codex/zigeffect-causal-live-dashboard-streaming-workbench`.

In `m9-completion-audit.md`, update the handoff paragraph to say the backlog now recommends the live dashboard streaming workbench after record-only alerting integrations.

- [ ] **Step 4: Update performance budget wording**

Change non-goal wording from `alerting or paging` to `live alert delivery or paging execution` in:

- `packages/zigeffect/tools/causal_performance_budget.zig`
- `packages/zigeffect/docs/performance-budget.md`

- [ ] **Step 5: Update README stale handoff**

In `packages/zigeffect/README.md`, update the production-hardening backlog paragraph so it recommends `codex/zigeffect-causal-live-dashboard-streaming-workbench` after the delivered hardening chain, not an older runtime branch.

- [ ] **Step 6: Search for stale handoffs**

Run:

```sh
rg -n 'start-alerting-integrations|codex/zigeffect-causal-alerting-integrations|alerting or paging|Slack, Linear, Jira, or SIEM integrations' packages/zigeffect/docs packages/zigeffect/tools packages/zigeffect/README.md
```

Expected: remaining hits are either historical branch references for the delivered backlog item, command/tool names, or intentional old specs outside active zigeffect docs.

## Task 7: Final Verification And Commit

**Files:**
- All files above

- [ ] **Step 1: Focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_alerting_integrations.zig
zig build causal-alerting-integrations
zig build causal-alerting-integrations -- --format json
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
zig build causal-performance-budget -- --format json
```

Expected: all commands exit 0.

- [ ] **Step 2: Full verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Stage only this milestone**

Run:

```sh
git add docs/superpowers/specs/2026-06-10-zigeffect-causal-alerting-integrations-design.md docs/superpowers/plans/2026-06-10-zigeffect-causal-alerting-integrations.md packages/zigeffect/tools/causal_alerting_integrations.zig packages/zigeffect/docs/alerting-integrations.md packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/docs/schema-governance.md packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/docs/production-hardening-backlog.md packages/zigeffect/tools/causal_performance_budget.zig packages/zigeffect/docs/performance-budget.md packages/zigeffect/docs/operations.md packages/zigeffect/docs/roadmap.md packages/zigeffect/docs/m9-completion-audit.md packages/zigeffect/README.md
```

Before committing, run `git status --short` and confirm unrelated dirty files remain unstaged.

- [ ] **Step 4: Commit implementation**

Run:

```sh
git commit -m "feat(zigeffect): add alerting integrations contract"
```

## Self-Review

- Spec coverage: Tasks cover the report tool, schema, build target, backlog advancement, docs, README stale handoff, performance wording, verification, and commit.
- Placeholder scan: no task uses open-ended `TBD`, `TODO`, or unspecified implementation language.
- Type consistency: schema name is consistently `zigeffect.causal.alerting-integrations.v1`; build step is `causal-alerting-integrations`; branch handoff advances to `codex/zigeffect-causal-live-dashboard-streaming-workbench`.
