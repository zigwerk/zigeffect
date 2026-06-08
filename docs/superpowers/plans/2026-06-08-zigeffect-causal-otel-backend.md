# zigeffect Causal OpenTelemetry Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dependency-free OpenTelemetry-shaped causal backend that maps stored zigeffect causal events into typed span-event or log-record records.

**Architecture:** Keep `CausalStore` authoritative and add `causal_otel_backend.zig` as an adapter module behind `CausalBackendKind.opentelemetry`. The adapter owns cloned `CausalOtelRecord` values with typed causal attributes, OTel-style trace/span hex helpers, and a max-record ceiling that fails closed without perturbing the store.

**Tech Stack:** Zig 0.16, `std.ArrayList`, existing `CausalStore` and `CausalBackend`, backend conformance fixtures, Bun repo checks.

---

## File Structure

- Create: `packages/zigeffect/src/services/causal_otel_backend.zig`
  - Owns OTel signal classification, trace/span hex formatting, typed attribute cloning/deinit, event-to-record mapping, backend state, and max-record failure behavior.
- Create: `packages/zigeffect/test/causal_otel_backend_test.zig`
  - Tests hex helpers, mapper classification, typed attributes, backend conformance behavior, redaction/truncation propagation, and max-record failure.
- Modify: `packages/zigeffect/src/zigeffect.zig`
  - Exports the OTel backend module and public API through `fx`.
- Modify: `packages/zigeffect/test/all_test.zig`
  - Imports the OTel backend tests into package tests.
- Modify: `packages/zigeffect/build.zig`
  - Adds direct `zig build causal-otel-backend` step and wires it into the package `test` step.
- Modify: `packages/zigeffect/README.md`
  - Documents OTel-shaped backend use and focused gate.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Guides agents to treat OTel records as best-effort adapter output.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  - Updates backend adapter strategy with the concrete OTel bridge.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks OTel backend delivered and advances M4 to the graph-history backend.

## Task 1: OTel Backend Test First

**Files:**
- Create: `packages/zigeffect/test/causal_otel_backend_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write the failing OTel tests**

Create `packages/zigeffect/test/causal_otel_backend_test.zig` with:

```zig
const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

const AttributeExpectationError = error{
    MissingAttribute,
    WrongAttributeKind,
};

fn expectStringAttribute(record: *const fx.CausalOtelRecord, key: []const u8, expected: []const u8) !void {
    const value = record.attribute(key) orelse return AttributeExpectationError.MissingAttribute;
    switch (value) {
        .string => |actual| try std.testing.expectEqualStrings(expected, actual),
        else => return AttributeExpectationError.WrongAttributeKind,
    }
}

fn expectU64Attribute(record: *const fx.CausalOtelRecord, key: []const u8, expected: u64) !void {
    const value = record.attribute(key) orelse return AttributeExpectationError.MissingAttribute;
    switch (value) {
        .u64 => |actual| try std.testing.expectEqual(expected, actual),
        else => return AttributeExpectationError.WrongAttributeKind,
    }
}

fn recordsContainString(records: []const fx.CausalOtelRecord, needle: []const u8) bool {
    for (records) |record| {
        if (std.mem.indexOf(u8, record.name, needle) != null) return true;
        for (record.attributes) |attribute| {
            if (std.mem.indexOf(u8, attribute.key, needle) != null) return true;
            switch (attribute.value) {
                .string => |value| if (std.mem.indexOf(u8, value, needle) != null) return true,
                else => {},
            }
        }
    }
    return false;
}

test "causal otel id helpers emit fixed lowercase hex" {
    const trace_id = fx.formatCausalOtelTraceId(0x2a);
    const span_id = fx.formatCausalOtelSpanId(0x2a);

    try std.testing.expectEqual(@as(usize, 32), trace_id.len);
    try std.testing.expectEqual(@as(usize, 16), span_id.len);
    try std.testing.expectEqualStrings("0000000000000000000000000000002a", trace_id[0..]);
    try std.testing.expectEqualStrings("000000000000002a", span_id[0..]);
}

