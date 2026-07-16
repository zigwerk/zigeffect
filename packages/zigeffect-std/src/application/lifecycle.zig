const std = @import("std");
const builtin = @import("builtin");
const fx = @import("zigeffect");
pub const External = @import("../external/root.zig");
const Service = @import("../service/root.zig");
const Secrets = @import("../secrets/root.zig");

test "application lifecycle is a scope-owned service with typed effects" {
    const lifecycle_layer = managerLayer();
    var causal_store = fx.CausalStore.init(std.testing.allocator);
    defer causal_store.deinit();
    var app = try fx.kernel.ManagedRuntime(@TypeOf(lifecycle_layer)).make(std.testing.allocator, lifecycle_layer, .{ .causal_store = &causal_store });
    defer app.deinit();

    try app.run(start());
    try app.run(ready());
    const ready_snapshot = try app.run(currentState());
    try std.testing.expect(ready_snapshot.readiness);
    try app.run(drain());
    try app.run(stop());
    var snapshot = try causal_store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(Service.hasOperation(snapshot, Lifecycle, "Lifecycle.ready", "success"));
}

pub const State = enum {
    stopped,
    starting,
    ready,
    draining,
    stopping,
    forced_stopped,
    failed,
};

pub const Snapshot = struct {
    state: State,
    readiness: bool,
    liveness: bool,
    registered_resources: usize,
    finalized_resources: usize,
    failure: ?External.Failure,
};

pub const Transition = struct { sequence: u64, from: State, to: State, reason: []const u8 };
pub const Evidence = struct {
    allocator: std.mem.Allocator,
    transitions: std.ArrayList(Transition) = .empty,
    pub fn init(allocator: std.mem.Allocator) Evidence {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *Evidence) void {
        for (self.transitions.items) |item| self.allocator.free(item.reason);
        self.transitions.deinit(self.allocator);
    }
    fn record(self: *Evidence, from: State, to: State, reason: []const u8) !void {
        try Secrets.requireSafeBoundary(reason);
        const owned = try self.allocator.dupe(u8, reason);
        errdefer self.allocator.free(owned);
        try self.transitions.append(self.allocator, .{ .sequence = self.transitions.items.len + 1, .from = from, .to = to, .reason = owned });
    }
    pub fn workbenchJsonAlloc(self: *const Evidence, allocator: std.mem.Allocator) ![]u8 {
        return Secrets.safeJsonAlloc(allocator, .{ .schema = "zigeffect.lifecycle.transitions.v1", .transitions = self.transitions.items }, .{});
    }
};

const Finalizer = *const fn (*anyopaque) void;

const Resource = struct {
    name: []const u8,
    pointer: *anyopaque,
    finalizer: Finalizer,
    finalized: bool = false,
};

