const std = @import("std");

pub const schema = "zigeffect.test-suite-receipt.v2";
pub const schema_version: u32 = 2;
pub const runner_version = "2.0.0";

pub const Status = enum { passed, skipped, failed, pending };

pub const TestResult = struct {
    index: u32,
    id: []const u8,
    status: Status,
    error_name: ?[]const u8 = null,
    log_error_count: u32 = 0,
    leak_count: u32 = 0,
    duration_ms: u64 = 0,

    pub fn isPassing(self: TestResult) bool {
        return (self.status == .passed or self.status == .skipped) and
            self.log_error_count == 0 and self.leak_count == 0;
    }
};

pub const Counts = struct {
    discovered: u32,
    executed: u32,
    passed: u32,
    skipped: u32,
    failed: u32,
    pending: u32,
    log_errors: u32,
    leaks: u32,

    pub fn fromResults(discovered: usize, results: []const TestResult) Counts {
        var counts: Counts = .{
            .discovered = @intCast(discovered),
            .executed = 0,
            .passed = 0,
            .skipped = 0,
            .failed = 0,
            .pending = 0,
            .log_errors = 0,
            .leaks = 0,
        };
        for (results) |result| {
            switch (result.status) {
                .passed => counts.passed += 1,
                .skipped => counts.skipped += 1,
                .failed => counts.failed += 1,
                .pending => counts.pending += 1,
            }
            if (result.status != .pending) counts.executed += 1;
            counts.log_errors +|= result.log_error_count;
            counts.leaks +|= result.leak_count;
        }
        return counts;
    }
};

pub const Execution = struct {
    zig_version: []const u8,
    target: []const u8,
    optimize: []const u8,
    seed: u32,
    runner_version: []const u8 = runner_version,
    replay_command: []const u8,
};

pub const Receipt = struct {
    schema: []const u8 = schema,
    schema_version: u32 = schema_version,
    suite: []const u8,
    status: Status,
    complete: bool,
    started_ms: i64,
    ended_ms: i64,
    duration_ms: u64,
    execution: Execution,
    counts: Counts,
    tests: []const TestResult,
    limitations: []const []const u8 = &.{},

    pub fn validate(self: Receipt) !void {
        if (!std.mem.eql(u8, self.schema, schema) or self.schema_version != schema_version) return error.UnsupportedSchema;
        try validateId(self.suite);
        if (self.ended_ms < self.started_ms) return error.InvalidTiming;
        if (self.execution.zig_version.len == 0 or self.execution.target.len == 0 or self.execution.optimize.len == 0 or self.execution.replay_command.len == 0) return error.InvalidExecution;
        if (self.counts.discovered != self.tests.len) return error.InvalidCounts;

        const computed = Counts.fromResults(self.tests.len, self.tests);
        if (!std.meta.eql(self.counts, computed)) return error.InvalidCounts;

        for (self.tests, 0..) |result, index| {
            if (result.index != index) return error.InvalidTestIndex;
            if (result.id.len == 0) return error.InvalidTestId;
            for (self.tests[0..index]) |prior| {
                if (std.mem.eql(u8, prior.id, result.id)) return error.DuplicateTestId;
            }
        }

        const should_complete = self.counts.executed == self.counts.discovered and self.counts.pending == 0;
        const should_pass = should_complete and self.counts.failed == 0 and self.counts.log_errors == 0 and self.counts.leaks == 0;
        if (self.complete != should_complete) return error.InvalidCompleteness;
        if ((self.status == .passed) != should_pass) return error.InvalidVerdict;
        if (!should_pass and self.status == .passed) return error.InvalidVerdict;
    }

    pub fn jsonAlloc(self: Receipt, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        const json = try std.json.Stringify.valueAlloc(allocator, self, .{});
        errdefer allocator.free(json);
        if (@import("../core/secret_scan.zig").containsSensitiveMaterial(json)) return error.SecretMaterialRejected;
        return json;
    }
};

pub const ParsedReceipt = std.json.Parsed(Receipt);