test "mapCausalEventToOtelRecord maps complete trace context to span event" {
    var record = try fx.mapCausalEventToOtelRecord(std.testing.allocator, .{
        .id = 42,
        .kind = .effect_started,
        .run_id = 7,
        .parent_id = 9,
        .fiber_id = 10,
        .scope_id = 11,
        .trace_id = 1,
        .span_id = 2,
        .label = "load-vessel",
        .type_name = "VesselEffect",
        .status = "running",
        .redacted_detail = "safe detail",
    });
    defer record.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.CausalOtelSignal.span_event, record.signal);
    try std.testing.expectEqualStrings("zigeffect.causal.effect_started", record.name);
    try std.testing.expectEqual(@as(?u64, 1), record.trace_id);
    try std.testing.expectEqual(@as(?u64, 2), record.span_id);
    try std.testing.expectEqualStrings("00000000000000000000000000000001", record.trace_id_hex.?[0..]);
    try std.testing.expectEqualStrings("0000000000000002", record.span_id_hex.?[0..]);
    try expectStringAttribute(&record, "zigeffect.causal.schema", fx.causal_otel_record_schema);
    try expectU64Attribute(&record, "zigeffect.causal.schema_version", fx.causal_otel_record_schema_version);
    try expectU64Attribute(&record, "zigeffect.causal.event_taxonomy_version", fx.causal_event_taxonomy_version);
    try expectU64Attribute(&record, "zigeffect.causal.event_id", 42);
    try expectStringAttribute(&record, "zigeffect.causal.kind", "effect_started");
    try expectStringAttribute(&record, "zigeffect.causal.signal", "span_event");
    try expectU64Attribute(&record, "zigeffect.causal.run_id", 7);
    try expectU64Attribute(&record, "zigeffect.causal.parent_event_id", 9);
    try expectU64Attribute(&record, "zigeffect.causal.fiber_id", 10);
    try expectU64Attribute(&record, "zigeffect.causal.scope_id", 11);
    try expectU64Attribute(&record, "zigeffect.causal.trace_id", 1);
    try expectU64Attribute(&record, "zigeffect.causal.span_id", 2);
    try expectStringAttribute(&record, "zigeffect.causal.label", "load-vessel");
    try expectStringAttribute(&record, "zigeffect.causal.type_name", "VesselEffect");
    try expectStringAttribute(&record, "zigeffect.causal.status", "running");
    try expectStringAttribute(&record, "zigeffect.causal.redacted_detail", "safe detail");
}

test "mapCausalEventToOtelRecord maps missing trace context to log record" {
    var record = try fx.mapCausalEventToOtelRecord(std.testing.allocator, .{
        .id = 5,
        .kind = .log_recorded,
        .label = "startup-log",
    });
    defer record.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.CausalOtelSignal.log_record, record.signal);
    try std.testing.expectEqualStrings("zigeffect.causal.log_recorded", record.name);
    try std.testing.expectEqual(@as(?u64, null), record.trace_id);
    try std.testing.expectEqual(@as(?u64, null), record.span_id);
    try std.testing.expect(record.trace_id_hex == null);
    try std.testing.expect(record.span_id_hex == null);
    try expectU64Attribute(&record, "zigeffect.causal.event_id", 5);
    try expectStringAttribute(&record, "zigeffect.causal.kind", "log_recorded");
    try expectStringAttribute(&record, "zigeffect.causal.signal", "log_record");
    try expectStringAttribute(&record, "zigeffect.causal.label", "startup-log");
}

test "otel backend records stored sanitized conformance events" {
    var backend_state = fx.CausalOtelBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    const records = backend_state.recordedRecords();
    try std.testing.expectEqual(fx.CausalBackendKind.opentelemetry, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(usize, 3), records.len);
    try std.testing.expectEqual(@as(u64, 3), backend_state.writtenRecordCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedRecordCount());
    try std.testing.expectEqual(@as(u64, 0), store.backendFailureCount());
    try std.testing.expectEqual(ids.started, records[0].attribute("zigeffect.causal.event_id").?.u64);
    try std.testing.expectEqual(ids.retained_log, records[1].attribute("zigeffect.causal.event_id").?.u64);
    try std.testing.expectEqual(ids.completed, records[2].attribute("zigeffect.causal.event_id").?.u64);
    try std.testing.expectEqual(fx.CausalOtelSignal.log_record, records[0].signal);
    try std.testing.expect(recordsContainString(records, "raw-secret") == false);
    try std.testing.expect(recordsContainString(records, fx.causal_redaction_marker));
    try std.testing.expect(recordsContainString(records, fx.causal_truncation_marker));
}

