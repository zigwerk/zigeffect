# zigeffect Causal Schema Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an authoritative schema/version governance report for all current zigeffect causal artifact families.

**Architecture:** Create a static Zig schema registry and a `causal-schema-governance` CLI that emits text or JSON reports. The registry is explicit rather than source-scanned, so new schemas require intentional governance entries, docs, and tests. Documentation explains versioning, migration posture, compatibility postures, and requirements for future schema changes.

**Tech Stack:** Zig 0.16 build modules and tests, Markdown docs, Bun workspace verification.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Owns the schema registry, CLI parsing, text/JSON report formatting, and focused tests.
- Modify: `packages/zigeffect/build.zig`
  - Adds the schema governance module, executable, build step, and test dependencies.
- Create: `packages/zigeffect/docs/schema-governance.md`
  - Documents schema versioning, migration policy, compatibility postures, and the official schema matrix.
- Modify: `packages/zigeffect/README.md`
  - Adds a short command reference for `causal-schema-governance`.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds agent-facing guidance for schema changes.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Links the governance report into the causal artifact compatibility section.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks schema governance delivered after implementation.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Updates M9 progress, immediate branch queue, and the preferred future UI
    stack as SolidJS plus `webui-dev/zig-webui`.

---

### Task 1: Add Zig RED Tests And Build Wiring

**Files:**
- Create: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Create the RED test file**

Create `packages/zigeffect/tools/causal_schema_governance.zig` with tests first:

```zig
const std = @import("std");

test "schema governance usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-schema-governance") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.schema-governance.v1", schema_governance_schema);
}

test "schema governance inventory includes official schemas and excludes fake fixtures" {
    const entries = schemaEntries();
    try std.testing.expectEqual(@as(usize, 31), entries.len);
    try expectSchema(entries, "zigeffect.causal.v1");
    try expectSchema(entries, "zigeffect.causal.event.v1");
    try expectSchema(entries, "zigeffect.causal.app-application.v1");
    try expectSchema(entries, "zigeffect.causal.registry-application.v1");
    try expectSchema(entries, "zigeffect.causal.snapshot-manifest.v1");
    try expectSchema(entries, "zigeffect.causal.workbench-session.v1");
    try std.testing.expect(!hasSchema(entries, "zigeffect.causal.other.v1"));
    try std.testing.expect(!hasSchema(entries, "zigeffect.causal.unknown.v1"));
}

test "schema governance entries have required metadata" {
    for (schemaEntries()) |entry| {
        try std.testing.expect(entry.schema.len > 0);
        try std.testing.expectEqual(@as(u32, 1), entry.version);
        try std.testing.expect(entry.category.len > 0);
        try std.testing.expect(entry.status.len > 0);
        try std.testing.expect(entry.emitted_by.len > 0);
        try std.testing.expect(entry.consumed_by.len > 0);
        try std.testing.expect(entry.compatibility.len > 0);
        try std.testing.expect(entry.governance_requirements.len > 0);
    }
}

test "schema governance text report includes policy and representative schemas" {
    const report = try formatSchemaGovernanceText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal schema governance") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.schema-governance.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema count: 31") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event taxonomy version: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "versioning policy:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "migration policy:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.app-application.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.registry-application.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.snapshot-manifest.v1") != null);
}

test "schema governance json report is machine readable" {
    const report = try formatSchemaGovernanceJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.schema-governance.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"current_core_schema\": \"zigeffect.causal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"current_event_taxonomy_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_count\": 31") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schemas\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"compatibility\"") != null);
}

test "schema governance parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-schema-governance"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-schema-governance", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-schema-governance", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-schema-governance", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-schema-governance", "--json" }));
}
```

- [ ] **Step 2: Add build wiring**

In `packages/zigeffect/build.zig`, after `causal_artifacts_tool_module`, add:

```zig
    const causal_schema_governance_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_schema_governance.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_schema_governance_tool = b.addExecutable(.{
        .name = "zigeffect-causal-schema-governance",
        .root_module = causal_schema_governance_tool_module,
    });
    const run_causal_schema_governance_tool = b.addRunArtifact(causal_schema_governance_tool);
    if (b.args) |args| run_causal_schema_governance_tool.addArgs(args);
    const causal_schema_governance_step = b.step("causal-schema-governance", "Print causal artifact schema/version governance report");
    causal_schema_governance_step.dependOn(&run_causal_schema_governance_tool.step);

    const causal_schema_governance_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-schema-governance-tests",
        .root_module = causal_schema_governance_tool_module,
    });
    const run_causal_schema_governance_tool_tests = b.addRunArtifact(causal_schema_governance_tool_tests);
```