pub const Manager = struct {
    pub const operations: []const []const u8 = &.{
        "Lifecycle.start",
        "Lifecycle.ready",
        "Lifecycle.drain",
        "Lifecycle.stop",
        "Lifecycle.snapshot",
    };

    allocator: std.mem.Allocator,
    state: State = .stopped,
    resources: std.ArrayList(Resource) = .empty,
    finalized_resources: usize = 0,
    failure: ?External.Failure = null,
    evidence: ?*Evidence = null,

    pub fn init(allocator: std.mem.Allocator) Manager {
        return .{ .allocator = allocator };
    }

    pub fn initWithEvidence(allocator: std.mem.Allocator, evidence: *Evidence) Manager {
        return .{ .allocator = allocator, .evidence = evidence };
    }

    pub fn deinit(self: *Manager) void {
        self.finalizeReverse();
        self.resources.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn start(self: *Manager) !void {
        switch (self.state) {
            .stopped => try self.transition(.starting, "start"),
            .starting, .ready => {},
            .draining, .stopping, .forced_stopped, .failed => return error.InvalidLifecycleTransition,
        }
    }

    pub fn register(self: *Manager, name: []const u8, pointer: *anyopaque, finalizer: Finalizer) !void {
        if (self.state != .starting and self.state != .ready) return error.InvalidLifecycleTransition;
        if (name.len == 0 or name.len > 128) return error.InvalidResourceName;
        for (self.resources.items) |resource| {
            if (std.mem.eql(u8, resource.name, name)) return error.DuplicateResource;
        }
        try self.resources.append(self.allocator, .{ .name = name, .pointer = pointer, .finalizer = finalizer });
    }

    pub fn ready(self: *Manager) !void {
        switch (self.state) {
            .starting => try self.transition(.ready, "ready"),
            .ready => {},
            else => return error.InvalidLifecycleTransition,
        }
    }

    pub fn drain(self: *Manager) !void {
        switch (self.state) {
            .ready, .starting => try self.transition(.draining, "drain"),
            .draining, .stopping, .stopped => {},
            .forced_stopped, .failed => return error.InvalidLifecycleTransition,
        }
    }

    pub fn stop(self: *Manager) !void {
        switch (self.state) {
            .stopped => return,
            .forced_stopped, .failed => return,
            .starting, .ready, .draining, .stopping => if (self.state != .stopping) try self.transition(.stopping, "stop"),
        }
        self.finalizeReverse();
        try self.transition(.stopped, "stopped");
    }

    pub fn forceStop(self: *Manager) !void {
        switch (self.state) {
            .forced_stopped => return,
            .failed => return,
            .stopped => return error.InvalidLifecycleTransition,
            else => {},
        }
        self.finalizeReverse();
        try self.transition(.forced_stopped, "forced-stop");
    }

    pub fn fail(self: *Manager, failure: External.Failure) !void {
        try failure.validate();
        if (self.state == .failed) return;
        self.failure = failure;
        self.finalizeReverse();
        try self.transition(.failed, "failure");
    }

    pub fn snapshot(self: *const Manager) Snapshot {
        return .{
            .state = self.state,
            .readiness = self.state == .ready,
            .liveness = switch (self.state) {
                .starting, .ready, .draining, .stopping => true,
                .stopped, .forced_stopped, .failed => false,
            },
            .registered_resources = self.resources.items.len,
            .finalized_resources = self.finalized_resources,
            .failure = self.failure,
        };
    }

    fn finalizeReverse(self: *Manager) void {
        var index = self.resources.items.len;
        while (index > 0) {
            index -= 1;
            const resource = &self.resources.items[index];
            if (resource.finalized) continue;
            resource.finalizer(resource.pointer);
            resource.finalized = true;
            self.finalized_resources += 1;
        }
    }

    fn transition(self: *Manager, target: State, reason: []const u8) !void {
        const previous = self.state;
        if (self.evidence) |evidence| try evidence.record(previous, target, reason);
        self.state = target;
    }
};

pub const Lifecycle = fx.kernel.Service("zigeffect/std/ApplicationLifecycle", Manager);

const ManagerLifecycle = struct {
    fn acquire(ctx: *fx.kernel.ContextView(.{})) error{}!Manager {
        return Manager.init(ctx.allocator());
    }

    fn release(manager: *Manager) void {
        manager.stop() catch {};
        manager.deinit();
    }
};

pub fn managerLayer() @TypeOf(fx.kernel.Layer.scoped(
    Lifecycle,
    error{},
    .{},
    ManagerLifecycle.acquire,
    ManagerLifecycle.release,
)) {
    return fx.kernel.Layer.scoped(Lifecycle, error{}, .{}, ManagerLifecycle.acquire, ManagerLifecycle.release);
}

const ManagerOperation = enum { start, ready, drain, stop };

fn runManagerOperation(manager: *Manager, comptime operation: ManagerOperation) anyerror!void {
    switch (operation) {
        .start => try manager.start(),
        .ready => try manager.ready(),
        .drain => try manager.drain(),
        .stop => try manager.stop(),
    }
}

fn operationEffect(comptime operation: ManagerOperation) fx.kernel.Effect(void, anyerror, .{Lifecycle}) {
    return fx.kernel.Effect(void, anyerror, .{Lifecycle}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Lifecycle})) anyerror!void {
            runManagerOperation(ctx.service(Lifecycle), operation) catch |failure| {
                _ = Service.recordSemantic(ctx, .span_recorded, Lifecycle.service_key, "Lifecycle." ++ @tagName(operation), "failure", @errorName(failure));
                return failure;
            };
            _ = Service.recordSemantic(ctx, .span_recorded, Lifecycle.service_key, "Lifecycle." ++ @tagName(operation), "success", "application lifecycle transitioned");
        }
    }.run);
}