test "otel backend max_records fails closed without partial records" {
    var backend_state = fx.CausalOtelBackendState.init(std.testing.allocator, .{ .max_records = 0 });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{
        .kind = .run_started,
        .label = "overflowing-otel-record",
    });

    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), backend_state.recordedRecords().len);
    try std.testing.expectEqual(@as(u64, 0), backend_state.writtenRecordCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedRecordCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 1), snapshot.events.len);
    try std.testing.expectEqual(id, snapshot.events[0].id);
}
```

Add the test import in `packages/zigeffect/test/all_test.zig` after the DOT
backend import:

```zig
    _ = @import("causal_otel_backend_test.zig");
```

- [ ] **Step 2: Run the red check**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
```

Expected: FAIL because `fx.CausalOtelRecord`,
`fx.CausalOtelBackendState`, and related exports do not exist yet.

- [ ] **Step 3: Commit the red tests**

```bash
git add packages/zigeffect/test/causal_otel_backend_test.zig packages/zigeffect/test/all_test.zig
git commit -m "test(zigeffect): specify causal otel backend"
```

## Task 2: Implement The OTel Backend

**Files:**
- Create: `packages/zigeffect/src/services/causal_otel_backend.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the OTel backend module**

Create `packages/zigeffect/src/services/causal_otel_backend.zig` with:

```zig
const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const causal_otel_record_schema = "zigeffect.causal.otel_record.v1";
pub const causal_otel_record_schema_version: u32 = 1;

pub const CausalOtelSignal = enum {
    span_event,
    log_record,
};

pub const CausalOtelAttributeValue = union(enum) {
    string: []const u8,
    u64: u64,
    bool: bool,
};

pub const CausalOtelAttribute = struct {
    key: []const u8,
    value: CausalOtelAttributeValue,
};

pub const CausalOtelRecord = struct {
    signal: CausalOtelSignal,
    name: []const u8,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    trace_id_hex: ?[32]u8 = null,
    span_id_hex: ?[16]u8 = null,
    attributes: []CausalOtelAttribute = &.{},

    pub fn deinit(self: *CausalOtelRecord, allocator: Allocator) void {
        if (self.name.len > 0) allocator.free(self.name);
        for (self.attributes) |attribute| {
            if (attribute.key.len > 0) allocator.free(attribute.key);
            switch (attribute.value) {
                .string => |value| if (value.len > 0) allocator.free(value),
                else => {},
            }
        }
        if (self.attributes.len > 0) allocator.free(self.attributes);
        self.* = .{
            .signal = .log_record,
            .name = "",
        };
    }

    pub fn attribute(self: *const CausalOtelRecord, key: []const u8) ?CausalOtelAttributeValue {
        for (self.attributes) |candidate| {
            if (std.mem.eql(u8, candidate.key, key)) return candidate.value;
        }
        return null;
    }
};

pub const CausalOtelBackendOptions = struct {
    max_records: ?usize = null,
};

pub const CausalOtelBackendError = error{
    CausalOtelBackendFull,
};

pub const CausalOtelBackendState = struct {
    allocator: Allocator,
    records: std.ArrayList(CausalOtelRecord) = .empty,
    max_records: ?usize = null,
    written_record_count: u64 = 0,
    failed_record_count: u64 = 0,

    pub fn init(allocator: Allocator, options: CausalOtelBackendOptions) CausalOtelBackendState {
        return .{
            .allocator = allocator,
            .max_records = options.max_records,
        };
    }

    pub fn deinit(self: *CausalOtelBackendState) void {
        for (self.records.items) |*record| {
            record.deinit(self.allocator);
        }
        self.records.deinit(self.allocator);
    }

    pub fn backend(self: *CausalOtelBackendState) causal_backend.CausalBackend {
        return .{
            .kind = .opentelemetry,
            .state = self,
            .record = recordOtelBackend,
        };
    }

    pub fn recordedRecords(self: *const CausalOtelBackendState) []const CausalOtelRecord {
        return self.records.items;
    }

    pub fn writtenRecordCount(self: *const CausalOtelBackendState) u64 {
        return self.written_record_count;
    }

    pub fn failedRecordCount(self: *const CausalOtelBackendState) u64 {
        return self.failed_record_count;
    }
};