Add to the main test dependencies:

```zig
    test_step.dependOn(&run_causal_schema_governance_tool_tests.step);
```

Add to examples dependencies near `causal-artifacts`:

```zig
    examples_step.dependOn(&causal_schema_governance_tool.step);
    examples_step.dependOn(&run_causal_schema_governance_tool_tests.step);
```

- [ ] **Step 3: Verify RED**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: FAIL with missing identifiers such as `usage`, `schema_governance_schema`, `schemaEntries`, or `formatSchemaGovernanceText`.

---

### Task 2: Implement Schema Governance Report Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Add constants and types**

Add these declarations above the tests:

```zig
const schema_governance_schema = "zigeffect.causal.schema-governance.v1";
const current_core_schema = "zigeffect.causal.v1";
const current_core_schema_version: u32 = 1;
const current_event_taxonomy_version: u32 = 1;

const OutputFormat = enum { text, json };

const SchemaEntry = struct {
    schema: []const u8,
    version: u32,
    category: []const u8,
    status: []const u8,
    emitted_by: []const []const u8,
    consumed_by: []const []const u8,
    compatibility: []const []const u8,
    governance_requirements: []const []const u8,
};
```

- [ ] **Step 2: Add the static schema registry**

Implement `schemaEntries()` returning all 31 official entries from the design spec. Each entry must have version `1` and non-empty arrays. Use these category values:

```text
core-runtime
backend-export
app-runtime
dev-loop
governance
registry
snapshot-replay
app-remediation
workbench
test-coverage
```

Use these compatibility values only:

```text
legacy-tolerant
warn-forward
strict-v1
sink-contract
record-only
viewer-session
```

Representative entries should look like:

```zig
.{
    .schema = "zigeffect.causal.v1",
    .version = 1,
    .category = "core-runtime",
    .status = "current",
    .emitted_by = &.{"formatCausalJson"},
    .consumed_by = &.{ "causal-query", "causal-compare", "causal-loop", "causal-advice", "causal-workbench" },
    .compatibility = &.{ "legacy-tolerant", "warn-forward" },
    .governance_requirements = &.{ "compatibility tests", "taxonomy warning tests", "docs" },
},
.{
    .schema = "zigeffect.causal.app-application.v1",
    .version = 1,
    .category = "app-remediation",
    .status = "current",
    .emitted_by = &.{"causal-app-apply"},
    .consumed_by = &.{ "causal-workbench", "agents" },
    .compatibility = &.{ "strict-v1", "record-only" },
    .governance_requirements = &.{ "schema validation tests", "applied-state tests", "docs", "workbench mapping" },
},
```

- [ ] **Step 3: Add helpers and option parsing**

Implement:

```zig
fn usage() []const u8
fn parseOptions(args: []const []const u8) !OutputFormat
fn hasSchema(entries: []const SchemaEntry, schema: []const u8) bool
fn expectSchema(entries: []const SchemaEntry, schema: []const u8) !void
fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void
fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void
fn appendTextList(allocator: std.mem.Allocator, output: *std.ArrayList(u8), label: []const u8, values: []const []const u8) !void
```

`parseOptions` must accept no flags, `--format text`, and `--format json`.

- [ ] **Step 4: Add text formatter**

Implement `formatSchemaGovernanceText(allocator)` with these sections:

```text
zigeffect causal schema governance
schema: zigeffect.causal.schema-governance.v1
schema_version: 1
core schema: zigeffect.causal.v1 version 1
event taxonomy version: 1
schema count: 31

versioning policy:
- schema names the artifact family
- schema_version tracks the current shape inside that family
- event_taxonomy_version tracks event-kind role semantics

migration policy:
- legacy core artifacts without schema metadata remain readable
- strict governance artifacts fail closed on unsupported schema/version
- artifact rewrite tooling is deferred until a real v2 exists

schemas:
...
```

- [ ] **Step 5: Add JSON formatter**

Implement `formatSchemaGovernanceJson(allocator)` with root fields:

```text
schema
schema_version
current_core_schema
current_core_schema_version
current_event_taxonomy_version
schema_count
policy
schemas
```

- [ ] **Step 6: Add CLI main**

