# zigeffect Causal DOT Backend Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish causal DOT graph output and add an attachable DOT backend adapter with explicit finish and no-partial-statement byte ceilings.

**Architecture:** Keep `formatCausalDot` as the full-store snapshot formatter, but factor DOT graph formatting into reusable append helpers in `causal.zig`. Add `causal_dot_backend.zig` for a caller-owned-buffer backend that emits graph statements as stored events arrive and closes the graph through `finish()`.

**Tech Stack:** Zig 0.16, `std.ArrayList`, existing `CausalStore` and `CausalBackend`, backend conformance fixtures, Bun repo checks.

---

## File Structure

- Create: `packages/zigeffect/src/services/causal_dot_backend.zig`
  - Owns DOT backend state, backend errors, single-event formatter, byte ceiling, and finish behavior.
- Create: `packages/zigeffect/test/causal_dot_backend_test.zig`
  - Tests polished DOT formatting, backend conformance behavior, finish lifecycle, byte ceilings, and post-finish record failure.
- Modify: `packages/zigeffect/src/services/causal.zig`
  - Adds public DOT append helpers and updates `formatCausalDot` to use the richer graph format.
- Modify: `packages/zigeffect/src/zigeffect.zig`
  - Exports the DOT backend module and public API through `fx`.
- Modify: `packages/zigeffect/test/all_test.zig`
  - Imports the DOT backend tests.
- Modify: `packages/zigeffect/test/services_test.zig`
  - Updates existing DOT expectations to the polished format.
- Modify: `packages/zigeffect/build.zig`
  - Adds direct `zig build causal-dot-backend` step and wires it into the package `test` step.
- Modify: `packages/zigeffect/README.md`
  - Documents DOT backend use and `finish()`.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Guides agents to treat DOT as visual evidence only.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Updates storage strategy with the concrete DOT adapter.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks DOT polish delivered and advances M4 to the next backend branch.

## Task 1: DOT Formatter Test First

**Files:**
- Create: `packages/zigeffect/test/causal_dot_backend_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write the failing full-graph formatter test**

Create `packages/zigeffect/test/causal_dot_backend_test.zig` with:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "formatCausalDot emits graph attributes contextual labels and parent edges" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "readiness \"quoted\"\nnext",
        .type_name = "DotRun",
        .status = "success",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .parent_id = started,
        .scope_id = 3,
        .label = "Config",
        .type_name = "ConfigService",
        .status = "missing",
    });

    const dot = try fx.formatCausalDot(std.testing.allocator, &store);
    defer std.testing.allocator.free(dot);

    try std.testing.expect(std.mem.indexOf(u8, dot, "digraph zigeffect_causal {") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "graph [rankdir=\"LR\", labelloc=\"t\", label=\"zigeffect causal graph\"];") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "node [shape=\"box\", style=\"rounded,filled\", fontname=\"Menlo\", fontsize=\"10\"];") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "edge [fontname=\"Menlo\", fontsize=\"9\", color=\"#64748b\"];") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 [label=\"event 1\\nrun_started\\nreadiness \\\"quoted\\\" next\\nstatus=success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "tooltip=\"run=1 type=DotRun\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_2 [label=\"event 2\\nservice_required\\nConfig\\nstatus=missing\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "tooltip=\"run=1 scope=3 type=ConfigService\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 -> event_2 [label=\"parent\"];") != null);
    try std.testing.expect(std.mem.endsWith(u8, dot, "}\n"));
}
```

Add the test import to `packages/zigeffect/test/all_test.zig` after the JSONL backend import:

```zig
    _ = @import("causal_dot_backend_test.zig");
```

- [ ] **Step 2: Run the formatter red check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: FAIL because current DOT output lacks graph attributes, contextual labels, tooltips, and edge labels.

## Task 2: Polish `formatCausalDot`

**Files:**
- Modify: `packages/zigeffect/src/services/causal.zig`
- Modify: `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Add reusable DOT append helpers**

In `packages/zigeffect/src/services/causal.zig`, replace the old private `appendDotLabel` with helpers equivalent to:

```zig
fn appendDotEscaped(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n', '\r', '\t' => try output.append(allocator, ' '),
            else => try output.append(allocator, byte),
        }
    }
}

fn appendDotString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    try appendDotEscaped(output, allocator, value);
    try output.append(allocator, '"');
}