pub fn classifyCausalOtelSignal(event: causal.CausalEvent) CausalOtelSignal {
    if (event.trace_id != null and event.span_id != null) return .span_event;
    return .log_record;
}

pub fn formatCausalOtelTraceId(trace_id: u64) [32]u8 {
    var output: [32]u8 = undefined;
    @memcpy(output[0..16], "0000000000000000");
    _ = std.fmt.bufPrint(output[16..], "{x:0>16}", .{trace_id}) catch unreachable;
    return output;
}

pub fn formatCausalOtelSpanId(span_id: u64) [16]u8 {
    var output: [16]u8 = undefined;
    _ = std.fmt.bufPrint(output[0..], "{x:0>16}", .{span_id}) catch unreachable;
    return output;
}

fn cloneString(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn appendStringAttribute(
    allocator: Allocator,
    attributes: *std.ArrayList(CausalOtelAttribute),
    key: []const u8,
    value: []const u8,
) Allocator.Error!void {
    const owned_key = try cloneString(allocator, key);
    errdefer if (owned_key.len > 0) allocator.free(owned_key);
    const owned_value = try cloneString(allocator, value);
    errdefer if (owned_value.len > 0) allocator.free(owned_value);
    try attributes.append(allocator, .{
        .key = owned_key,
        .value = .{ .string = owned_value },
    });
}

fn appendU64Attribute(
    allocator: Allocator,
    attributes: *std.ArrayList(CausalOtelAttribute),
    key: []const u8,
    value: u64,
) Allocator.Error!void {
    const owned_key = try cloneString(allocator, key);
    errdefer if (owned_key.len > 0) allocator.free(owned_key);
    try attributes.append(allocator, .{
        .key = owned_key,
        .value = .{ .u64 = value },
    });
}

fn appendOptionalU64Attribute(
    allocator: Allocator,
    attributes: *std.ArrayList(CausalOtelAttribute),
    key: []const u8,
    value: ?u64,
) Allocator.Error!void {
    if (value) |number| {
        try appendU64Attribute(allocator, attributes, key, number);
    }
}

fn appendOptionalStringAttribute(
    allocator: Allocator,
    attributes: *std.ArrayList(CausalOtelAttribute),
    key: []const u8,
    value: []const u8,
) Allocator.Error!void {
    if (value.len > 0) {
        try appendStringAttribute(allocator, attributes, key, value);
    }
}

pub fn mapCausalEventToOtelRecord(allocator: Allocator, event: causal.CausalEvent) Allocator.Error!CausalOtelRecord {
    const signal = classifyCausalOtelSignal(event);
    var attributes = std.ArrayList(CausalOtelAttribute).empty;
    errdefer {
        for (attributes.items) |attribute| {
            if (attribute.key.len > 0) allocator.free(attribute.key);
            switch (attribute.value) {
                .string => |value| if (value.len > 0) allocator.free(value),
                else => {},
            }
        }
        attributes.deinit(allocator);
    }

    const name = try std.fmt.allocPrint(allocator, "zigeffect.causal.{s}", .{@tagName(event.kind)});
    errdefer allocator.free(name);

    try appendStringAttribute(allocator, &attributes, "zigeffect.causal.schema", causal_otel_record_schema);
    try appendU64Attribute(allocator, &attributes, "zigeffect.causal.schema_version", causal_otel_record_schema_version);
    try appendU64Attribute(allocator, &attributes, "zigeffect.causal.event_taxonomy_version", causal.causal_event_taxonomy_version);
    try appendU64Attribute(allocator, &attributes, "zigeffect.causal.event_id", event.id);
    try appendStringAttribute(allocator, &attributes, "zigeffect.causal.kind", @tagName(event.kind));
    try appendStringAttribute(allocator, &attributes, "zigeffect.causal.signal", @tagName(signal));
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.run_id", event.run_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.parent_event_id", event.parent_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.fiber_id", event.fiber_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.scope_id", event.scope_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.trace_id", event.trace_id);
    try appendOptionalU64Attribute(allocator, &attributes, "zigeffect.causal.span_id", event.span_id);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.label", event.label);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.type_name", event.type_name);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.status", event.status);
    try appendOptionalStringAttribute(allocator, &attributes, "zigeffect.causal.redacted_detail", event.redacted_detail);

    return .{
        .signal = signal,
        .name = name,
        .trace_id = event.trace_id,
        .span_id = event.span_id,
        .trace_id_hex = if (event.trace_id) |trace_id| formatCausalOtelTraceId(trace_id) else null,
        .span_id_hex = if (event.span_id) |span_id| formatCausalOtelSpanId(span_id) else null,
        .attributes = try attributes.toOwnedSlice(allocator),
    };
}

