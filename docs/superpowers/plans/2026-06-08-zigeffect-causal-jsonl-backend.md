# zigeffect Causal JSONL Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first concrete causal backend adapter: a schema-tagged JSON Lines sink with no-partial-row byte ceilings and backend conformance coverage.

**Architecture:** Add a focused `causal_jsonl_backend.zig` service module that formats one stored `CausalEvent` as one compact JSON row and appends rows to a caller-owned `std.ArrayList(u8)`. `CausalStore` remains authoritative; backend errors are best-effort sink failures counted by the store.

**Tech Stack:** Zig 0.16, `std.ArrayList`, `std.json.parseFromSlice`, existing `CausalBackend`, existing causal backend conformance fixtures, Bun repo checks.

---

## File Structure

- Create: `packages/zigeffect/src/services/causal_jsonl_backend.zig`
  - Owns JSONL row schema constants, single-row formatting, backend state, and byte-ceiling behavior.
- Create: `packages/zigeffect/test/causal_jsonl_backend_test.zig`
  - Tests formatter shape, backend conformance behavior, redaction/truncation propagation, and no-partial-row overflow behavior.
- Modify: `packages/zigeffect/src/zigeffect.zig`
  - Exports the JSONL backend module and public API through `fx`.
- Modify: `packages/zigeffect/test/all_test.zig`
  - Imports the JSONL backend tests into package tests.
- Modify: `packages/zigeffect/build.zig`
  - Adds direct `zig build causal-jsonl-backend` step and wires it into the package `test` step.
- Modify: `packages/zigeffect/README.md`
  - Documents JSONL backend usage and metadata caveats.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Adds agent guidance for JSONL rows, backend failures, and pairing with full JSON artifacts.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Updates storage strategy with the concrete JSONL adapter.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks the JSONL backend branch as delivered and sets the next M4 branch.

## Task 1: Formatter Test First

**Files:**
- Create: `packages/zigeffect/test/causal_jsonl_backend_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write the failing formatter test**

Create `packages/zigeffect/test/causal_jsonl_backend_test.zig` with:

```zig
const std = @import("std");
const fx = @import("zigeffect");

const JsonLineRow = struct {
    schema: []const u8,
    schema_version: u32,
    event_taxonomy_version: u32,
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};

fn expectSingleJsonLine(line: []const u8) ![]const u8 {
    try std.testing.expect(line.len > 1);
    try std.testing.expectEqual(@as(u8, '\n'), line[line.len - 1]);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, line, "\n"));
    return line[0 .. line.len - 1];
}