pub fn start() fx.kernel.Effect(void, anyerror, .{Lifecycle}) {
    return operationEffect(.start);
}
pub fn ready() fx.kernel.Effect(void, anyerror, .{Lifecycle}) {
    return operationEffect(.ready);
}
pub fn drain() fx.kernel.Effect(void, anyerror, .{Lifecycle}) {
    return operationEffect(.drain);
}
pub fn stop() fx.kernel.Effect(void, anyerror, .{Lifecycle}) {
    return operationEffect(.stop);
}

pub fn currentState() fx.kernel.Effect(Snapshot, error{}, .{Lifecycle}) {
    return fx.kernel.Effect(Snapshot, error{}, .{Lifecycle}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Lifecycle})) error{}!Snapshot {
            const current = ctx.service(Lifecycle).snapshot();
            _ = Service.recordSemantic(ctx, .span_recorded, Lifecycle.service_key, "Lifecycle.snapshot", "success", @tagName(current.state));
            return current;
        }
    }.run);
}

pub const ProcessSignal = enum(u8) { none = 0, interrupt = 1, terminate = 2 };
var process_signal = std.atomic.Value(u8).init(0);

fn processSignalHandler(signal: std.posix.SIG) callconv(.c) void {
    const value: ProcessSignal = if (signal == .INT) .interrupt else .terminate;
    process_signal.store(@intFromEnum(value), .release);
}

/// Installs SIGINT/SIGTERM as an async-signal-safe atomic latch. The application
/// loop performs drain and shutdown outside the signal handler.
pub const SignalRegistration = struct {
    old_int: if (builtin.os.tag == .windows) void else std.posix.Sigaction,
    old_term: if (builtin.os.tag == .windows) void else std.posix.Sigaction,
    installed: bool,

    pub fn install() !SignalRegistration {
        process_signal.store(0, .release);
        if (builtin.os.tag == .windows) return .{ .old_int = {}, .old_term = {}, .installed = false };
        const action: std.posix.Sigaction = .{ .handler = .{ .handler = processSignalHandler }, .mask = std.posix.sigemptyset(), .flags = 0 };
        var old_int: std.posix.Sigaction = undefined;
        var old_term: std.posix.Sigaction = undefined;
        std.posix.sigaction(.INT, &action, &old_int);
        std.posix.sigaction(.TERM, &action, &old_term);
        return .{ .old_int = old_int, .old_term = old_term, .installed = true };
    }

    pub fn deinit(self: *SignalRegistration) void {
        if (builtin.os.tag != .windows and self.installed) {
            std.posix.sigaction(.INT, &self.old_int, null);
            std.posix.sigaction(.TERM, &self.old_term, null);
        }
        self.installed = false;
    }
};

pub const SignalApi = struct {
    pub const operations: []const []const u8 = &.{"ProcessSignals.requested"};
    registration: SignalRegistration,
};

/// Process signal handlers are installed once for the owning application
/// scope and restored automatically when its managed runtime is released.
pub const ProcessSignals = fx.kernel.Service("zigeffect/std/ProcessSignals", SignalApi);

const SignalLifecycle = struct {
    fn acquire(_: *fx.kernel.ContextView(.{})) anyerror!SignalApi {
        return .{ .registration = try SignalRegistration.install() };
    }

    fn release(api: *SignalApi) void {
        api.registration.deinit();
    }
};

pub fn signalLayer() @TypeOf(fx.kernel.Layer.scoped(
    ProcessSignals,
    anyerror,
    .{},
    SignalLifecycle.acquire,
    SignalLifecycle.release,
)) {
    return fx.kernel.Layer.scoped(ProcessSignals, anyerror, .{}, SignalLifecycle.acquire, SignalLifecycle.release);
}