fn recordOtelBackend(raw: ?*anyopaque, event: causal.CausalEvent) anyerror!void {
    const state: *CausalOtelBackendState = @ptrCast(@alignCast(raw.?));
    if (state.max_records) |max_records| {
        if (state.records.items.len >= max_records) {
            state.failed_record_count += 1;
            return error.CausalOtelBackendFull;
        }
    }

    var record = mapCausalEventToOtelRecord(state.allocator, event) catch |err| {
        state.failed_record_count += 1;
        return err;
    };
    errdefer record.deinit(state.allocator);

    state.records.append(state.allocator, record) catch |err| {
        state.failed_record_count += 1;
        return err;
    };
    state.written_record_count += 1;
}
```

- [ ] **Step 2: Export the OTel backend**

In `packages/zigeffect/src/zigeffect.zig`, add the service import beside the
JSONL and DOT imports:

```zig
    pub const causal_otel_backend = @import("services/causal_otel_backend.zig");
```

Add service exports beside the other causal backend exports:

```zig
    pub const CausalOtelSignal = causal_otel_backend.CausalOtelSignal;
    pub const CausalOtelAttributeValue = causal_otel_backend.CausalOtelAttributeValue;
    pub const CausalOtelAttribute = causal_otel_backend.CausalOtelAttribute;
    pub const CausalOtelRecord = causal_otel_backend.CausalOtelRecord;
    pub const CausalOtelBackendOptions = causal_otel_backend.CausalOtelBackendOptions;
    pub const CausalOtelBackendState = causal_otel_backend.CausalOtelBackendState;
    pub const causal_otel_record_schema = causal_otel_backend.causal_otel_record_schema;
    pub const causal_otel_record_schema_version = causal_otel_backend.causal_otel_record_schema_version;
    pub const classifyCausalOtelSignal = causal_otel_backend.classifyCausalOtelSignal;
    pub const formatCausalOtelTraceId = causal_otel_backend.formatCausalOtelTraceId;
    pub const formatCausalOtelSpanId = causal_otel_backend.formatCausalOtelSpanId;
    pub const mapCausalEventToOtelRecord = causal_otel_backend.mapCausalEventToOtelRecord;