fn appendDotOptionalU64Tooltip(output: *std.ArrayList(u8), allocator: Allocator, label: []const u8, value: ?u64, wrote: *bool) Allocator.Error!void {
    if (value) |number| {
        if (wrote.*) try output.append(allocator, ' ');
        try output.print(allocator, "{s}={d}", .{ label, number });
        wrote.* = true;
    }
}
```

Add public append helpers:

```zig
pub fn appendCausalDotGraphHeader(output: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try output.appendSlice(allocator, "digraph zigeffect_causal {\n");
    try output.appendSlice(allocator, "  graph [rankdir=\"LR\", labelloc=\"t\", label=\"zigeffect causal graph\"];\n");
    try output.appendSlice(allocator, "  node [shape=\"box\", style=\"rounded,filled\", fontname=\"Menlo\", fontsize=\"10\"];\n");
    try output.appendSlice(allocator, "  edge [fontname=\"Menlo\", fontsize=\"9\", color=\"#64748b\"];\n");
}

pub fn appendCausalDotGraphFooter(output: *std.ArrayList(u8), allocator: Allocator) Allocator.Error!void {
    try output.appendSlice(allocator, "}\n");
}
```

Add event statement formatting:

```zig
fn dotEventFillColor(kind: CausalEventKind) []const u8 {
    const taxonomy = causalEventTaxonomy(kind);
    if (taxonomy.finding_evidence) return "#fff7ed";
    if (taxonomy.sampleable) return "#eef2ff";
    return "#f8fafc";
}

fn dotEventBorderColor(kind: CausalEventKind) []const u8 {
    const taxonomy = causalEventTaxonomy(kind);
    if (taxonomy.finding_evidence) return "#c2410c";
    if (taxonomy.sampleable) return "#4338ca";
    return "#334155";
}

fn appendDotEventLabel(output: *std.ArrayList(u8), allocator: Allocator, event: CausalEvent) Allocator.Error!void {
    try output.append(allocator, '"');
    try output.print(allocator, "event {d}\\n{s}", .{ event.id, @tagName(event.kind) });
    if (event.label.len > 0) {
        try output.appendSlice(allocator, "\\n");
        try appendDotEscaped(output, allocator, event.label);
    }
    if (event.status.len > 0) {
        try output.appendSlice(allocator, "\\nstatus=");
        try appendDotEscaped(output, allocator, event.status);
    }
    try output.append(allocator, '"');
}

fn appendDotEventTooltip(output: *std.ArrayList(u8), allocator: Allocator, event: CausalEvent) Allocator.Error!void {
    try output.append(allocator, '"');
    var wrote = false;
    try appendDotOptionalU64Tooltip(output, allocator, "run", event.run_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "scope", event.scope_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "fiber", event.fiber_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "trace", event.trace_id, &wrote);
    try appendDotOptionalU64Tooltip(output, allocator, "span", event.span_id, &wrote);
    if (event.type_name.len > 0) {
        if (wrote) try output.append(allocator, ' ');
        try output.appendSlice(allocator, "type=");
        try appendDotEscaped(output, allocator, event.type_name);
        wrote = true;
    }
    if (!wrote) try output.appendSlice(allocator, "event");
    try output.append(allocator, '"');
}

pub fn appendCausalDotEvent(output: *std.ArrayList(u8), allocator: Allocator, event: CausalEvent) Allocator.Error!void {
    try output.print(allocator, "  event_{d} [label=", .{event.id});
    try appendDotEventLabel(output, allocator, event);
    try output.appendSlice(allocator, ", tooltip=");
    try appendDotEventTooltip(output, allocator, event);
    try output.print(
        allocator,
        ", fillcolor=\"{s}\", color=\"{s}\"];\n",
        .{ dotEventFillColor(event.kind), dotEventBorderColor(event.kind) },
    );
    if (event.parent_id) |parent_id| {
        try output.print(allocator, "  event_{d} -> event_{d} [label=\"parent\"];\n", .{ parent_id, event.id });
    }
}
```

- [ ] **Step 2: Update `formatCausalDot` to use helpers**

Replace the body with:

```zig
pub fn formatCausalDot(allocator: Allocator, store: *const CausalStore) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try appendCausalDotGraphHeader(&output, allocator);
    for (store.events.items) |event| {
        try appendCausalDotEvent(&output, allocator, event);
    }
    try appendCausalDotGraphFooter(&output, allocator);

    return output.toOwnedSlice(allocator);
}
```

- [ ] **Step 3: Update existing service DOT expectations**

In `packages/zigeffect/test/services_test.zig`, update the DOT assertions in
`causal json and dot exports are deterministic and redacted`:

```zig
    try std.testing.expect(std.mem.indexOf(u8, dot, "graph [rankdir=\"LR\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 [label=\"event 1\\nrun_started\\nreadiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 -> event_2 [label=\"parent\"]") != null);
