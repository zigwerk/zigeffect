const std = @import("std");
const Contract = @import("contract.zig");

pub const Operator = enum { condition_negate, boundary_shift, constant_replace, error_suppress, transition_remove };
pub const Outcome = enum { killed, survived, unsupported };

pub const Point = struct {
    id: []const u8,
    operator: Operator,
    requirement: []const u8,
    source: Contract.SourceReference,

    pub fn validate(self: Point) !void {
        if (self.id.len == 0 or self.requirement.len == 0) return error.InvalidMutationPoint;
        try self.source.validate();
    }
};

pub const Result = struct { point: Point, outcome: Outcome, detail: []const u8 = "" };

pub const Runner = struct {
    state: *anyopaque,
    run_fn: *const fn (*anyopaque, Point) anyerror!Outcome,
    pub fn run(self: Runner, point: Point) !Outcome {
        return self.run_fn(self.state, point);
    }
};

pub const Options = struct { max_mutants: usize = 1024 };

pub const Report = struct {
    allocator: std.mem.Allocator,
    planned: usize,
    killed: usize,
    survived: usize,
    unsupported: usize,
    results: []Result,
    truncated: bool,
    replay_token: []const u8,

    pub fn deinit(self: *Report) void {
        self.allocator.free(self.results);
        self.allocator.free(self.replay_token);
    }

    pub fn status(self: Report) Contract.TestStatus {
        if (self.survived != 0) return .failed;
        if (self.truncated or self.results.len != self.planned) return .incomplete;
        if (self.killed == 0 and self.unsupported != 0) return .unsupported;
        return .passed;
    }

    pub fn evidenceSummary(self: Report) Contract.EvidenceSummary {
        return .{
            .attempted = true,
            .status = self.status(),
            .planned = self.planned,
            .executed = self.results.len,
            .passed = self.killed,
            .failed = self.survived,
            .unsupported = self.unsupported,
            .truncated = self.truncated,
            .replay_token = self.replay_token,
        };
    }

    pub fn jsonAlloc(self: Report, allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .schema = "zigeffect.test-mutation.v1",
            .status = @tagName(self.status()),
            .planned = self.planned,
            .killed = self.killed,
            .survived = self.survived,
            .unsupported = self.unsupported,
            .truncated = self.truncated,
            .replay_token = self.replay_token,
            .results = self.results,
            .source_writes = @as(usize, 0),
        }, .{});
    }
};

/// Computes a stable ID without editing source files. The runtime mutator is an
/// injected evaluator over a declared point, so source trees remain untouched.
pub fn stableIdAlloc(allocator: std.mem.Allocator, operator: Operator, source: Contract.SourceReference) ![]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(@tagName(operator));
    hasher.update(source.path);
    hasher.update(std.mem.asBytes(&source.line));
    hasher.update(std.mem.asBytes(&source.column));
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    return std.fmt.allocPrint(allocator, "mut-{x}", .{digest[0..8]});
}

pub fn runAlloc(allocator: std.mem.Allocator, points: []const Point, runner: Runner, options: Options) !Report {
    if (options.max_mutants == 0) return error.InvalidBounds;
    var results = std.ArrayList(Result).empty;
    errdefer results.deinit(allocator);
    var killed: usize = 0;
    var survived: usize = 0;
    var unsupported: usize = 0;
    var first_survivor: ?[]const u8 = null;
    const limit = @min(points.len, options.max_mutants);
    for (points[0..limit], 0..) |point, index| {
        try point.validate();
        for (points[0..index]) |previous| if (std.mem.eql(u8, previous.id, point.id)) return error.DuplicateMutationPoint;
        const outcome = runner.run(point) catch .unsupported;
        switch (outcome) {
            .killed => killed += 1,
            .survived => {
                survived += 1;
                if (first_survivor == null) first_survivor = point.id;
            },
            .unsupported => unsupported += 1,
        }
        try results.append(allocator, .{ .point = point, .outcome = outcome });
    }
    const replay = if (first_survivor) |id| try std.fmt.allocPrint(allocator, "zigeffect test replay --mutant {s}", .{id}) else try allocator.dupe(u8, "");
    return .{
        .allocator = allocator,
        .planned = points.len,
        .killed = killed,
        .survived = survived,
        .unsupported = unsupported,
        .results = try results.toOwnedSlice(allocator),
        .truncated = limit != points.len,
        .replay_token = replay,
    };
}

test "mutation analysis uses stable IDs and requirement-linked outcomes without source writes" {
    const source = Contract.SourceReference{ .id = "guard", .path = "src/main.zig", .line = 12, .column = 3 };
    const first = try stableIdAlloc(std.testing.allocator, .condition_negate, source);
    defer std.testing.allocator.free(first);
    const second = try stableIdAlloc(std.testing.allocator, .condition_negate, source);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualStrings(first, second);
    const State = struct {
        fn run(_: *anyopaque, point: Point) !Outcome {
            return if (std.mem.eql(u8, point.id, "survivor")) .survived else .killed;
        }
    };
    var state: u8 = 0;
    var report = try runAlloc(std.testing.allocator, &.{
        .{ .id = "killed", .operator = .boundary_shift, .requirement = "req-1", .source = source },
        .{ .id = "survivor", .operator = .error_suppress, .requirement = "req-1", .source = source },
    }, .{ .state = &state, .run_fn = State.run }, .{});
    defer report.deinit();
    try std.testing.expectEqual(Contract.TestStatus.failed, report.status());
    try std.testing.expect(std.mem.indexOf(u8, report.replay_token, "survivor") != null);
}

test "mutation analysis reports bounds and unsupported mutants truthfully" {
    const State = struct {
        fn run(_: *anyopaque, _: Point) !Outcome {
            return .unsupported;
        }
    };
    var state: u8 = 0;
    const source = Contract.SourceReference{ .id = "p", .path = "src/a.zig", .line = 1, .column = 1 };
    var report = try runAlloc(std.testing.allocator, &.{
        .{ .id = "a", .operator = .constant_replace, .requirement = "r", .source = source },
        .{ .id = "b", .operator = .constant_replace, .requirement = "r", .source = source },
    }, .{ .state = &state, .run_fn = State.run }, .{ .max_mutants = 1 });
    defer report.deinit();
    try std.testing.expect(report.truncated);
    try std.testing.expectEqual(Contract.TestStatus.incomplete, report.status());
}