```

- [ ] **Step 3: Add the focused build gate**

In `packages/zigeffect/build.zig`, add a test module after the DOT backend test
step:

```zig
    const causal_otel_backend_test_module = b.createModule(.{
        .root_source_file = b.path("test/causal_otel_backend_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_otel_backend_test_module.addImport("zigeffect", zigeffect);

    const causal_otel_backend_tests = b.addTest(.{
        .name = "zigeffect-causal-otel-backend-tests",
        .root_module = causal_otel_backend_test_module,
    });
    const run_causal_otel_backend_tests = b.addRunArtifact(causal_otel_backend_tests);
    const causal_otel_backend_step = b.step("causal-otel-backend", "Run causal OpenTelemetry backend tests");
    causal_otel_backend_step.dependOn(&run_causal_otel_backend_tests.step);
```

Add the focused tests to the package `test` dependencies:

```zig
    test_step.dependOn(&run_causal_otel_backend_tests.step);
```

- [ ] **Step 4: Run the focused green check**

Run:

```bash
cd packages/zigeffect
zig build causal-otel-backend
```

Expected: PASS.

- [ ] **Step 5: Run local package checks**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
zig build test --summary none
```

Expected: both PASS.

- [ ] **Step 6: Commit the implementation**

```bash
git add packages/zigeffect/src/services/causal_otel_backend.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal otel backend"
```

## Task 3: Document The OTel Backend

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update README backend guidance**

In `packages/zigeffect/README.md`, after the DOT backend paragraph, add:

```markdown
Use `fx.CausalOtelBackendState` when a harness wants OpenTelemetry-shaped
records while events are recorded. The first OTel bridge is dependency-free and
exporter-neutral: complete local `trace_id` plus `span_id` context maps to a
`span_event`, and missing or incomplete span context maps to a `log_record`.
Records preserve `zigeffect.causal.*` typed attributes so later SDK or OTLP
exporters can forward effect-native runtime facts without reparsing artifacts.
Run `zig build causal-otel-backend` for the focused adapter gate.
```

- [ ] **Step 2: Update the agent guide**

In `packages/zigeffect/docs/agent-guide.md`, after the DOT backend guidance,
add:

```markdown
Use `CausalOtelBackendState` when you need to inspect the runtime-to-OTel
mapping directly. Treat records as best-effort adapter sink output, not as the
source of truth. A record with complete `trace_id` and `span_id` is a
`span_event`; missing or incomplete context is a `log_record`. Cite the full
causal JSON artifact for retention, sampling, truncation, and backend-failure
metadata. Run `zig build causal-otel-backend` for the focused adapter gate.
```

- [ ] **Step 3: Update the agent-observable runtime doc**

In `packages/zigeffect/docs/agent-observable-runtime.md`, replace the OTel
backend bullet and add a concrete adapter paragraph after the DOT adapter
paragraph:

```markdown
- `opentelemetry`: dependency-free span-event/log-record bridge for production
  span and event ecosystems
```

```markdown
The concrete `opentelemetry` adapter is `CausalOtelBackendState`. It maps stored
causal events into typed `CausalOtelRecord` values with `span_event` or
`log_record` signal classification, OTel-style trace/span hex strings where
local ids exist, and `zigeffect.causal.*` attributes for runtime facts. This is
an exporter-neutral bridge; OTLP serialization, SDK integration, resources, and
collector delivery remain future adapter work. Its focused gate is
`zig build causal-otel-backend`.
```

- [ ] **Step 4: Update the master roadmap ledger**

In
`docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`,
update the current baseline list to include:

```markdown
- `CausalJsonLinesBackendState`, `CausalDotBackendState`, and
  `CausalOtelBackendState` concrete causal backend adapters.
```

Update M4 recommended branch status from "next OTel backend" to "next graph
history backend" by keeping the branch list and adding:

````markdown
Current branch:

```text
codex/zigeffect-causal-graph-history-backend
```
````

- [ ] **Step 5: Run docs diff check**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 6: Commit docs**

```bash
git add packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal otel backend"
```

## Task 4: Final Verification And Merge

**Files:**
- Verify branch state only.

- [ ] **Step 1: Run focused backend gates**

Run:

```bash
cd packages/zigeffect
zig build causal-otel-backend
zig build causal-dot-backend
zig build causal-jsonl-backend
zig build causal-backend-conformance
```

Expected: all PASS.

- [ ] **Step 2: Run package and repo verification**

Run:

```bash
cd packages/zigeffect
zig build test-raw --summary none
zig build test --summary none
zig build causal-test-matrix
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check HEAD
```

Expected:

- Zig focused and package checks exit zero.
- `bun run check` exits zero with no failing tests.
- `bun run zig:test` exits zero.
- `git diff --check HEAD` exits zero.
- `git status --short` shows only the known unrelated untracked
  `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  file outside this branch's committed work.

- [ ] **Step 3: Merge to master**

Run:

```bash
git switch master
git merge --ff-only codex/zigeffect-causal-otel-backend
git branch -d codex/zigeffect-causal-otel-backend
```

Expected: fast-forward merge succeeds and branch deletes cleanly.

- [ ] **Step 4: Run post-merge smoke verification**

Run:

```bash
cd packages/zigeffect
zig build causal-otel-backend
zig build test --summary none
cd ../..
bun run check
bun run zig:test
git diff --check HEAD
```

Expected: all exit zero; only the known unrelated untracked durable-workflows
roadmap file remains outside committed work.

- [ ] **Step 5: Start the next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-graph-history-backend
```

Expected: new feature branch is created from verified `master`.

## Self-Review

- Spec coverage: The tasks cover OTel-shaped mapping, signal classification,
  typed attributes, hex helpers, backend state, max-record failure, conformance
  behavior, docs, roadmap updates, verification, and merge.
- Red-flag scan: No forbidden marker strings or vague test instructions remain.
- Type consistency: Public API names match the design:
  `CausalOtelRecord`, `CausalOtelBackendState`, `classifyCausalOtelSignal`,
  `formatCausalOtelTraceId`, `formatCausalOtelSpanId`, and
  `mapCausalEventToOtelRecord`.
