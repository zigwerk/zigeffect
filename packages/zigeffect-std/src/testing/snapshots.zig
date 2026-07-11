const std = @import("std");
const Secrets = @import("../secrets/root.zig");
const Project = @import("../project/root.zig");

pub const snapshot_schema = "zigeffect.test-snapshot.v1";
pub const snapshot_schema_version: u32 = 1;
pub const fixture_root = ".zigeffect/tests/snapshots";

pub const Kind = enum {
    text,
    semantic_json,
    jsonl_set,
    causal_shape,
    application_facts,
    workflow_receipt,
    statechart_receipt,
    test_receipt,
};

pub const Snapshot = struct {
    schema: []const u8 = snapshot_schema,
    schema_version: u32 = snapshot_schema_version,
    id: []const u8,
    kind: Kind,
    normalized: []const u8,
    digest: []const u8,
    ignore_fields: []const []const u8 = &.{},

    pub fn validate(self: Snapshot) !void {
        if (!std.mem.eql(u8, self.schema, snapshot_schema) or self.schema_version != snapshot_schema_version) return error.UnsupportedSnapshotSchema;
        try validateId(self.id);
        if (self.normalized.len > 16 * 1024 * 1024) return error.SnapshotTooLarge;
        if (Secrets.containsSecret(self.normalized)) return error.SecretDetected;
        const actual = try digestAlloc(std.heap.page_allocator, self.normalized);
        defer std.heap.page_allocator.free(actual);
        if (!std.mem.eql(u8, actual, self.digest)) return error.CorruptSnapshot;
    }

    pub fn compareAlloc(self: Snapshot, allocator: std.mem.Allocator, actual: []const u8) !Comparison {
        try self.validate();
        const normalized_actual = try normalizeAlloc(allocator, self.kind, actual, self.ignore_fields);
        errdefer allocator.free(normalized_actual);
        const actual_digest = try digestAlloc(allocator, normalized_actual);
        errdefer allocator.free(actual_digest);
        const expected_digest = try allocator.dupe(u8, self.digest);
        errdefer allocator.free(expected_digest);
        const diff = try diffSummaryAlloc(allocator, self.normalized, normalized_actual);
        return .{
            .allocator = allocator,
            .equal = std.mem.eql(u8, self.normalized, normalized_actual),
            .expected_digest = expected_digest,
            .actual_digest = actual_digest,
            .normalized_actual = normalized_actual,
            .diff = diff,
        };
    }
};

pub const OwnedSnapshot = struct {
    allocator: std.mem.Allocator,
    value: Snapshot,

    pub fn deinit(self: *OwnedSnapshot) void {
        self.allocator.free(self.value.id);
        self.allocator.free(self.value.normalized);
        self.allocator.free(self.value.digest);
        for (self.value.ignore_fields) |field| self.allocator.free(field);
        self.allocator.free(self.value.ignore_fields);
    }
};

pub const Comparison = struct {
    allocator: std.mem.Allocator,
    equal: bool,
    expected_digest: []const u8,
    actual_digest: []const u8,
    normalized_actual: []const u8,
    diff: []const u8,

    pub fn deinit(self: *Comparison) void {
        self.allocator.free(self.expected_digest);
        self.allocator.free(self.actual_digest);
        self.allocator.free(self.normalized_actual);
        self.allocator.free(self.diff);
    }
};

pub const UpdatePlan = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    expected_digest: []const u8,
    proposed: []const u8,
    proposed_digest: []const u8,

    pub fn deinit(self: *UpdatePlan) void {
        self.allocator.free(self.path);
        self.allocator.free(self.expected_digest);
        self.allocator.free(self.proposed);
        self.allocator.free(self.proposed_digest);
    }

    /// Verifies optimistic concurrency before a CLI or application performs
    /// the explicit write. Snapshot comparison itself never mutates storage.
    pub fn verifyCurrent(self: UpdatePlan, allocator: std.mem.Allocator, current: []const u8) !void {
        const digest = try digestAlloc(allocator, current);
        defer allocator.free(digest);
        if (!std.mem.eql(u8, digest, self.expected_digest)) return error.SnapshotConflict;
    }
};

