const std = @import("std");
const result = @import("result.zig");

pub const Allocator = std.mem.Allocator;
pub const FinalizerExit = result.FinalizerExit;
pub const ScopeError = error{MissingScope};
pub const FinalizerRegistrationError = Allocator.Error || ScopeError;

pub const Scope = struct {
    const Finalizer = struct {
        state: ?*anyopaque,
        run: *const fn (?*anyopaque, FinalizerExit) ?[]const u8,
    };

    allocator: Allocator,
    finalizers: std.ArrayList(Finalizer) = .empty,
    finalizer_failures: std.ArrayList([]const u8) = .empty,
    closed: bool = false,

    pub fn init(allocator: Allocator) Scope {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Scope) void {
        if (!self.closed) self.close();
        self.finalizer_failures.deinit(self.allocator);
        self.finalizers.deinit(self.allocator);
    }

    pub fn addFinalizer(
        self: *Scope,
        state: ?*anyopaque,
        comptime run: *const fn (?*anyopaque) void,
    ) Allocator.Error!void {
        const Runner = struct {
            fn runNoFailure(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                _ = exit;
                run(raw);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = state,
            .run = Runner.runNoFailure,
        });
    }

    pub fn addFinalizerFallible(
        self: *Scope,
        state: ?*anyopaque,
        comptime run: anytype,
    ) Allocator.Error!void {
        const Runner = struct {
            fn runFallible(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                _ = exit;
                run(raw) catch |err| return @errorName(err);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = state,
            .run = Runner.runFallible,
        });
    }

    pub fn addFinalizerFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: *const fn (*Resource) void,
    ) Allocator.Error!void {
        const Runner = struct {
            fn run(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                _ = exit;
                const typed: *Resource = @ptrCast(@alignCast(raw.?));
                release(typed);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = resource,
            .run = Runner.run,
        });
    }

    pub fn addFinalizerFallibleFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: anytype,
    ) Allocator.Error!void {
        const Runner = struct {
            fn run(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                _ = exit;
                const typed: *Resource = @ptrCast(@alignCast(raw.?));
                release(typed) catch |err| return @errorName(err);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = resource,
            .run = Runner.run,
        });
    }

    pub fn addFinalizerExit(
        self: *Scope,
        state: ?*anyopaque,
        comptime run: *const fn (?*anyopaque, FinalizerExit) void,
    ) Allocator.Error!void {
        const Runner = struct {
            fn runNoFailure(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                run(raw, exit);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = state,
            .run = Runner.runNoFailure,
        });
    }

    pub fn addFinalizerExitFallible(
        self: *Scope,
        state: ?*anyopaque,
        comptime run: anytype,
    ) Allocator.Error!void {
        const Runner = struct {
            fn runFallible(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                run(raw, exit) catch |err| return @errorName(err);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = state,
            .run = Runner.runFallible,
        });
    }

    pub fn addFinalizerExitFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: *const fn (*Resource, FinalizerExit) void,
    ) Allocator.Error!void {
        const Runner = struct {
            fn run(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                const typed: *Resource = @ptrCast(@alignCast(raw.?));
                release(typed, exit);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = resource,
            .run = Runner.run,
        });
    }

    pub fn addFinalizerExitFallibleFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: anytype,
    ) Allocator.Error!void {
        const Runner = struct {
            fn run(raw: ?*anyopaque, exit: FinalizerExit) ?[]const u8 {
                const typed: *Resource = @ptrCast(@alignCast(raw.?));
                release(typed, exit) catch |err| return @errorName(err);
                return null;
            }
        };

        try self.finalizers.append(self.allocator, .{
            .state = resource,
            .run = Runner.run,
        });
    }

    pub fn close(self: *Scope) void {
        self.closeWithExit(.success);
    }

    pub fn closeWithExit(self: *Scope, exit: FinalizerExit) void {
        if (self.closed) return;
        while (self.finalizers.items.len > 0) {
            const index = self.finalizers.items.len - 1;
            const finalizer = self.finalizers.items[index];
            self.finalizers.items.len = index;
            if (finalizer.run(finalizer.state, exit)) |failure| {
                self.finalizer_failures.append(self.allocator, failure) catch {};
            }
        }
        self.closed = true;
    }

    pub fn finalizerFailureCount(self: *const Scope) usize {
        return self.finalizer_failures.items.len;
    }

    pub fn firstFinalizerFailure(self: *const Scope) ?[]const u8 {
        if (self.finalizer_failures.items.len == 0) return null;
        return self.finalizer_failures.items[0];
    }

    pub fn hasFinalizerFailure(self: *const Scope, expected: []const u8) bool {
        for (self.finalizer_failures.items) |failure| {
            if (std.mem.eql(u8, failure, expected)) return true;
        }
        return false;
    }
};
