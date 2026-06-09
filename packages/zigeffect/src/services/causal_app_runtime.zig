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

pub const CausalAppIncidentKind = enum {
    missing_config,
    missing_requirement,
    failed_response,
    retry_exhausted,
    resource_leak,
    finalizer_failure,
    fiber_unresolved,
};

pub const CausalAppIncident = struct {
    kind: CausalAppIncidentKind,
    event_id: u64,
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
    label: []const u8 = "",
    type_name: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const CausalAppIncidents = struct {
    allocator: std.mem.Allocator,
    items: []CausalAppIncident,

    pub fn deinit(self: *CausalAppIncidents) void {
        for (self.items) |incident| {
            deinitIncidentStrings(self.allocator, incident);
        }
        self.allocator.free(self.items);
    }
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

pub fn deriveCausalAppIncidents(
    allocator: std.mem.Allocator,
    store: *const causal.CausalStore,
) std.mem.Allocator.Error!CausalAppIncidents {
    var output = std.ArrayList(CausalAppIncident).empty;
    errdefer {
        for (output.items) |incident| {
            deinitIncidentStrings(allocator, incident);
        }
        output.deinit(allocator);
    }

    for (store.events.items) |event| {
        const kind = classifyAppIncident(store.events.items, event) orelse continue;
        const incident = try cloneIncident(allocator, kind, event);
        errdefer deinitIncidentStrings(allocator, incident);
        try output.append(allocator, incident);
    }

    return .{ .allocator = allocator, .items = try output.toOwnedSlice(allocator) };
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

fn classifyAppIncident(events: []const causal.CausalEvent, event: causal.CausalEvent) ?CausalAppIncidentKind {
    if (isAppConfigFailure(event)) return .missing_config;
    if (isAppRequirementFailure(event)) return .missing_requirement;
    if (isAppResponseFailure(event)) return .failed_response;
    if (isAppRetryExhaustion(event)) return .retry_exhausted;
    if (isAppResourceAcquired(event) and !hasFinalizedResource(events, event)) return .resource_leak;
    if (isAppFinalizerFailure(event)) return .finalizer_failure;
    if (isAppFiberPending(event) and !hasResolvedFiber(events, event)) return .fiber_unresolved;
    return null;
}

fn isAppConfigFailure(event: causal.CausalEvent) bool {
    return event.kind == .assertion_recorded and
        std.mem.eql(u8, event.status, "failure") and
        (std.mem.eql(u8, event.redacted_detail, "app.config.required") or
            std.mem.eql(u8, event.label, "YACHDEE_ENV"));
}

fn isAppRequirementFailure(event: causal.CausalEvent) bool {
    return event.kind == .assertion_recorded and
        std.mem.eql(u8, event.status, "failure") and
        std.mem.eql(u8, event.redacted_detail, "app.requirement.required");
}

fn isAppResponseFailure(event: causal.CausalEvent) bool {
    return event.kind == .span_recorded and
        std.mem.eql(u8, event.type_name, "zigeffect.app.response") and
        std.mem.startsWith(u8, event.status, "5");
}

fn isAppRetryExhaustion(event: causal.CausalEvent) bool {
    return event.kind == .schedule_decision and
        std.mem.eql(u8, event.type_name, "zigeffect.app.retry") and
        std.mem.eql(u8, event.status, "exhausted");
}

fn isAppResourceAcquired(event: causal.CausalEvent) bool {
    return event.kind == .resource_acquired and isAppTypeName(event.type_name);
}

fn isAppFinalizerFailure(event: causal.CausalEvent) bool {
    return event.kind == .resource_finalized and
        std.mem.eql(u8, event.status, "failure") and
        isAppTypeName(event.type_name);
}

fn isAppFiberPending(event: causal.CausalEvent) bool {
    return (event.kind == .fiber_forked or event.kind == .fiber_started) and
        (std.mem.eql(u8, event.status, "pending") or std.mem.eql(u8, event.status, "running") or std.mem.eql(u8, event.status, "started")) and
        isAppTypeName(event.type_name);
}

fn isAppTypeName(type_name: []const u8) bool {
    return std.mem.startsWith(u8, type_name, "zigeffect.app.") or
        std.mem.startsWith(u8, type_name, "app ");
}

fn hasFinalizedResource(events: []const causal.CausalEvent, acquired: causal.CausalEvent) bool {
    for (events) |event| {
        if (event.kind != .resource_finalized) continue;
        if (event.scope_id != acquired.scope_id) continue;
        if (!std.mem.eql(u8, event.type_name, acquired.type_name)) continue;
        return true;
    }
    return false;
}

fn hasResolvedFiber(events: []const causal.CausalEvent, pending: causal.CausalEvent) bool {
    const fiber_id = pending.fiber_id orelse return false;
    for (events) |event| {
        if (event.id <= pending.id) continue;
        if (event.fiber_id != fiber_id) continue;
        if (event.kind == .fiber_joined or event.kind == .fiber_interrupted) return true;
    }
    return false;
}

fn cloneIncident(
    allocator: std.mem.Allocator,
    kind: CausalAppIncidentKind,
    event: causal.CausalEvent,
) std.mem.Allocator.Error!CausalAppIncident {
    var incident = CausalAppIncident{
        .kind = kind,
        .event_id = event.id,
        .run_id = event.run_id,
        .scope_id = event.scope_id,
        .fiber_id = event.fiber_id,
    };
    incident.label = try cloneSlice(allocator, event.label);
    errdefer if (incident.label.len > 0) allocator.free(incident.label);
    incident.type_name = try cloneSlice(allocator, event.type_name);
    errdefer if (incident.type_name.len > 0) allocator.free(incident.type_name);
    incident.redacted_detail = try cloneSlice(allocator, event.redacted_detail);
    errdefer if (incident.redacted_detail.len > 0) allocator.free(incident.redacted_detail);
    return incident;
}

fn cloneSlice(allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn deinitIncidentStrings(allocator: std.mem.Allocator, incident: CausalAppIncident) void {
    if (incident.label.len > 0) allocator.free(incident.label);
    if (incident.type_name.len > 0) allocator.free(incident.type_name);
    if (incident.redacted_detail.len > 0) allocator.free(incident.redacted_detail);
}
