const std = @import("std");
const causal = @import("causal.zig");

pub const causal_app_runtime_schema = "zigeffect.causal.app-runtime.v1";
pub const causal_app_runtime_schema_version: u32 = 1;
pub const default_request_max_events: usize = 256;
pub const default_job_max_events: usize = 1024;
pub const default_app_max_event_string_bytes: usize = 256;

pub const CausalAppTraceKind = enum {
    request,
    background_job,
};

pub const CausalAppStatus = enum {
    started,
    success,
    failure,
    cancelled,
};

pub const CausalAppTraceOptions = struct {
    method: []const u8 = "",
    route: []const u8 = "",
    job_name: []const u8 = "",
    runtime: []const u8 = "",
    trace_id: ?u64 = null,
};

pub fn defaultRequestCausalStoreOptions() causal.CausalStoreOptions {
    return .{
        .max_events = default_request_max_events,
        .max_event_string_bytes = default_app_max_event_string_bytes,
    };
}

pub fn defaultJobCausalStoreOptions() causal.CausalStoreOptions {
    return .{
        .max_events = default_job_max_events,
        .max_event_string_bytes = default_app_max_event_string_bytes,
    };
}

pub const CausalAppTrace = struct {
    store: *causal.CausalStore,
    kind: CausalAppTraceKind,
    options: CausalAppTraceOptions,
    run_id: u64,
    root_event_id: u64,
    last_scope_id: ?u64 = null,
    last_scope_label: []const u8 = "",
    completed: bool = false,

    pub fn startRequest(store: *causal.CausalStore, options: CausalAppTraceOptions) std.mem.Allocator.Error!CausalAppTrace {
        var trace = CausalAppTrace{
            .store = store,
            .kind = .request,
            .options = options,
            .run_id = store.nextRunId(),
            .root_event_id = 0,
        };
        trace.root_event_id = try trace.recordRoot(.run_started, .started);
        return trace;
    }

    pub fn startJob(store: *causal.CausalStore, options: CausalAppTraceOptions) std.mem.Allocator.Error!CausalAppTrace {
        var trace = CausalAppTrace{
            .store = store,
            .kind = .background_job,
            .options = options,
            .run_id = store.nextRunId(),
            .root_event_id = 0,
        };
        trace.root_event_id = try trace.recordRoot(.run_started, .started);
        return trace;
    }

    pub fn complete(self: *CausalAppTrace, status: CausalAppStatus) std.mem.Allocator.Error!void {
        _ = try self.recordRoot(.run_completed, status);
        self.completed = true;
    }

    pub fn recordServiceResolution(
        self: *CausalAppTrace,
        service_name: []const u8,
        status: []const u8,
    ) std.mem.Allocator.Error!void {
        _ = try self.record(.{
            .kind = .service_required,
            .label = service_name,
            .type_name = "zigeffect.app.service",
            .status = status,
        });
    }

    pub fn recordLayerConstruction(
        self: *CausalAppTrace,
        layer_name: []const u8,
        status: []const u8,
    ) std.mem.Allocator.Error!void {
        const kind: causal.CausalEventKind = if (std.mem.eql(u8, status, "started"))
            .layer_started
        else
            .layer_completed;
        _ = try self.record(.{
            .kind = kind,
            .label = layer_name,
            .type_name = "zigeffect.app.layer",
            .status = status,
        });
    }

    pub fn openScope(self: *CausalAppTrace, label: []const u8) std.mem.Allocator.Error!u64 {
        const scope_id = self.store.nextScopeId();
        _ = try self.record(.{
            .kind = .scope_opened,
            .scope_id = scope_id,
            .label = label,
            .type_name = "zigeffect.app.scope",
            .status = "opened",
        });
        self.last_scope_id = scope_id;
        self.last_scope_label = label;
        return scope_id;
    }

    pub fn closeScope(
        self: *CausalAppTrace,
        scope_id: u64,
        status: []const u8,
    ) std.mem.Allocator.Error!void {
        const label = if (self.last_scope_id != null and self.last_scope_id.? == scope_id)
            self.last_scope_label
        else
            "";
        _ = try self.record(.{
            .kind = .scope_closed,
            .scope_id = scope_id,
            .label = label,
            .type_name = "zigeffect.app.scope",
            .status = status,
        });
    }

    pub fn recordResourceAcquired(
        self: *CausalAppTrace,
        label: []const u8,
        scope_id: u64,
    ) std.mem.Allocator.Error!void {
        _ = try self.record(.{
            .kind = .resource_acquired,
            .scope_id = scope_id,
            .label = label,
            .type_name = label,
            .status = "success",
        });
    }

    pub fn recordResourceFinalized(
        self: *CausalAppTrace,
        label: []const u8,
        scope_id: u64,
        status: []const u8,
    ) std.mem.Allocator.Error!void {
        _ = try self.record(.{
            .kind = .resource_finalized,
            .scope_id = scope_id,
            .label = label,
            .type_name = label,
            .status = status,
        });
    }

    pub fn recordFiberStatus(
        self: *CausalAppTrace,
        label: []const u8,
        fiber_id: u64,
        status: CausalAppStatus,
    ) std.mem.Allocator.Error!void {
        const kind: causal.CausalEventKind = switch (status) {
            .started => .fiber_started,
            .success => .fiber_joined,
            .failure, .cancelled => .fiber_interrupted,
        };
        _ = try self.record(.{
            .kind = kind,
            .fiber_id = fiber_id,
            .label = label,
            .type_name = "zigeffect.app.fiber",
            .status = @tagName(status),
        });
    }

    pub fn recordRetryAttempt(
        self: *CausalAppTrace,
        label: []const u8,
        attempt: u32,
        max_attempts: u32,
        status: []const u8,
    ) std.mem.Allocator.Error!void {
        const detail = try std.fmt.allocPrint(
            self.store.allocator,
            "attempt={d} max_attempts={d}",
            .{ attempt, max_attempts },
        );
        defer self.store.allocator.free(detail);
        _ = try self.record(.{
            .kind = .schedule_decision,
            .label = label,
            .type_name = "zigeffect.app.retry",
            .status = status,
            .redacted_detail = detail,
        });
    }

    pub fn recordConfigFailure(
        self: *CausalAppTrace,
        key: []const u8,
        error_name: []const u8,
    ) std.mem.Allocator.Error!void {
        _ = try self.record(.{
            .kind = .assertion_recorded,
            .label = key,
            .type_name = error_name,
            .status = "failure",
            .redacted_detail = "app.config.required",
        });
    }

    pub fn recordRequirementFailure(
        self: *CausalAppTrace,
        name: []const u8,
        error_name: []const u8,
    ) std.mem.Allocator.Error!void {
        _ = try self.record(.{
            .kind = .assertion_recorded,
            .label = name,
            .type_name = error_name,
            .status = "failure",
            .redacted_detail = "app.requirement.required",
        });
    }

    fn recordRoot(
        self: *CausalAppTrace,
        event_kind: causal.CausalEventKind,
        status: CausalAppStatus,
    ) std.mem.Allocator.Error!u64 {
        const label = try self.formatRootLabel();
        defer self.store.allocator.free(label);
        const detail = try self.formatRootDetail();
        defer self.store.allocator.free(detail);
        return self.store.record(.{
            .kind = event_kind,
            .run_id = self.run_id,
            .parent_id = if (event_kind == .run_completed) self.root_event_id else null,
            .trace_id = self.options.trace_id,
            .label = label,
            .type_name = switch (self.kind) {
                .request => "zigeffect.app.request",
                .background_job => "zigeffect.app.job",
            },
            .status = @tagName(status),
            .redacted_detail = detail,
        });
    }

    fn record(self: *CausalAppTrace, event: causal.CausalEvent) std.mem.Allocator.Error!u64 {
        var app_event = event;
        app_event.run_id = app_event.run_id orelse self.run_id;
        app_event.parent_id = app_event.parent_id orelse self.root_event_id;
        app_event.trace_id = app_event.trace_id orelse self.options.trace_id;
        return self.store.record(app_event);
    }

    fn formatRootLabel(self: *const CausalAppTrace) std.mem.Allocator.Error![]const u8 {
        return switch (self.kind) {
            .request => std.fmt.allocPrint(
                self.store.allocator,
                "app.request {s} {s}",
                .{ self.options.method, self.options.route },
            ),
            .background_job => std.fmt.allocPrint(
                self.store.allocator,
                "app.job {s}",
                .{self.options.job_name},
            ),
        };
    }

    fn formatRootDetail(self: *const CausalAppTrace) std.mem.Allocator.Error![]const u8 {
        return switch (self.kind) {
            .request => std.fmt.allocPrint(
                self.store.allocator,
                "schema={s} schema_version={d} method={s} route={s} runtime={s}",
                .{
                    causal_app_runtime_schema,
                    causal_app_runtime_schema_version,
                    self.options.method,
                    self.options.route,
                    self.options.runtime,
                },
            ),
            .background_job => std.fmt.allocPrint(
                self.store.allocator,
                "schema={s} schema_version={d} job={s} runtime={s}",
                .{
                    causal_app_runtime_schema,
                    causal_app_runtime_schema_version,
                    self.options.job_name,
                    self.options.runtime,
                },
            ),
        };
    }
};