test "formatCausalJsonLine emits schema-tagged escaped row" {
    const line = try fx.formatCausalJsonLine(std.testing.allocator, .{
        .id = 42,
        .kind = .run_started,
        .run_id = 7,
        .parent_id = null,
        .fiber_id = 99,
        .scope_id = 11,
        .trace_id = 101,
        .span_id = 202,
        .label = "quote \" newline\n tab\t slash \\",
        .type_name = "JsonLineFormatter",
        .status = "success",
        .redacted_detail = "detail\rvalue",
    });
    defer std.testing.allocator.free(line);

    const row_json = try expectSingleJsonLine(line);
    var parsed = try std.json.parseFromSlice(JsonLineRow, std.testing.allocator, row_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings(fx.causal_jsonl_event_schema, parsed.value.schema);
    try std.testing.expectEqual(fx.causal_jsonl_event_schema_version, parsed.value.schema_version);
    try std.testing.expectEqual(fx.causal_event_taxonomy_version, parsed.value.event_taxonomy_version);
    try std.testing.expectEqual(@as(u64, 42), parsed.value.id);
    try std.testing.expectEqualStrings("run_started", parsed.value.kind);
    try std.testing.expectEqual(@as(?u64, 7), parsed.value.run_id);
    try std.testing.expectEqual(@as(?u64, null), parsed.value.parent_id);
    try std.testing.expectEqual(@as(?u64, 99), parsed.value.fiber_id);
    try std.testing.expectEqual(@as(?u64, 11), parsed.value.scope_id);
    try std.testing.expectEqual(@as(?u64, 101), parsed.value.trace_id);
    try std.testing.expectEqual(@as(?u64, 202), parsed.value.span_id);
    try std.testing.expectEqualStrings("quote \" newline\n tab\t slash \\", parsed.value.label);
    try std.testing.expectEqualStrings("JsonLineFormatter", parsed.value.type_name);
    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expectEqualStrings("detail\rvalue", parsed.value.redacted_detail);
}
```

Add the test import to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("causal_jsonl_backend_test.zig");
```

Place it after the existing `causal_backend_conformance_test.zig` import.

- [ ] **Step 2: Run the formatter test red check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: FAIL because `fx.formatCausalJsonLine`, `fx.causal_jsonl_event_schema`, and `fx.causal_jsonl_event_schema_version` do not exist yet.

## Task 2: Formatter Implementation

**Files:**
- Create: `packages/zigeffect/src/services/causal_jsonl_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add the JSONL formatter module**

Create `packages/zigeffect/src/services/causal_jsonl_backend.zig` with:

```zig
const std = @import("std");
const causal = @import("causal.zig");

pub const Allocator = std.mem.Allocator;
pub const causal_jsonl_event_schema = "zigeffect.causal.event.v1";
pub const causal_jsonl_event_schema_version: u32 = 1;

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

pub fn formatCausalJsonLine(allocator: Allocator, event: causal.CausalEvent) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, causal_jsonl_event_schema);
    try output.print(
        allocator,
        ",\"schema_version\":{d},\"event_taxonomy_version\":{d},\"id\":{d},\"kind\":",
        .{ causal_jsonl_event_schema_version, causal.causal_event_taxonomy_version, event.id },
    );
    try appendJsonString(&output, allocator, @tagName(event.kind));
    try output.appendSlice(allocator, ",\"run_id\":");
    try appendOptionalJsonU64(&output, allocator, event.run_id);
    try output.appendSlice(allocator, ",\"parent_id\":");
    try appendOptionalJsonU64(&output, allocator, event.parent_id);
    try output.appendSlice(allocator, ",\"fiber_id\":");
    try appendOptionalJsonU64(&output, allocator, event.fiber_id);
    try output.appendSlice(allocator, ",\"scope_id\":");
    try appendOptionalJsonU64(&output, allocator, event.scope_id);
    try output.appendSlice(allocator, ",\"trace_id\":");
    try appendOptionalJsonU64(&output, allocator, event.trace_id);
    try output.appendSlice(allocator, ",\"span_id\":");
    try appendOptionalJsonU64(&output, allocator, event.span_id);
    try output.appendSlice(allocator, ",\"label\":");
    try appendJsonString(&output, allocator, event.label);
    try output.appendSlice(allocator, ",\"type_name\":");
    try appendJsonString(&output, allocator, event.type_name);
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(&output, allocator, event.status);
    try output.appendSlice(allocator, ",\"redacted_detail\":");
    try appendJsonString(&output, allocator, event.redacted_detail);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}
```

- [ ] **Step 2: Export the formatter API**

In `packages/zigeffect/src/zigeffect.zig`, add the module inside `pub const services`:

```zig
    pub const causal_jsonl_backend = @import("services/causal_jsonl_backend.zig");
```

Add these service exports near the causal exports:

```zig
    pub const causal_jsonl_event_schema = causal_jsonl_backend.causal_jsonl_event_schema;
    pub const causal_jsonl_event_schema_version = causal_jsonl_backend.causal_jsonl_event_schema_version;
    pub const formatCausalJsonLine = causal_jsonl_backend.formatCausalJsonLine;
```

Add root-level re-exports near the existing causal root aliases:

```zig
pub const causal_jsonl_event_schema = services.causal_jsonl_event_schema;
pub const causal_jsonl_event_schema_version = services.causal_jsonl_event_schema_version;
pub const formatCausalJsonLine = services.formatCausalJsonLine;
```

- [ ] **Step 3: Run the formatter test green check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: PASS for the new formatter test and existing raw package tests.

- [ ] **Step 4: Commit formatter slice**

Run:

```bash
git add packages/zigeffect/test/causal_jsonl_backend_test.zig packages/zigeffect/test/all_test.zig packages/zigeffect/src/services/causal_jsonl_backend.zig packages/zigeffect/src/zigeffect.zig
git commit -m "feat(zigeffect): format causal jsonl events"
```

## Task 3: Backend Conformance Test First

**Files:**
- Modify: `packages/zigeffect/test/causal_jsonl_backend_test.zig`

- [ ] **Step 1: Add backend conformance tests**

Extend `packages/zigeffect/test/causal_jsonl_backend_test.zig` with:

```zig
const conformance = @import("support/causal_backend_conformance.zig");

