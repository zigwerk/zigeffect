const std = @import("std");
const safe_resource = @import("../core/safe_resource.zig");

pub const schedule_exploration_schema = "zigeffect.schedule-exploration.v1";
pub const schedule_exploration_schema_version: u32 = 1;

pub const ScheduleFailureKind = enum {
    invariant_failed,
    deadlock,
    step_error,
};

pub const ScheduleExplorationVerdict = enum {
    passed,
    failed,
    incomplete,
};

pub const ScheduleExplorerOptions = struct {
    max_states: usize = 10_000,
    max_schedules: usize = 10_000,
    max_steps_per_schedule: usize = 64,
};

pub const ScheduleFailure = struct {
    kind: ScheduleFailureKind,
    schedule: []usize,
    source_ref_id: ?u64 = null,
    error_name: []const u8 = "",
};

pub const ScheduleExplorationReport = struct {
    allocator: std.mem.Allocator,
    explored_states: usize = 0,
    explored_schedules: usize = 0,
    deduplicated_states: usize = 0,
    truncated: bool = false,
    failure: ?ScheduleFailure = null,

    pub fn deinit(self: *ScheduleExplorationReport) void {
        if (self.failure) |failure| self.allocator.free(failure.schedule);
        self.* = undefined;
    }

    pub fn verdict(self: ScheduleExplorationReport) ScheduleExplorationVerdict {
        if (self.truncated) return .incomplete;
        if (self.failure != null) return .failed;
        return .passed;
    }

    pub fn jsonAlloc(self: ScheduleExplorationReport, allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
        const value = .{
            .schema = schedule_exploration_schema,
            .schema_version = schedule_exploration_schema_version,
            .verdict = self.verdict(),
            .explored_states = self.explored_states,
            .explored_schedules = self.explored_schedules,
            .deduplicated_states = self.deduplicated_states,
            .truncated = self.truncated,
            .failure = self.failure,
        };
        return std.json.Stringify.valueAlloc(allocator, value, .{});
    }
};

pub fn exploreSchedules(
    allocator: std.mem.Allocator,
    initial: anytype,
    options: ScheduleExplorerOptions,
) std.mem.Allocator.Error!ScheduleExplorationReport {
    const Model = @TypeOf(initial);
    comptime {
        safe_resource.assertAgentSendable(Model);
        assertModelContract(Model);
    }
    var report = ScheduleExplorationReport{ .allocator = allocator };
    errdefer report.deinit();
    if (options.max_states == 0 or options.max_schedules == 0 or options.max_steps_per_schedule == 0) {
        report.truncated = true;
        return report;
    }

    var context = ExplorerContext(Model).init(allocator, options, &report);
    defer context.deinit();
    try context.visit(initial);
    return report;
}

pub fn replaySchedule(initial: anytype, schedule: []const usize) anyerror!@TypeOf(initial) {
    const Model = @TypeOf(initial);
    comptime {
        safe_resource.assertAgentSendable(Model);
        assertModelContract(Model);
    }
    var model = initial;
    for (schedule) |action| {
        if (!model.runnable(action)) return error.NotRunnable;
        try model.step(action);
    }
    return model;
}

fn ExplorerContext(comptime Model: type) type {
    return struct {
        const Self = @This();
        const Visited = struct {
            hash: u64,
            depth: usize,
            model: Model,
        };

        allocator: std.mem.Allocator,
        options: ScheduleExplorerOptions,
        report: *ScheduleExplorationReport,
        schedule: std.ArrayList(usize) = .empty,
        visited: std.ArrayList(Visited) = .empty,

        fn init(
            allocator: std.mem.Allocator,
            options: ScheduleExplorerOptions,
            report: *ScheduleExplorationReport,
        ) Self {
            return .{ .allocator = allocator, .options = options, .report = report };
        }

        fn deinit(self: *Self) void {
            self.schedule.deinit(self.allocator);
            self.visited.deinit(self.allocator);
        }

        fn visit(self: *Self, model: Model) std.mem.Allocator.Error!void {
            if (self.report.explored_states >= self.options.max_states) {
                self.report.truncated = true;
                return;
            }
            if (self.alreadyVisited(model)) {
                self.report.deduplicated_states += 1;
                return;
            }
            try self.visited.append(self.allocator, .{
                .hash = model.stateHash(),
                .depth = self.schedule.items.len,
                .model = model,
            });
            self.report.explored_states += 1;

            if (!model.invariant()) {
                try self.recordFailure(.invariant_failed, model, "");
                return;
            }
            if (model.isComplete()) {
                if (self.report.explored_schedules >= self.options.max_schedules) {
                    self.report.truncated = true;
                    return;
                }
                self.report.explored_schedules += 1;
                return;
            }
            if (self.schedule.items.len >= self.options.max_steps_per_schedule) {
                self.report.truncated = true;
                return;
            }

            var found_runnable = false;
            var action: usize = 0;
            while (action < model.actionCount()) : (action += 1) {
                if (!model.runnable(action)) continue;
                found_runnable = true;
                var child = model;
                try self.schedule.append(self.allocator, action);
                if (child.step(action)) |_| {
                    try self.visit(child);
                } else |err| {
                    try self.recordFailure(.step_error, child, @errorName(err));
                }
                _ = self.schedule.pop();
            }
            if (!found_runnable) try self.recordFailure(.deadlock, model, "");
        }

        fn alreadyVisited(self: *Self, model: Model) bool {
            const hash = model.stateHash();
            for (self.visited.items) |visited| {
                if (visited.hash == hash and
                    visited.depth == self.schedule.items.len and
                    std.meta.eql(visited.model, model))
                {
                    return true;
                }
            }
            return false;
        }

        fn recordFailure(
            self: *Self,
            kind: ScheduleFailureKind,
            model: Model,
            error_name: []const u8,
        ) std.mem.Allocator.Error!void {
            if (self.report.failure) |existing| {
                if (!scheduleLess(self.schedule.items, existing.schedule)) return;
            }
            const owned = try self.allocator.dupe(usize, self.schedule.items);
            if (self.report.failure) |existing| self.allocator.free(existing.schedule);
            const source_ref_id = if (self.schedule.items.len > 0)
                model.sourceRef(self.schedule.items[self.schedule.items.len - 1])
            else
                null;
            self.report.failure = .{
                .kind = kind,
                .schedule = owned,
                .source_ref_id = source_ref_id,
                .error_name = error_name,
            };
        }
    };
}

fn scheduleLess(candidate: []const usize, existing: []const usize) bool {
    if (candidate.len != existing.len) return candidate.len < existing.len;
    for (candidate, existing) |left, right| {
        if (left != right) return left < right;
    }
    return false;
}

fn assertModelContract(comptime Model: type) void {
    inline for ([_][]const u8{ "actionCount", "runnable", "step", "isComplete", "invariant", "stateHash", "sourceRef" }) |name| {
        if (!@hasDecl(Model, name)) {
            @compileError("zigeffect schedule model missing declaration: " ++ name);
        }
    }
}
