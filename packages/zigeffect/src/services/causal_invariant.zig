const std = @import("std");
const causal = @import("causal.zig");

pub const CausalInvariantViolationKind = enum {
    pending_fiber_after_scope_close,
    resource_not_finalized,
    suspended_fiber_unresolved,
    assertion_failed,
};

pub const CausalInvariantViolation = struct {
    kind: CausalInvariantViolationKind,
    event_id: u64,
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
    resource_id: ?u64 = null,
};

pub const CausalInvariantCheck = struct {
    allocator: std.mem.Allocator,
    violations: []CausalInvariantViolation,

    pub fn deinit(self: *CausalInvariantCheck) void {
        self.allocator.free(self.violations);
    }
};

pub const CausalInvariantBuilder = struct {
    every_resource_finalized: bool = false,
    suspended_fibers_resolve: bool = false,
    no_pending_fibers_after_scope_close: bool = false,
    no_assertion_failures: bool = false,

    pub fn init() CausalInvariantBuilder {
        return .{};
    }

    pub fn requireEveryResourceFinalized(self: CausalInvariantBuilder) CausalInvariantBuilder {
        var next = self;
        next.every_resource_finalized = true;
        return next;
    }

    pub fn requireSuspendedFibersResolve(self: CausalInvariantBuilder) CausalInvariantBuilder {
        var next = self;
        next.suspended_fibers_resolve = true;
        return next;
    }

    pub fn requireNoPendingFibersAfterScopeClose(self: CausalInvariantBuilder) CausalInvariantBuilder {
        var next = self;
        next.no_pending_fibers_after_scope_close = true;
        return next;
    }

    pub fn requireNoAssertionFailures(self: CausalInvariantBuilder) CausalInvariantBuilder {
        var next = self;
        next.no_assertion_failures = true;
        return next;
    }

    pub fn check(
        self: CausalInvariantBuilder,
        allocator: std.mem.Allocator,
        events: []const causal.CausalEvent,
    ) std.mem.Allocator.Error!CausalInvariantCheck {
        var violations = std.ArrayList(CausalInvariantViolation).empty;
        errdefer violations.deinit(allocator);

        if (self.every_resource_finalized) {
            try appendResourceViolations(allocator, &violations, events);
        }
        if (self.suspended_fibers_resolve) {
            try appendSuspendedFiberViolations(allocator, &violations, events);
        }
        if (self.no_pending_fibers_after_scope_close) {
            try appendPendingFiberViolations(allocator, &violations, events);
        }
        if (self.no_assertion_failures) {
            try appendAssertionViolations(allocator, &violations, events);
        }

        return .{ .allocator = allocator, .violations = try violations.toOwnedSlice(allocator) };
    }
};

fn resourceFinalized(events: []const causal.CausalEvent, acquired: causal.CausalEvent) bool {
    for (events) |event| {
        if (event.kind != .resource_finalized) continue;
        if (acquired.resource_id) |resource_id| {
            if (event.resource_id == resource_id) return true;
        } else if (event.scope_id == acquired.scope_id and std.mem.eql(u8, event.type_name, acquired.type_name)) {
            return true;
        }
    }
    return false;
}

fn appendResourceViolations(
    allocator: std.mem.Allocator,
    violations: *std.ArrayList(CausalInvariantViolation),
    events: []const causal.CausalEvent,
) std.mem.Allocator.Error!void {
    for (events) |event| {
        if (event.kind != .resource_acquired) continue;
        if (resourceFinalized(events, event)) continue;
        try violations.append(allocator, .{
            .kind = .resource_not_finalized,
            .event_id = event.id,
            .run_id = event.run_id,
            .scope_id = event.scope_id,
            .resource_id = event.resource_id,
        });
    }
}

fn fiberResolvedAfter(events: []const causal.CausalEvent, source: causal.CausalEvent) bool {
    const fiber_id = source.fiber_id orelse return true;
    for (events) |event| {
        if (event.id <= source.id) continue;
        if (event.fiber_id != fiber_id) continue;
        switch (event.kind) {
            .fiber_resumed, .fiber_joined, .fiber_interrupted => return true,
            else => {},
        }
    }
    return false;
}

fn appendSuspendedFiberViolations(
    allocator: std.mem.Allocator,
    violations: *std.ArrayList(CausalInvariantViolation),
    events: []const causal.CausalEvent,
) std.mem.Allocator.Error!void {
    for (events) |event| {
        if (event.kind != .fiber_suspended) continue;
        if (fiberResolvedAfter(events, event)) continue;
        try violations.append(allocator, .{
            .kind = .suspended_fiber_unresolved,
            .event_id = event.id,
            .run_id = event.run_id,
            .scope_id = event.scope_id,
            .fiber_id = event.fiber_id,
        });
    }
}

fn fiberPendingAtScopeClose(events: []const causal.CausalEvent, source: causal.CausalEvent, closed: causal.CausalEvent) bool {
    const fiber_id = source.fiber_id orelse return false;
    if (source.id > closed.id) return false;
    for (events) |event| {
        if (event.id <= source.id) continue;
        if (event.fiber_id != fiber_id) continue;
        switch (event.kind) {
            .fiber_joined, .fiber_interrupted => return false,
            else => {},
        }
    }
    return true;
}

fn appendPendingFiberViolations(
    allocator: std.mem.Allocator,
    violations: *std.ArrayList(CausalInvariantViolation),
    events: []const causal.CausalEvent,
) std.mem.Allocator.Error!void {
    for (events) |closed| {
        if (closed.kind != .scope_closed) continue;
        const scope_id = closed.scope_id orelse continue;
        for (events) |event| {
            if (event.scope_id != scope_id) continue;
            if (event.fiber_id == null) continue;
            switch (event.kind) {
                .fiber_forked, .fiber_started, .fiber_suspended => {},
                else => continue,
            }
            if (!fiberPendingAtScopeClose(events, event, closed)) continue;
            try violations.append(allocator, .{
                .kind = .pending_fiber_after_scope_close,
                .event_id = event.id,
                .run_id = event.run_id,
                .scope_id = event.scope_id,
                .fiber_id = event.fiber_id,
            });
            break;
        }
    }
}

fn appendAssertionViolations(
    allocator: std.mem.Allocator,
    violations: *std.ArrayList(CausalInvariantViolation),
    events: []const causal.CausalEvent,
) std.mem.Allocator.Error!void {
    for (events) |event| {
        if (event.kind != .assertion_recorded) continue;
        if (!std.mem.eql(u8, event.status, "failure")) continue;
        try violations.append(allocator, .{
            .kind = .assertion_failed,
            .event_id = event.id,
            .run_id = event.run_id,
            .scope_id = event.scope_id,
            .fiber_id = event.fiber_id,
        });
    }
}