Implement:

```zig
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatSchemaGovernanceText(init.gpa),
        .json => try formatSchemaGovernanceJson(init.gpa),
    };
    defer init.gpa.free(report);
    std.debug.print("{s}", .{report});
}
```

- [ ] **Step 7: Verify GREEN**

Run:

```sh
cd packages/zigeffect
zig build test
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
zig build examples
```

Expected: all PASS/exit 0. The two command invocations should print text and JSON respectively.

---

### Task 3: Document Schema Governance Policy

**Files:**
- Create: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`

- [ ] **Step 1: Add `schema-governance.md`**

Create `packages/zigeffect/docs/schema-governance.md` with these sections:

```md
# zigeffect Schema Governance

## Command

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

## Versioning Policy

- `schema` names the artifact family.
- `schema_version` tracks the current shape inside that family.
- `event_taxonomy_version` tracks event-kind role semantics.
- Additive optional fields may keep the current version only when current consumers ignore unknown fields and tests cover graceful behavior.
- Required, renamed, removed, or semantically changed fields require a version bump and compatibility tests.
- New event kinds or role/sampleability changes require an event taxonomy version bump.

## Migration Policy

- Legacy core causal artifacts without root schema metadata remain readable.
- Current core tools warn, not crash, when future schema or taxonomy versions can still provide event ids.
- Strict governance artifacts fail closed on unsupported schema or version.
- Rewrite tooling is deferred until a real v2 artifact exists.

## New Schema Checklist

- Add schema name and version.
- Add producer tests.
- Add consumer or compatibility tests.
- Add a schema governance registry entry.
- Add README or guide docs.
- Add workbench mapping when user-facing.
- Add artifact manifest entries when retained in `.zig-cache/causal-artifacts`.
```

Then include the official schema list grouped by category. The list must match the design spec and report tool.

- [ ] **Step 2: Update README**

Add a short section near artifact schema docs:

```md
Print the causal schema governance report:

```bash
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

The report lists every official causal artifact schema, current version,
producer, consumer, compatibility posture, and schema-change checklist. Treat it
as the first stop before adding or changing causal artifact fields.
```

- [ ] **Step 3: Update agent guide**

Add an agent-facing rule:

```md
Before changing any causal artifact schema, run `zig build causal-schema-governance`
and update the registry, docs, and compatibility tests with the schema change.
Do not infer schema compatibility from string search alone.
```

- [ ] **Step 4: Update observable runtime docs**

In the schema compatibility section, mention `causal-schema-governance` as the authoritative matrix for schemas beyond core causal JSON.

---

### Task 4: Update Roadmaps

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update package roadmap**

Add to the M9/current causal runtime area:

```md
- Delivered: `zig build causal-schema-governance` prints the authoritative
  causal artifact schema/version matrix with compatibility posture, producer,
  consumer, migration policy, and new-schema checklist.
```

- [ ] **Step 2: Update master roadmap ledger**

Change M9 from deferred to active/partial:

```md
| M9 Operating model | active | schema governance report and policy docs exist; operations docs, performance budget, and release template remain | move to operations docs |
```

Update immediate queue:

```text
1. codex/zigeffect-causal-operations-docs
2. codex/zigeffect-causal-performance-budget
```

Preserve the frontend/workbench direction as SolidJS with
`webui-dev/zig-webui`. React remains an acceptable future adapter only when a
specific integration need outweighs the existing SolidJS workbench path.

- [ ] **Step 3: Run whitespace check**

Run:

```sh
git diff --check
```

Expected: PASS.

---

### Task 5: Full Verification And Commit

**Files:**
- All changed files in Tasks 1 through 4.

- [ ] **Step 1: Run focused Zig verification**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
zig build examples
zig build test
```

Expected: all exit 0.

- [ ] **Step 2: Run workspace verification**

Run from repo root:

```sh
bun run check
bun run zig:test
git diff --check
```

Expected: all PASS.

- [ ] **Step 3: Inspect git status**

Run:

```sh
git status --short --branch
```

Expected: intended schema governance files are modified or added. The pre-existing unrelated untracked durable roadmap file remains untracked and unstaged.

- [ ] **Step 4: Commit implementation**

Stage only intended files:

```sh
git add packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/roadmap.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Commit:

```sh
git commit -m "feat(zigeffect): add causal schema governance report"
```

Expected: commit succeeds and the unrelated durable roadmap file remains untracked.