pub fn parse(allocator: std.mem.Allocator, input: []const u8) !ParsedReceipt {
    if (@import("../core/secret_scan.zig").containsSensitiveMaterial(input)) return error.SecretMaterialRejected;
    var parsed = try std.json.parseFromSlice(Receipt, allocator, input, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub fn writeAtomic(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8, receipt: Receipt) !void {
    const json = try receipt.jsonAlloc(allocator);
    defer allocator.free(json);
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try dir.createDirPath(io, path[0..slash]);
    for (0..1024) |slot| {
        if (try writeAtomicSlot(allocator, io, dir, path, json, slot)) return;
    }
    return error.AtomicTemporaryPathExhausted;
}

fn writeAtomicSlot(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    path: []const u8,
    content: []const u8,
    slot: usize,
) !bool {
    const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ path, slot });
    defer allocator.free(temporary);
    const file = dir.createFile(io, temporary, .{ .exclusive = true }) catch |err| switch (err) {
        error.PathAlreadyExists => return false,
        else => return err,
    };
    var file_open = true;
    defer if (file_open) file.close(io);
    defer dir.deleteFile(io, temporary) catch {};
    try file.writeStreamingAll(io, content);
    file.close(io);
    file_open = false;
    dir.rename(temporary, dir, path, io) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    return true;
}

fn validateId(value: []const u8) !void {
    if (value.len == 0 or value.len > 160) return error.InvalidSuiteId;
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.') continue;
        return error.InvalidSuiteId;
    }
}

fn sample(results: []const TestResult) Receipt {
    const counts = Counts.fromResults(results.len, results);
    const passing = counts.executed == counts.discovered and counts.failed == 0 and counts.pending == 0 and counts.log_errors == 0 and counts.leaks == 0;
    return .{
        .suite = "core-unit",
        .status = if (passing) .passed else .failed,
        .complete = counts.executed == counts.discovered and counts.pending == 0,
        .started_ms = 10,
        .ended_ms = 12,
        .duration_ms = 2,
        .execution = .{
            .zig_version = "0.16.0",
            .target = "aarch64-macos",
            .optimize = "Debug",
            .seed = 42,
            .replay_command = "zig build test",
        },
        .counts = counts,
        .tests = results,
    };
}

test "suite receipt round trips complete passing evidence" {
    const results = [_]TestResult{
        .{ .index = 0, .id = "unit one", .status = .passed },
        .{ .index = 1, .id = "unit two", .status = .skipped },
    };
    const json = try sample(&results).jsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parse(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expect(parsed.value.complete);
    try std.testing.expectEqual(Status.passed, parsed.value.status);
    try std.testing.expectEqual(@as(u32, 2), parsed.value.counts.executed);
}

test "suite receipt rejects incomplete false passes" {
    const results = [_]TestResult{
        .{ .index = 0, .id = "unit one", .status = .passed },
        .{ .index = 1, .id = "unit two", .status = .pending },
    };
    var receipt = sample(&results);
    receipt.status = .passed;
    try std.testing.expectError(error.InvalidVerdict, receipt.validate());
}

test "suite receipt rejects duplicate identities and inconsistent counts" {
    const results = [_]TestResult{
        .{ .index = 0, .id = "same", .status = .passed },
        .{ .index = 1, .id = "same", .status = .passed },
    };
    try std.testing.expectError(error.DuplicateTestId, sample(&results).validate());
    var receipt = sample(&results);
    receipt.counts.passed = 99;
    try std.testing.expectError(error.InvalidCounts, receipt.validate());
}

test "suite receipt fails closed on leaks error logs and failures" {
    inline for (.{
        TestResult{ .index = 0, .id = "leak", .status = .passed, .leak_count = 1 },
        TestResult{ .index = 0, .id = "logged", .status = .passed, .log_error_count = 1 },
        TestResult{ .index = 0, .id = "failed", .status = .failed, .error_name = "Broken" },
    }) |result| {
        const receipt = sample(&.{result});
        try receipt.validate();
        try std.testing.expectEqual(Status.failed, receipt.status);
    }
}

test "suite receipt writes atomically and parses from disk" {
    const results = [_]TestResult{.{ .index = 0, .id = "atomic", .status = .passed }};
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.createDirPath(std.testing.io, "nested");
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "nested/receipt.json.tmp.0", .data = "occupied-by-another-writer" });
    try writeAtomic(std.testing.allocator, std.testing.io, tmp.dir, "nested/receipt.json", sample(&results));
    const bytes = try tmp.dir.readFileAlloc(std.testing.io, "nested/receipt.json", std.testing.allocator, .limited(64 * 1024));
    defer std.testing.allocator.free(bytes);
    var parsed = try parse(std.testing.allocator, bytes);
    defer parsed.deinit();
    try std.testing.expectEqualStrings("core-unit", parsed.value.suite);
    const occupied = try tmp.dir.readFileAlloc(std.testing.io, "nested/receipt.json.tmp.0", std.testing.allocator, .limited(64));
    defer std.testing.allocator.free(occupied);
    try std.testing.expectEqualStrings("occupied-by-another-writer", occupied);
}