pub fn captureAlloc(allocator: std.mem.Allocator, id: []const u8, kind: Kind, input: []const u8, ignore_fields: []const []const u8) !OwnedSnapshot {
    try validateId(id);
    const normalized = try normalizeAlloc(allocator, kind, input, ignore_fields);
    errdefer allocator.free(normalized);
    const digest = try digestAlloc(allocator, normalized);
    errdefer allocator.free(digest);
    const owned_ignore = try allocator.alloc([]const u8, ignore_fields.len);
    errdefer allocator.free(owned_ignore);
    var initialized: usize = 0;
    errdefer for (owned_ignore[0..initialized]) |field| allocator.free(field);
    for (ignore_fields, 0..) |field, index| {
        try validateId(field);
        owned_ignore[index] = try allocator.dupe(u8, field);
        initialized += 1;
    }
    return .{ .allocator = allocator, .value = .{
        .id = try allocator.dupe(u8, id),
        .kind = kind,
        .normalized = normalized,
        .digest = digest,
        .ignore_fields = owned_ignore,
    } };
}

pub fn planUpdateAlloc(allocator: std.mem.Allocator, path: []const u8, current: []const u8, comparison: Comparison) !UpdatePlan {
    try validateFixturePath(path);
    return .{
        .allocator = allocator,
        .path = try allocator.dupe(u8, path),
        .expected_digest = try digestAlloc(allocator, current),
        .proposed = try allocator.dupe(u8, comparison.normalized_actual),
        .proposed_digest = try allocator.dupe(u8, comparison.actual_digest),
    };
}

pub fn validateFixturePath(path: []const u8) !void {
    try Project.validateRelativePath(path, false);
    if (!std.mem.startsWith(u8, path, fixture_root ++ "/")) return error.OutsideFixtureRoot;
    if (!(std.mem.endsWith(u8, path, ".snap") or std.mem.endsWith(u8, path, ".json") or std.mem.endsWith(u8, path, ".jsonl"))) return error.InvalidFixtureExtension;
}

pub fn normalizeAlloc(allocator: std.mem.Allocator, kind: Kind, input: []const u8, ignore_fields: []const []const u8) ![]u8 {
    if (input.len > 16 * 1024 * 1024) return error.SnapshotTooLarge;
    if (Secrets.containsSecret(input)) return error.SecretDetected;
    return switch (kind) {
        .text => normalizeTextAlloc(allocator, input),
        .jsonl_set => normalizeJsonlSetAlloc(allocator, input, ignore_fields),
        .semantic_json, .causal_shape, .application_facts, .workflow_receipt, .statechart_receipt, .test_receipt => normalizeJsonAlloc(allocator, input, ignore_fields),
    };
}

fn normalizeTextAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    var lines = std.mem.splitScalar(u8, input, '\n');
    var first = true;
    while (lines.next()) |raw| {
        var line = raw;
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        line = std.mem.trimEnd(u8, line, " \t");
        if (!first) try output.append(allocator, '\n');
        first = false;
        try output.appendSlice(allocator, line);
    }
    while (output.items.len > 0 and output.items[output.items.len - 1] == '\n') _ = output.pop();
    try output.append(allocator, '\n');
    return output.toOwnedSlice(allocator);
}

fn normalizeJsonAlloc(allocator: std.mem.Allocator, input: []const u8, ignore_fields: []const []const u8) ![]u8 {
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, input, .{});
    defer parsed.deinit();
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try appendCanonicalJson(&output, allocator, parsed.value, ignore_fields);
    try output.append(allocator, '\n');
    return output.toOwnedSlice(allocator);
}

fn normalizeJsonlSetAlloc(allocator: std.mem.Allocator, input: []const u8, ignore_fields: []const []const u8) ![]u8 {
    var rows = std.ArrayList([]const u8).empty;
    defer {
        for (rows.items) |row| allocator.free(row);
        rows.deinit(allocator);
    }
    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        const normalized = try normalizeJsonAlloc(allocator, trimmed, ignore_fields);
        try rows.append(allocator, normalized);
    }
    std.mem.sort([]const u8, rows.items, {}, struct {
        fn lessThan(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.lessThan);
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    for (rows.items) |row| try output.appendSlice(allocator, row);
    return output.toOwnedSlice(allocator);
}

fn appendCanonicalJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: std.json.Value, ignore_fields: []const []const u8) !void {
    switch (value) {
        .null => try output.appendSlice(allocator, "null"),
        .bool => |item| try output.appendSlice(allocator, if (item) "true" else "false"),
        .integer => |item| try output.print(allocator, "{d}", .{item}),
        .float => |item| try output.print(allocator, "{d}", .{item}),
        .number_string => |item| try output.appendSlice(allocator, item),
        .string => |item| try appendJsonString(output, allocator, item),
        .array => |items| {
            try output.append(allocator, '[');
            for (items.items, 0..) |item, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendCanonicalJson(output, allocator, item, ignore_fields);
            }
            try output.append(allocator, ']');
        },
        .object => |object| {
            var keys = std.ArrayList([]const u8).empty;
            defer keys.deinit(allocator);
            var iterator = object.iterator();
            while (iterator.next()) |entry| if (!ignored(entry.key_ptr.*, ignore_fields)) try keys.append(allocator, entry.key_ptr.*);
            std.mem.sort([]const u8, keys.items, {}, struct {
                fn lessThan(_: void, left: []const u8, right: []const u8) bool {
                    return std.mem.lessThan(u8, left, right);
                }
            }.lessThan);
            try output.append(allocator, '{');
            for (keys.items, 0..) |key, index| {
                if (index != 0) try output.append(allocator, ',');
                try appendJsonString(output, allocator, key);
                try output.append(allocator, ':');
                try appendCanonicalJson(output, allocator, object.get(key).?, ignore_fields);
            }
            try output.append(allocator, '}');
        },
    }
}