```

Keep the existing truncation test expectations that check `<truncated>` is
present and `too-long` is absent.

- [ ] **Step 4: Run formatter green check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: PASS.

- [ ] **Step 5: Commit formatter polish**

Run:

```bash
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/test/services_test.zig packages/zigeffect/test/causal_dot_backend_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): polish causal dot graph output"
```

## Task 3: DOT Backend Test First

**Files:**
- Modify: `packages/zigeffect/test/causal_dot_backend_test.zig`

- [ ] **Step 1: Add failing DOT backend tests**

Extend `packages/zigeffect/test/causal_dot_backend_test.zig`:

```zig
const conformance = @import("support/causal_backend_conformance.zig");

test "dot backend writes stored sanitized conformance events and finishes graph" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    var backend_state = fx.CausalDotBackendState.init(std.testing.allocator, &output, .{});

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);
    try backend_state.finish();
    try backend_state.finish();

    try std.testing.expectEqual(fx.CausalBackendKind.dot, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(u64, 3), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedWriteCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
    try std.testing.expect(backend_state.isFinished());
    try std.testing.expect(std.mem.indexOf(u8, output.items, "digraph zigeffect_causal {") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "raw-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, fx.causal_redaction_marker) != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, fx.causal_truncation_marker) != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "event_1 [label=\"event 1\\nrun_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "event_3 [label=\"event 3\\nlog_recorded") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "event_4 [label=\"event 4\\nrun_completed") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "event_1 -> event_3 [label=\"parent\"]") != null);
    try std.testing.expect(std.mem.endsWith(u8, output.items, "}\n"));
}
```

Add a single-event formatter test:

```zig
test "formatCausalDotEvent emits one complete event statement group" {
    const dot = try fx.formatCausalDotEvent(std.testing.allocator, .{
        .id = 9,
        .kind = .span_recorded,
        .run_id = 1,
        .parent_id = 4,
        .trace_id = 7,
        .span_id = 8,
        .label = "span\nline",
        .status = "ok",
    });
    defer std.testing.allocator.free(dot);

    try std.testing.expect(std.mem.indexOf(u8, dot, "event_9 [label=\"event 9\\nspan_recorded\\nspan line\\nstatus=ok\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "tooltip=\"run=1 trace=7 span=8\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_4 -> event_9 [label=\"parent\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "\nline") == null);
}
```

- [ ] **Step 2: Run backend red check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: FAIL because `fx.CausalDotBackendState` and
`fx.formatCausalDotEvent` do not exist yet.

## Task 4: DOT Backend Implementation

**Files:**
- Create: `packages/zigeffect/src/services/causal_dot_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add DOT backend module without byte ceiling**

Create `packages/zigeffect/src/services/causal_dot_backend.zig`:

```zig
const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;

pub const CausalDotBackendOptions = struct {
    max_bytes: ?usize = null,
    include_graph_header: bool = true,
};

pub const CausalDotBackendError = error{
    CausalDotBackendFull,
    CausalDotBackendFinished,
};

pub const CausalDotBackendState = struct {
    allocator: Allocator,
    output: *std.ArrayList(u8),
    max_bytes: ?usize = null,
    include_graph_header: bool = true,
    opened: bool = false,
    finished: bool = false,
    written_event_count: u64 = 0,
    failed_write_count: u64 = 0,

    pub fn init(allocator: Allocator, output: *std.ArrayList(u8), options: CausalDotBackendOptions) CausalDotBackendState {
        return .{
            .allocator = allocator,
            .output = output,
            .max_bytes = options.max_bytes,
            .include_graph_header = options.include_graph_header,
        };
    }

    pub fn backend(self: *CausalDotBackendState) causal_backend.CausalBackend {
        return .{ .kind = .dot, .state = self, .record = recordDotBackend };
    }

    pub fn finish(self: *CausalDotBackendState) anyerror!void {
        if (self.finished) return;
        if (self.include_graph_header and !self.opened) {
            var header = std.ArrayList(u8).empty;
            defer header.deinit(self.allocator);
            try causal.appendCausalDotGraphHeader(&header, self.allocator);
            try self.appendFragment(header.items);
            self.opened = true;
        }
        if (self.include_graph_header) {
            var footer = std.ArrayList(u8).empty;
            defer footer.deinit(self.allocator);
            try causal.appendCausalDotGraphFooter(&footer, self.allocator);
            try self.appendFragment(footer.items);
        }
        self.finished = true;
    }

    pub fn writtenEventCount(self: *const CausalDotBackendState) u64 {
        return self.written_event_count;
    }

    pub fn failedWriteCount(self: *const CausalDotBackendState) u64 {
        return self.failed_write_count;
    }

    pub fn isFinished(self: *const CausalDotBackendState) bool {
        return self.finished;
    }

    fn appendFragment(self: *CausalDotBackendState, fragment: []const u8) anyerror!void {
        try self.output.appendSlice(self.allocator, fragment);
    }
};

pub fn formatCausalDotEvent(allocator: Allocator, event: causal.CausalEvent) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try causal.appendCausalDotEvent(&output, allocator, event);
    return output.toOwnedSlice(allocator);
}

fn recordDotBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalDotBackendState = @ptrCast(@alignCast(raw.?));
    if (state.finished) {
        state.failed_write_count += 1;
        return error.CausalDotBackendFinished;
    }
    if (state.include_graph_header and !state.opened) {
        var header = std.ArrayList(u8).empty;
        defer header.deinit(state.allocator);
        try causal.appendCausalDotGraphHeader(&header, state.allocator);
        try state.appendFragment(header.items);
        state.opened = true;
    }
    const fragment = try formatCausalDotEvent(state.allocator, event);
    defer state.allocator.free(fragment);
    try state.appendFragment(fragment);
    state.written_event_count += 1;
}
```

- [ ] **Step 2: Export DOT backend API**

In `packages/zigeffect/src/zigeffect.zig`, add the module:

```zig
    pub const causal_dot_backend = @import("services/causal_dot_backend.zig");
```

Add service exports:

```zig
    pub const CausalDotBackendOptions = causal_dot_backend.CausalDotBackendOptions;
    pub const CausalDotBackendState = causal_dot_backend.CausalDotBackendState;
    pub const formatCausalDotEvent = causal_dot_backend.formatCausalDotEvent;
```

Add root-level re-exports:

```zig
pub const CausalDotBackendOptions = services.causal_dot_backend.CausalDotBackendOptions;
pub const CausalDotBackendState = services.causal_dot_backend.CausalDotBackendState;
pub const formatCausalDotEvent = services.causal_dot_backend.formatCausalDotEvent;
```

- [ ] **Step 3: Run backend green check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: PASS.

- [ ] **Step 4: Commit backend slice**

Run:

```bash
git add packages/zigeffect/src/services/causal_dot_backend.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/causal_dot_backend_test.zig
git commit -m "feat(zigeffect): add causal dot backend"
```

## Task 5: Byte Ceiling And Post-Finish Failures

**Files:**
- Modify: `packages/zigeffect/test/causal_dot_backend_test.zig`
- Modify: `packages/zigeffect/src/services/causal_dot_backend.zig`

- [ ] **Step 1: Add failing byte ceiling and post-finish tests**

Add:

```zig
test "dot backend max_bytes fails closed without partial statements" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    var backend_state = fx.CausalDotBackendState.init(std.testing.allocator, &output, .{ .max_bytes = 1 });

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{ .kind = .run_started, .label = "overflowing-dot-row" });

    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), output.items.len);
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedWriteCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());
}

test "dot backend records after finish as sink failures only" {
    var output = std.ArrayList(u8).empty;
    defer output.deinit(std.testing.allocator);

    var backend_state = fx.CausalDotBackendState.init(std.testing.allocator, &output, .{});

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const first = try store.record(.{ .kind = .run_started, .label = "finished" });
    try backend_state.finish();
    const second = try store.record(.{ .kind = .run_completed, .parent_id = first, .status = "success" });

    try std.testing.expectEqual(@as(u64, 2), second);
    try std.testing.expectEqual(@as(u64, 1), backend_state.writtenEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedWriteCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
}
```

- [ ] **Step 2: Run red check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: FAIL because `max_bytes` is not enforced.

- [ ] **Step 3: Enforce no-partial-fragment ceiling and count allocation failures**

Update `appendFragment`:

```zig
    fn appendFragment(self: *CausalDotBackendState, fragment: []const u8) anyerror!void {
        if (self.max_bytes) |max_bytes| {
            if (self.output.items.len > max_bytes or fragment.len > max_bytes - self.output.items.len) {
                self.failed_write_count += 1;
                return error.CausalDotBackendFull;
            }
        }
        self.output.appendSlice(self.allocator, fragment) catch |err| {
            self.failed_write_count += 1;
            return err;
        };
    }
```

Wrap record-time formatter/header failures so `failed_write_count` increments:

```zig
const fragment = formatCausalDotEvent(state.allocator, event) catch |err| {
    state.failed_write_count += 1;
    return err;
};
```

- [ ] **Step 4: Run green check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: PASS.

- [ ] **Step 5: Commit byte-ceiling slice**

Run:

```bash
git add packages/zigeffect/src/services/causal_dot_backend.zig packages/zigeffect/test/causal_dot_backend_test.zig
git commit -m "feat(zigeffect): bound causal dot backend output"
```

## Task 6: Build Gate

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Run direct step red check**

Run:

```bash
cd packages/zigeffect
zig build causal-dot-backend
```

Expected: FAIL because the step is not defined.

- [ ] **Step 2: Add direct build step**

In `packages/zigeffect/build.zig`, after the JSONL backend step, add:

```zig
    const causal_dot_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_dot_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_dot_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_dot_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-dot-backend-tests",
        .root_module = causal_dot_backend_test_module,
    });
    const run_causal_dot_backend_tests = b.addRunArtifact(causal_dot_backend_tests);
    const causal_dot_backend_step = b.step("causal-dot-backend", "Run causal DOT backend tests");
    causal_dot_backend_step.dependOn(&run_causal_dot_backend_tests.step);
```

Add to the package `test_step` dependencies:

```zig
    test_step.dependOn(&run_causal_dot_backend_tests.step);
```

- [ ] **Step 3: Run direct step green check**

Run:

```bash
cd packages/zigeffect
zig build causal-dot-backend
```

Expected: PASS.

- [ ] **Step 4: Commit build gate**

Run:

```bash
git add packages/zigeffect/build.zig
git commit -m "build(zigeffect): add causal dot backend gate"
```

## Task 7: Documentation And Roadmap

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update docs**

Add guidance that says:

```markdown
Use `fx.CausalDotBackendState` when a local or CI harness wants graph output as
events are recorded. DOT backend output is an artifact builder: call
`finish()` before writing the buffer to a `.dot` file. Treat DOT as visual
evidence for humans and graph tools; use the full causal JSON artifact for
agent queries, schema metadata, retention, sampling, and truncation summaries.
Run `zig build causal-dot-backend` for the focused adapter gate.
```

- [ ] **Step 2: Update roadmap**

Update M4 ledger:

```markdown
| M4 Durable backends | in progress | backend boundary, conformance suite, JSONL sink, and polished DOT backend exist | design OpenTelemetry backend |
```

Update immediate branch queue:

```markdown
1. `codex/zigeffect-causal-otel-backend`
   - Build the first telemetry bridge behind the conformance contract.
```

- [ ] **Step 3: Commit docs**

Run:

```bash
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal dot backend"
```

## Task 8: Final Verification And Merge

**Files:**
- Verify all changed files.
- Merge branch to `master` after verification.

- [ ] **Step 1: Run focused adapter checks**

Run:

```bash
cd packages/zigeffect
zig build causal-dot-backend
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

Expected: PASS.

- [ ] **Step 3: Run repo verification**

Run:

```bash
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: PASS. Existing live database checks may skip when CockroachDB is unavailable.

- [ ] **Step 4: Merge and post-merge verify**

Run:

```bash
git checkout master
git merge --ff-only codex/zigeffect-causal-dot-backend-polish
```

Then run:

```bash
cd packages/zigeffect
zig build causal-dot-backend
zig build test --summary none
```

From repo root:

```bash
bun run check
bun run zig:test
git diff --check HEAD
git status --short --branch
```

Expected: PASS, with only the unrelated untracked durable workflows roadmap outside committed work.

## Self-Review

- Spec coverage: The plan covers DOT graph output polish, reusable append
  helpers, backend state, finish lifecycle, no-partial byte ceiling, direct
  build gate, docs, roadmap, verification, and merge.
- Type consistency: The plan consistently uses `CausalDotBackendState`,
  `CausalDotBackendOptions`, `formatCausalDotEvent`, `failedWriteCount`, and
  `zig build causal-dot-backend`.
- Scope: This plan does not add rendering, file-owned adapters, graph query,
  workbench UI, OpenTelemetry, or durable database history.