fn parseJsonLine(row_json: []const u8) !std.json.Parsed(JsonLineRow) {
    return std.json.parseFromSlice(JsonLineRow, std.testing.allocator, row_json, .{ .ignore_unknown_fields = true });
}

test "json lines backend writes stored sanitized conformance events" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    var backend_state = fx.CausalJsonLinesBackendState.init(std.testing.allocator, &output, .{});

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    try std.testing.expectEqual(fx.CausalBackendKind.json_lines, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(u64, 3), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
    try std.testing.expect(std.mem.indexOf(u8, output.items, "raw-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, fx.causal_redaction_marker) != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, fx.causal_truncation_marker) != null);

    var lines = std.mem.tokenizeScalar(u8, output.items, '\n');
    const first_line = lines.next().?;
    const second_line = lines.next().?;
    const third_line = lines.next().?;
    try std.testing.expect(lines.next() == null);

    var first = try parseJsonLine(first_line);
    defer first.deinit();
    var second = try parseJsonLine(second_line);
    defer second.deinit();
    var third = try parseJsonLine(third_line);
    defer third.deinit();

    try std.testing.expectEqual(ids.started, first.value.id);
    try std.testing.expectEqualStrings("run_started", first.value.kind);
    try std.testing.expect(first.value.label.len <= conformance.standard_max_event_string_bytes);
    try std.testing.expectEqual(ids.retained_log, second.value.id);
    try std.testing.expectEqualStrings("log_recorded", second.value.kind);
    try std.testing.expectEqual(ids.completed, third.value.id);
    try std.testing.expectEqualStrings("run_completed", third.value.kind);
}
```

- [ ] **Step 2: Run the backend test red check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: FAIL because `fx.CausalJsonLinesBackendState` does not exist yet.

## Task 4: Backend State Implementation

**Files:**
- Modify: `packages/zigeffect/src/services/causal_jsonl_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add backend state without byte ceiling behavior**

In `packages/zigeffect/src/services/causal_jsonl_backend.zig`, add:

```zig
const causal_backend = @import("causal_backend.zig");

pub const CausalJsonLinesBackendOptions = struct {
    max_bytes: ?usize = null,
};

pub const CausalJsonLinesBackendState = struct {
    allocator: Allocator,
    output: *std.ArrayList(u8),
    max_bytes: ?usize = null,
    written_event_count: u64 = 0,
    failed_event_count: u64 = 0,

    pub fn init(
        allocator: Allocator,
        output: *std.ArrayList(u8),
        options: CausalJsonLinesBackendOptions,
    ) CausalJsonLinesBackendState {
        return .{
            .allocator = allocator,
            .output = output,
            .max_bytes = options.max_bytes,
        };
    }

    pub fn backend(self: *CausalJsonLinesBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .json_lines,
            .state = self,
            .record = recordJsonLinesBackend,
        };
    }

    pub fn writtenEventCount(self: *const CausalJsonLinesBackendState) u64 {
        return self.written_event_count;
    }

    pub fn failedEventCount(self: *const CausalJsonLinesBackendState) u64 {
        return self.failed_event_count;
    }
};

fn recordJsonLinesBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalJsonLinesBackendState = @ptrCast(@alignCast(raw.?));
    const row = try formatCausalJsonLine(state.allocator, event);
    defer state.allocator.free(row);

    try state.output.appendSlice(state.allocator, row);
    state.written_event_count += 1;
}
```

- [ ] **Step 2: Export backend state API**

In `packages/zigeffect/src/zigeffect.zig`, add service exports:

```zig
    pub const CausalJsonLinesBackendOptions = causal_jsonl_backend.CausalJsonLinesBackendOptions;
    pub const CausalJsonLinesBackendState = causal_jsonl_backend.CausalJsonLinesBackendState;
```

Add root-level re-exports:

```zig
pub const CausalJsonLinesBackendOptions = services.CausalJsonLinesBackendOptions;
pub const CausalJsonLinesBackendState = services.CausalJsonLinesBackendState;
```

- [ ] **Step 3: Run backend conformance green check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: PASS for JSONL formatter and backend conformance tests.

- [ ] **Step 4: Commit backend slice**

Run:

```bash
git add packages/zigeffect/src/services/causal_jsonl_backend.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/causal_jsonl_backend_test.zig
git commit -m "feat(zigeffect): add causal jsonl backend"
```

## Task 5: Byte Ceiling Test First And Implementation

**Files:**
- Modify: `packages/zigeffect/test/causal_jsonl_backend_test.zig`
- Modify: `packages/zigeffect/src/services/causal_jsonl_backend.zig`

- [ ] **Step 1: Add failing no-partial-row overflow test**

Add to `packages/zigeffect/test/causal_jsonl_backend_test.zig`:

```zig
test "json lines backend max_bytes fails closed without partial rows" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    var backend_state = fx.CausalJsonLinesBackendState.init(std.testing.allocator, &output, .{ .max_bytes = 1 });

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{
        .kind = .run_started,
        .label = "overflowing-jsonl-row",
    });

    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), output.items.len);
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(id, snapshot.events[0].id);
}
```

- [ ] **Step 2: Run the byte-ceiling red check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: FAIL because `max_bytes` is stored but not enforced.

- [ ] **Step 3: Implement fail-closed byte ceiling**

Update `recordJsonLinesBackend` in `packages/zigeffect/src/services/causal_jsonl_backend.zig`:

```zig
pub const CausalJsonLinesBackendError = error{
    CausalJsonLinesBackendFull,
};

fn recordJsonLinesBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalJsonLinesBackendState = @ptrCast(@alignCast(raw.?));
    const row = try formatCausalJsonLine(state.allocator, event);
    defer state.allocator.free(row);

    if (state.max_bytes) |max_bytes| {
        if (state.output.items.len > max_bytes or row.len > max_bytes - state.output.items.len) {
            state.failed_event_count += 1;
            return error.CausalJsonLinesBackendFull;
        }
    }

    try state.output.appendSlice(state.allocator, row);
    state.written_event_count += 1;
}
```

- [ ] **Step 4: Run byte-ceiling green check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: PASS.

- [ ] **Step 5: Commit byte-ceiling slice**

Run:

```bash
git add packages/zigeffect/src/services/causal_jsonl_backend.zig packages/zigeffect/test/causal_jsonl_backend_test.zig
git commit -m "feat(zigeffect): bound causal jsonl backend output"
```

## Task 6: Build Step And Direct Gate

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Run the direct step red check**

Run:

```bash
cd packages/zigeffect
zig build causal-jsonl-backend
```

Expected: FAIL because the build step is not defined yet.

- [ ] **Step 2: Add the direct JSONL backend build step**

In `packages/zigeffect/build.zig`, after `causal_backend_conformance_step`, add:

```zig
    const causal_jsonl_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_jsonl_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_jsonl_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_jsonl_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-jsonl-backend-tests",
        .root_module = causal_jsonl_backend_test_module,
    });
    const run_causal_jsonl_backend_tests = b.addRunArtifact(causal_jsonl_backend_tests);
    const causal_jsonl_backend_step = b.step("causal-jsonl-backend", "Run causal JSON Lines backend tests");
    causal_jsonl_backend_step.dependOn(&run_causal_jsonl_backend_tests.step);
```

Near the existing package `test_step` dependencies, add:

```zig
    test_step.dependOn(&run_causal_jsonl_backend_tests.step);
```

- [ ] **Step 3: Run direct step green check**

Run:

```bash
cd packages/zigeffect
zig build causal-jsonl-backend
```

Expected: PASS.

- [ ] **Step 4: Commit build gate**

Run:

```bash
git add packages/zigeffect/build.zig
git commit -m "build(zigeffect): add causal jsonl backend gate"
```

## Task 7: Documentation And Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update package README**

Add a short section near the backend adapter guidance:

````markdown
Use `fx.CausalJsonLinesBackendState` when a local or CI harness needs one
schema-tagged causal event per line while the run is being recorded:

```zig
var lines = std.ArrayList(u8).empty;
defer lines.deinit(allocator);

var jsonl_backend = fx.CausalJsonLinesBackendState.init(allocator, &lines, .{
    .max_bytes = 64 * 1024,
});

var store = fx.CausalStore.init(allocator);
store.attachBackend(jsonl_backend.backend());
defer store.deinit();
```

The JSONL backend receives the same stored events as every backend: assigned,
redacted, bounded, and not sampled out. A full row is formatted before it is
appended; when `max_bytes` would be exceeded, no partial row is written and
`backendFailureCount()` reports the failed sink write. Pair JSONL files with the
full causal JSON artifact when agents need retention, sampling, truncation, or
backend metadata.
````

- [ ] **Step 2: Update agent guide**

Add guidance:

```markdown
For incremental analysis, prefer JSONL rows from `CausalJsonLinesBackendState`
when you need to tail or split events. Treat each row as an event fact, not as a
complete store report. If sink failures are nonzero, use the in-memory/full JSON
artifact as the authoritative trace and describe the JSONL stream as incomplete.
```

- [ ] **Step 3: Update agent-observable runtime storage strategy**

Add a paragraph under Storage Strategy:

```markdown
The concrete `json_lines` adapter is now `CausalJsonLinesBackendState`. It
formats `zigeffect.causal.event.v1` rows into a caller-owned byte buffer, with an
optional max-byte ceiling that fails closed before writing partial rows. Local
tools own filesystem persistence and rotation; the runtime service owns event
formatting and backend conformance.
```

- [ ] **Step 4: Update master roadmap**

In M4, record:

````markdown
Progress:

- Delivered `codex/zigeffect-causal-backend-conformance`.
- Delivered `codex/zigeffect-causal-jsonl-backend`.

Next branch:

```text
codex/zigeffect-causal-dot-backend-polish
```
````

- [ ] **Step 5: Commit documentation**

Run:

```bash
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal jsonl backend"
```

## Task 8: Final Verification And Merge

**Files:**
- Verify all changed files.
- Merge branch to `master` after verification.

- [ ] **Step 1: Run direct adapter checks**

Run:

```bash
cd packages/zigeffect
zig build causal-jsonl-backend
zig build causal-backend-conformance
```

Expected: PASS.

- [ ] **Step 2: Run package verification**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
zig build test --summary none
zig build causal-test-matrix
zig build examples
```

Expected: PASS. `zig build test --summary none` may intentionally create causal artifacts for failure fixtures but must exit 0.

- [ ] **Step 3: Run repo verification**

Run:

```bash
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: PASS. Existing live database checks may skip when CockroachDB is unavailable.

- [ ] **Step 4: Inspect status**

Run:

```bash
git status --short --branch
```

Expected: only the unrelated untracked durable workflows roadmap remains outside this branch's committed work.

- [ ] **Step 5: Merge to master**

Run:

```bash
git checkout master
git merge --ff-only codex/zigeffect-causal-jsonl-backend
```

Expected: fast-forward merge.

- [ ] **Step 6: Post-merge verification**

Run:

```bash
cd packages/zigeffect
zig build causal-jsonl-backend
zig build test --summary none
```

Then from repo root:

```bash
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: PASS, with the same allowed live database skips as earlier branches.

## Self-Review

- Spec coverage: The plan covers formatter, backend state, byte-ceiling policy,
  conformance reuse, build gate, docs, roadmap, verification, and merge.
- Type consistency: The plan consistently uses
  `CausalJsonLinesBackendState`, `CausalJsonLinesBackendOptions`,
  `formatCausalJsonLine`, `causal_jsonl_event_schema`, and
  `causal_jsonl_event_schema_version`.
- Scope: This plan implements the JSONL backend slice only. File-owned sinks,
  import/query tools, OpenTelemetry, graph history, and replay remain later M4
  or M5 work.