pub fn requestedSignal() ProcessSignal {
    return @enumFromInt(process_signal.load(.acquire));
}

pub const RequestedSignalEffect = fx.kernel.Effect(ProcessSignal, error{}, .{ProcessSignals});

pub fn requestedSignalEffect() RequestedSignalEffect {
    return RequestedSignalEffect.fromFn(struct {
        fn run(ctx: *RequestedSignalEffect.Context) error{}!ProcessSignal {
            _ = ctx.service(ProcessSignals);
            const signal = requestedSignal();
            _ = Service.recordSemantic(ctx, .span_recorded, ProcessSignals.service_key, "ProcessSignals.requested", "success", @tagName(signal));
            return signal;
        }
    }.run);
}
pub fn requestShutdownForTest(signal: ProcessSignal) void {
    process_signal.store(@intFromEnum(signal), .release);
}

test "application lifecycle is idempotent and finalizes resources in reverse order" {
    const Recorder = struct {
        order: *[3]u8,
        count: *usize,
        value: u8,

        fn finalize(pointer: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(pointer));
            self.order[self.count.*] = self.value;
            self.count.* += 1;
        }
    };

    var order = [_]u8{ 0, 0, 0 };
    var count: usize = 0;
    var first = Recorder{ .order = &order, .count = &count, .value = 1 };
    var second = Recorder{ .order = &order, .count = &count, .value = 2 };
    var third = Recorder{ .order = &order, .count = &count, .value = 3 };
    var lifecycle = Manager.init(std.testing.allocator);
    defer lifecycle.deinit();

    try lifecycle.start();
    try lifecycle.register("database", &first, Recorder.finalize);
    try lifecycle.register("http", &second, Recorder.finalize);
    try lifecycle.register("telemetry", &third, Recorder.finalize);
    try lifecycle.ready();
    try std.testing.expect(lifecycle.snapshot().readiness);
    try std.testing.expect(lifecycle.snapshot().liveness);

    try lifecycle.drain();
    try lifecycle.drain();
    try std.testing.expect(!lifecycle.snapshot().readiness);
    try lifecycle.stop();
    try lifecycle.stop();
    try std.testing.expectEqualSlices(u8, &.{ 3, 2, 1 }, &order);
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "application lifecycle exposes forced stop and failed health" {
    var lifecycle = Manager.init(std.testing.allocator);
    defer lifecycle.deinit();
    try lifecycle.start();
    try lifecycle.ready();
    try lifecycle.forceStop();
    try std.testing.expectEqual(State.forced_stopped, lifecycle.snapshot().state);
    try std.testing.expect(!lifecycle.snapshot().liveness);

    var failed = Manager.init(std.testing.allocator);
    defer failed.deinit();
    try failed.start();
    try failed.fail(.init("http", "listen", .unavailable, "bind failed", "AddressInUse"));
    try std.testing.expectEqual(State.failed, failed.snapshot().state);
    try std.testing.expectEqual(External.Class.unavailable, failed.snapshot().failure.?.class);
}

test "application lifecycle is available through its canonical managed layer" {
    const root = fx.kernel.Layer.mergeAll(.{ managerLayer(), signalLayer() });
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();
    try runtime.run(start());
    try runtime.run(ready());
    try std.testing.expect((try runtime.run(currentState())).readiness);
    try std.testing.expectEqual(ProcessSignal.none, try runtime.run(requestedSignalEffect()));
}

test "lifecycle evidence is secret safe and process signals latch outside handlers" {
    var evidence = Evidence.init(std.testing.allocator);
    defer evidence.deinit();
    var lifecycle = Manager.initWithEvidence(std.testing.allocator, &evidence);
    defer lifecycle.deinit();
    try lifecycle.start();
    try lifecycle.ready();
    try lifecycle.drain();
    try lifecycle.stop();
    try std.testing.expectEqual(@as(usize, 5), evidence.transitions.items.len);
    const json = try evidence.workbenchJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "forced-stop") == null);
    requestShutdownForTest(.terminate);
    try std.testing.expectEqual(ProcessSignal.terminate, requestedSignal());
    requestShutdownForTest(.none);
}