fn ignored(field: []const u8, fields: []const []const u8) bool {
    for (fields) |candidate| if (std.mem.eql(u8, candidate, field)) return true;
    return false;
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn digestAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(input, &digest, .{});
    return std.fmt.allocPrint(allocator, "sha256:{x}", .{digest});
}

fn diffSummaryAlloc(allocator: std.mem.Allocator, expected: []const u8, actual: []const u8) ![]u8 {
    if (std.mem.eql(u8, expected, actual)) return allocator.dupe(u8, "equal");
    const limit = @min(expected.len, actual.len);
    var index: usize = 0;
    while (index < limit and expected[index] == actual[index]) : (index += 1) {}
    var line: usize = 1;
    for (expected[0..index]) |byte| if (byte == '\n') {
        line += 1;
    };
    return std.fmt.allocPrint(allocator, "first semantic difference at line {d}, byte {d}; expected {d} bytes, actual {d} bytes", .{ line, index, expected.len, actual.len });
}

fn validateId(id: []const u8) !void {
    if (id.len == 0 or id.len > 128) return error.InvalidSnapshotId;
    for (id) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.')) return error.InvalidSnapshotId;
}

test "semantic snapshots canonicalize keys ignore volatile fields and compare" {
    var snapshot = try captureAlloc(std.testing.allocator, "order", .semantic_json, "{\"time\":1,\"b\":2,\"a\":1}", &.{"time"});
    defer snapshot.deinit();
    var comparison = try snapshot.value.compareAlloc(std.testing.allocator, "{\"a\":1,\"time\":99,\"b\":2}");
    defer comparison.deinit();
    try std.testing.expect(comparison.equal);
    try std.testing.expectEqualStrings("equal", comparison.diff);
}

test "JSONL set and causal shape snapshots ignore order and volatile ids" {
    const input = "{\"id\":2,\"kind\":\"end\"}\n{\"id\":1,\"kind\":\"start\"}\n";
    var snapshot = try captureAlloc(std.testing.allocator, "events", .jsonl_set, input, &.{"id"});
    defer snapshot.deinit();
    var comparison = try snapshot.value.compareAlloc(std.testing.allocator, "{\"kind\":\"start\",\"id\":9}\n{\"kind\":\"end\",\"id\":8}");
    defer comparison.deinit();
    try std.testing.expect(comparison.equal);
}

test "snapshot updates require explicit conflict-free plans" {
    var snapshot = try captureAlloc(std.testing.allocator, "text", .text, "old  \r\n", &.{});
    defer snapshot.deinit();
    var comparison = try snapshot.value.compareAlloc(std.testing.allocator, "new\n");
    defer comparison.deinit();
    try std.testing.expect(!comparison.equal);
    var plan = try planUpdateAlloc(std.testing.allocator, ".zigeffect/tests/snapshots/text.snap", "old\n", comparison);
    defer plan.deinit();
    try plan.verifyCurrent(std.testing.allocator, "old\n");
    try std.testing.expectError(error.SnapshotConflict, plan.verifyCurrent(std.testing.allocator, "changed\n"));
    try std.testing.expectError(error.OutsideFixtureRoot, validateFixturePath("src/text.snap"));
}

test "snapshots reject secrets corruption and release partial allocations" {
    try std.testing.expectError(error.SecretDetected, captureAlloc(std.testing.allocator, "secret", .text, "sentinel-secret-for-tests", &.{}));
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var snapshot = try captureAlloc(allocator, "json", .semantic_json, "{\"ok\":true}", &.{});
            defer snapshot.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}
