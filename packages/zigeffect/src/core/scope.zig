const std = @import("std");
const result = @import("result.zig");
const causal_mod = @import("../services/causal.zig");
const runtime_signal_mod = @import("runtime_signal.zig");

pub const Allocator = std.mem.Allocator;
pub const FinalizerExit = result.FinalizerExit;
pub const CausalStore = causal_mod.CausalStore;
pub const CausalEvent = causal_mod.CausalEvent;
pub const CausalContextV2 = causal_mod.CausalContextV2;
pub const RuntimeSignalSink = runtime_signal_mod.RuntimeSignalSink;
pub const ScopeError = error{MissingScope};
pub const FinalizerRegistrationError = Allocator.Error || ScopeError;

pub const Scope = struct {
    const Finalizer = struct {
        state: ?*anyopaque,
        run: *const fn (?*anyopaque, FinalizerExit) ?[]const u8,
        resource_type: []const u8 = "",
        resource_id: ?u64 = null,
        acquired_event_id: ?u64 = null,
        /// Captured when the resource enters the scope. A later finalizer may
        /// run after the dynamic effect context has unwound, so it must not
        /// consult mutable process- or scope-wide "current lineage" state.
        causal_context: CausalContextV2 = .{},
    };

    allocator: Allocator,
    finalizers: std.ArrayList(Finalizer) = .empty,
    finalizer_failures: std.ArrayList([]const u8) = .empty,
    closed: bool = false,
    /// Captured at scope-close time so downstream events (e.g. a child fiber's
    /// `fiber_interrupted` whose interrupt was triggered by this scope's
    /// finalizers) can point their `cause_event_id` at the precise close event.
    /// Null before close.
    causal_closed_event_id: ?u64 = null,
    causal_store: ?*CausalStore = null,
    causal_run_id: ?u64 = null,
    causal_scope_id: ?u64 = null,
    causal_opened_event_id: ?u64 = null,
    causal_trace_id: ?u64 = null,
    causal_span_id: ?u64 = null,
    causal_context: CausalContextV2 = .{},
    runtime_signal: ?RuntimeSignalSink = null,

    pub fn attachRuntimeSignal(
        self: *Scope,
        sink: RuntimeSignalSink,
        run_id: u64,
        parent_id: ?u64,
        trace_id: ?u64,
        span_id: ?u64,
    ) void {
        self.runtime_signal = sink;
        self.causal_run_id = run_id;
        self.causal_trace_id = trace_id;
        self.causal_span_id = span_id;
        self.causal_scope_id = self.causal_scope_id orelse sink.nextScopeId();
        self.causal_opened_event_id = self.causal_opened_event_id orelse self.recordLifecycle(.{
            .kind = .scope_opened,
            .parent_id = parent_id,
            .status = "open",
        });
    }

    pub fn init(allocator: Allocator) Scope {
        return .{ .allocator = allocator };
    }

    pub fn attachCausal(
        self: *Scope,
        store: *CausalStore,
        run_id: u64,
        parent_id: ?u64,
        trace_id: ?u64,
        span_id: ?u64,
    ) void {
        self.causal_store = store;
        self.causal_run_id = run_id;
        self.causal_trace_id = trace_id;
        self.causal_span_id = span_id;
        self.causal_scope_id = self.causal_scope_id orelse store.nextScopeId();
        self.causal_opened_event_id = self.causal_opened_event_id orelse self.recordLifecycle(.{
            .kind = .scope_opened,
            .parent_id = parent_id,
            .status = "open",
        });
    }

    pub fn setCausalContext(self: *Scope, context: CausalContextV2) void {
        self.causal_context = CausalContextV2.merge(self.causal_context, context);
    }

    fn recordLifecycleWithContext(
        self: *Scope,
        event: CausalEvent,
        captured_context: CausalContextV2,
    ) ?u64 {
        var owned = event;
        owned.run_id = owned.run_id orelse self.causal_run_id;
        owned.scope_id = owned.scope_id orelse self.causal_scope_id;
        owned.trace_id = owned.trace_id orelse self.causal_trace_id;
        owned.span_id = owned.span_id orelse self.causal_span_id;
        owned.context = CausalContextV2.merge(
            self.causal_context,
            CausalContextV2.merge(captured_context, owned.context),
        );
        owned.context.trace_id_low = owned.context.trace_id_low orelse owned.trace_id;
        owned.context.span_id = owned.context.span_id orelse owned.span_id;
        if (self.runtime_signal) |sink| {
            const kind: runtime_signal_mod.RuntimeEventKind = switch (owned.kind) {
                .scope_opened => .scope_opened,
                .scope_closed => .scope_closed,
                .resource_acquired => .resource_acquired,
                .resource_finalized => .resource_finalized,
                else => return null,
            };
            return sink.emit(.{
                .kind = kind,
                .run_id = owned.run_id,
                .parent_id = owned.parent_id,
                .scope_id = owned.scope_id,
                .resource_id = owned.resource_id,
                .cause_event_id = owned.cause_event_id,
                .trace_id = owned.trace_id,
                .span_id = owned.span_id,
                .context = owned.context,
                .label = owned.label,
                .type_name = owned.type_name,
                .status = owned.status,
                .redacted_detail = owned.redacted_detail,
            });
        }
        const store = self.causal_store orelse return null;
        return store.record(owned) catch null;
    }

    fn recordLifecycle(self: *Scope, event: CausalEvent) ?u64 {
        return self.recordLifecycleWithContext(event, .{});
    }

    fn finalizerExitStatus(exit: FinalizerExit) []const u8 {
        return switch (exit) {
            .success => "success",
            .failure => "failure",
            .defect => "defect",
            .interrupted => "interrupted",
            .cause => "cause",
        };
    }

    fn finalizerExitDetail(exit: FinalizerExit) []const u8 {
        return switch (exit) {
            .success => "",
            .failure => |name| name,
            .defect => |message| message,
            .interrupted => "",
            .cause => |name| name,
        };
    }

    fn recordResourceAcquired(self: *Scope, finalizer: *Finalizer) void {
        if (finalizer.resource_type.len == 0) return;
        const resource_id = if (self.runtime_signal) |sink|
            sink.nextResourceId()
        else if (self.causal_store) |store|
            store.nextResourceId()
        else
            return;
        finalizer.resource_id = finalizer.resource_id orelse resource_id;
        finalizer.acquired_event_id = self.recordLifecycleWithContext(.{
            .kind = .resource_acquired,
            .parent_id = self.causal_opened_event_id,
            .resource_id = finalizer.resource_id,
            .type_name = finalizer.resource_type,
            .status = "success",
        }, finalizer.causal_context);
    }

    fn recordResourceFinalized(self: *Scope, finalizer: Finalizer, failure: ?[]const u8) void {
        if (finalizer.resource_type.len == 0) return;
        _ = self.recordLifecycleWithContext(.{
            .kind = .resource_finalized,
            .parent_id = finalizer.acquired_event_id orelse self.causal_opened_event_id,
            .resource_id = finalizer.resource_id,
            .cause_event_id = if (failure == null) null else finalizer.acquired_event_id,
            .type_name = finalizer.resource_type,
            .status = if (failure == null) "success" else "failure",
            .redacted_detail = failure orelse "",
        }, finalizer.causal_context);
    }

    fn recordScopeClosed(self: *Scope, exit: FinalizerExit) void {
        // Capture the close event id on the scope so finalizer-triggered
        // interrupts on child fibers can point their cause_event_id at the
        // precise scope_closed (instead of falling back to fiber_forked).
        const close_id = self.recordLifecycle(.{
            .kind = .scope_closed,
            .parent_id = self.causal_opened_event_id,
            .status = finalizerExitStatus(exit),
            .redacted_detail = finalizerExitDetail(exit),
        });
        self.causal_closed_event_id = close_id;
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
        return self.addFinalizerForWithContext(Resource, resource, release, self.causal_context);
    }

    pub fn addFinalizerForWithContext(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: *const fn (*Resource) void,
        causal_context: CausalContextV2,
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
            .resource_type = @typeName(Resource),
            .causal_context = causal_context,
        });
        self.recordResourceAcquired(&self.finalizers.items[self.finalizers.items.len - 1]);
    }

    pub fn addFinalizerFallibleFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: anytype,
    ) Allocator.Error!void {
        return self.addFinalizerFallibleForWithContext(Resource, resource, release, self.causal_context);
    }

    pub fn addFinalizerFallibleForWithContext(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: anytype,
        causal_context: CausalContextV2,
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
            .resource_type = @typeName(Resource),
            .causal_context = causal_context,
        });
        self.recordResourceAcquired(&self.finalizers.items[self.finalizers.items.len - 1]);
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
        return self.addFinalizerExitForWithContext(Resource, resource, release, self.causal_context);
    }

    pub fn addFinalizerExitForWithContext(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: *const fn (*Resource, FinalizerExit) void,
        causal_context: CausalContextV2,
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
            .resource_type = @typeName(Resource),
            .causal_context = causal_context,
        });
        self.recordResourceAcquired(&self.finalizers.items[self.finalizers.items.len - 1]);
    }

    pub fn addFinalizerExitFallibleFor(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: anytype,
    ) Allocator.Error!void {
        return self.addFinalizerExitFallibleForWithContext(Resource, resource, release, self.causal_context);
    }

    pub fn addFinalizerExitFallibleForWithContext(
        self: *Scope,
        comptime Resource: type,
        resource: *Resource,
        comptime release: anytype,
        causal_context: CausalContextV2,
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
            .resource_type = @typeName(Resource),
            .causal_context = causal_context,
        });
        self.recordResourceAcquired(&self.finalizers.items[self.finalizers.items.len - 1]);
    }

    pub fn close(self: *Scope) void {
        self.closeWithExit(.success);
    }

    pub fn closeWithExit(self: *Scope, exit: FinalizerExit) void {
        if (self.closed) return;
        // H7a — record `scope_closed` BEFORE running finalizers so that
        // finalizer-triggered events (e.g. a child fiber being interrupted as
        // its parent scope cancels) can point their cause_event_id at the real
        // scope_closed. This is also the logically correct order: the scope
        // was closed first, finalizers are the consequences.
        self.recordScopeClosed(exit);
        while (self.finalizers.items.len > 0) {
            const index = self.finalizers.items.len - 1;
            const finalizer = self.finalizers.items[index];
            self.finalizers.items.len = index;
            const failure = finalizer.run(finalizer.state, exit);
            self.recordResourceFinalized(finalizer, failure);
            if (failure) |name| {
                self.finalizer_failures.append(self.allocator, name) catch {};
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
