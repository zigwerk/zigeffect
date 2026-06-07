const std = @import("std");
const causal_backend = @import("causal_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalBackend = causal_backend.CausalBackend;
pub const causal_json_schema = "zigeffect.causal.v1";
pub const causal_json_schema_version: u32 = 1;

pub const CausalStoreOptions = struct {
    max_events: ?usize = null,
};

pub const CausalEventKind = enum {
    run_started,
    run_completed,
    effect_started,
    effect_completed,
    layer_started,
    layer_completed,
    service_required,
    service_provided,
    service_replaced,
    scope_opened,
    scope_closed,
    resource_acquired,
    resource_finalized,
    fiber_forked,
    fiber_started,
    fiber_joined,
    fiber_interrupted,
    schedule_decision,
    exit_recorded,
    log_recorded,
    metric_recorded,
    span_recorded,
    assertion_recorded,
};

pub const CausalEvent = struct {
    id: u64 = 0,
    kind: CausalEventKind,
    run_id: ?u64 = null,
    parent_id: ?u64 = null,
    fiber_id: ?u64 = null,
    scope_id: ?u64 = null,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    label: []const u8 = "",
    type_name: []const u8 = "",
    status: []const u8 = "",
    redacted_detail: []const u8 = "",
};

fn cloneSlice(allocator: Allocator, value: []const u8) Allocator.Error![]const u8 {
    if (value.len == 0) return "";
    return allocator.dupe(u8, value);
}

fn cloneEvent(allocator: Allocator, event: CausalEvent) Allocator.Error!CausalEvent {
    var owned = event;
    owned.label = try cloneSlice(allocator, event.label);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try cloneSlice(allocator, event.type_name);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
    owned.status = try cloneSlice(allocator, event.status);
    errdefer if (owned.status.len > 0) allocator.free(owned.status);
    owned.redacted_detail = try cloneSlice(allocator, event.redacted_detail);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    return owned;
}

fn deinitEventStrings(allocator: Allocator, event: CausalEvent) void {
    if (event.label.len > 0) allocator.free(event.label);
    if (event.type_name.len > 0) allocator.free(event.type_name);
    if (event.status.len > 0) allocator.free(event.status);
    if (event.redacted_detail.len > 0) allocator.free(event.redacted_detail);
}

pub const CausalSnapshot = struct {
    allocator: Allocator,
    events: []CausalEvent,

    pub fn deinit(self: *CausalSnapshot) void {
        for (self.events) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.allocator.free(self.events);
    }
};

pub const CausalLineage = struct {
    allocator: Allocator,
    events: []CausalEvent,

    pub fn deinit(self: *CausalLineage) void {
        for (self.events) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.allocator.free(self.events);
    }
};

pub const CausalFindingKind = enum {
    resource_acquired_without_finalization,
    fiber_pending_after_scope_close,
    finalizer_failure,
    retry_budget_exhausted,
    service_requirement_without_provider,
    assertion_failure,
};

pub const CausalFinding = struct {
    kind: CausalFindingKind,
    event_id: u64,
    run_id: ?u64 = null,
    scope_id: ?u64 = null,
    fiber_id: ?u64 = null,
    label: []const u8 = "",
    type_name: []const u8 = "",
    redacted_detail: []const u8 = "",
};

fn cloneFinding(allocator: Allocator, finding: CausalFinding) Allocator.Error!CausalFinding {
    var owned = finding;
    owned.label = try cloneSlice(allocator, finding.label);
    errdefer if (owned.label.len > 0) allocator.free(owned.label);
    owned.type_name = try cloneSlice(allocator, finding.type_name);
    errdefer if (owned.type_name.len > 0) allocator.free(owned.type_name);
    owned.redacted_detail = try cloneSlice(allocator, finding.redacted_detail);
    errdefer if (owned.redacted_detail.len > 0) allocator.free(owned.redacted_detail);
    return owned;
}

fn deinitFindingStrings(allocator: Allocator, finding: CausalFinding) void {
    if (finding.label.len > 0) allocator.free(finding.label);
    if (finding.type_name.len > 0) allocator.free(finding.type_name);
    if (finding.redacted_detail.len > 0) allocator.free(finding.redacted_detail);
}

pub const CausalFindings = struct {
    allocator: Allocator,
    items: []CausalFinding,

    pub fn deinit(self: *CausalFindings) void {
        for (self.items) |finding| {
            deinitFindingStrings(self.allocator, finding);
        }
        self.allocator.free(self.items);
    }
};

pub const CausalStore = struct {
    allocator: Allocator,
    next_event_id: u64 = 1,
    next_run_id_value: u64 = 1,
    next_scope_id_value: u64 = 1,
    events: std.ArrayList(CausalEvent) = .empty,
    backend: ?CausalBackend = null,
    max_events: ?usize = null,
    dropped_event_count: u64 = 0,

    pub fn init(allocator: Allocator) CausalStore {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: Allocator, options: CausalStoreOptions) CausalStore {
        return .{
            .allocator = allocator,
            .max_events = options.max_events,
        };
    }

    pub fn initBounded(allocator: Allocator, max_events: usize) CausalStore {
        return initWithOptions(allocator, .{ .max_events = max_events });
    }

    pub fn deinit(self: *CausalStore) void {
        for (self.events.items) |event| {
            deinitEventStrings(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    pub fn attachBackend(self: *CausalStore, backend: CausalBackend) void {
        self.backend = backend;
    }

    pub fn droppedEventCount(self: *const CausalStore) u64 {
        return self.dropped_event_count;
    }

    pub fn oldestRetainedEventId(self: *const CausalStore) ?u64 {
        if (self.events.items.len == 0) return null;
        return self.events.items[0].id;
    }

    pub fn nextRunId(self: *CausalStore) u64 {
        const id = self.next_run_id_value;
        self.next_run_id_value += 1;
        return id;
    }

    pub fn nextScopeId(self: *CausalStore) u64 {
        const id = self.next_scope_id_value;
        self.next_scope_id_value += 1;
        return id;
    }

    pub fn record(self: *CausalStore, event: CausalEvent) Allocator.Error!u64 {
        var owned = try cloneEvent(self.allocator, event);
        errdefer deinitEventStrings(self.allocator, owned);
        owned.id = self.next_event_id;
        self.next_event_id += 1;
        try self.events.append(self.allocator, owned);
        if (self.backend) |backend| {
            backend.record(backend.state, owned) catch {};
        }
        self.trimRetainedEvents();
        return owned.id;
    }

    pub fn snapshot(self: *const CausalStore, allocator: Allocator) Allocator.Error!CausalSnapshot {
        const events = try allocator.alloc(CausalEvent, self.events.items.len);
        errdefer allocator.free(events);

        var initialized: usize = 0;
        errdefer {
            for (events[0..initialized]) |event| {
                deinitEventStrings(allocator, event);
            }
        }

        for (self.events.items, 0..) |event, index| {
            events[index] = try cloneEvent(allocator, event);
            initialized += 1;
        }

        return .{ .allocator = allocator, .events = events };
    }

    pub fn lineage(self: *const CausalStore, allocator: Allocator, event_id: u64) Allocator.Error!CausalLineage {
        var output = std.ArrayList(CausalEvent).empty;
        errdefer {
            for (output.items) |event| {
                deinitEventStrings(allocator, event);
            }
            output.deinit(allocator);
        }

        for (self.events.items) |event| {
            if (event.id == event_id or event.parent_id == event_id) {
                {
                    const cloned = try cloneEvent(allocator, event);
                    errdefer deinitEventStrings(allocator, cloned);
                    try output.append(allocator, cloned);
                }
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn cause(self: *const CausalStore, allocator: Allocator, event_id: u64) Allocator.Error!CausalLineage {
        var output = std.ArrayList(CausalEvent).empty;
        errdefer {
            for (output.items) |event| {
                deinitEventStrings(allocator, event);
            }
            output.deinit(allocator);
        }

        try self.appendCauseChain(allocator, &output, event_id);

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    pub fn resources(self: *const CausalStore, allocator: Allocator, scope_id: u64) Allocator.Error!CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: CausalEvent, expected_scope_id: u64) bool {
                return event.scope_id == expected_scope_id and
                    (event.kind == .resource_acquired or event.kind == .resource_finalized);
            }
        }.matches, scope_id);
    }

    pub fn fibers(self: *const CausalStore, allocator: Allocator, status: ?[]const u8) Allocator.Error!CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: CausalEvent, expected_status: ?[]const u8) bool {
                const fiber_event = switch (event.kind) {
                    .fiber_forked, .fiber_started, .fiber_joined, .fiber_interrupted => true,
                    else => false,
                };
                if (!fiber_event) return false;
                if (expected_status) |value| return std.mem.eql(u8, event.status, value);
                return true;
            }
        }.matches, status);
    }

    pub fn requirements(self: *const CausalStore, allocator: Allocator, run_id: u64) Allocator.Error!CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: CausalEvent, expected_run_id: u64) bool {
                return event.run_id == expected_run_id and event.kind == .service_required;
            }
        }.matches, run_id);
    }

    pub fn retries(self: *const CausalStore, allocator: Allocator, run_id: u64) Allocator.Error!CausalSnapshot {
        return self.filterEvents(allocator, struct {
            fn matches(event: CausalEvent, expected_run_id: u64) bool {
                return event.run_id == expected_run_id and event.kind == .schedule_decision;
            }
        }.matches, run_id);
    }

    pub fn findings(self: *const CausalStore, allocator: Allocator) Allocator.Error!CausalFindings {
        var output = std.ArrayList(CausalFinding).empty;
        errdefer {
            for (output.items) |finding| {
                deinitFindingStrings(allocator, finding);
            }
            output.deinit(allocator);
        }

        for (self.events.items) |event| {
            switch (event.kind) {
                .resource_acquired => if (!self.hasFinalizedResource(event)) {
                    try appendFinding(allocator, &output, .resource_acquired_without_finalization, event);
                },
                .scope_closed => try self.appendPendingFiberFindings(allocator, &output, event),
                .resource_finalized => if (std.mem.eql(u8, event.status, "failure")) {
                    try appendFinding(allocator, &output, .finalizer_failure, event);
                },
                .schedule_decision => if (std.mem.eql(u8, event.status, "exhausted")) {
                    try appendFinding(allocator, &output, .retry_budget_exhausted, event);
                },
                .service_required => if (std.mem.eql(u8, event.status, "missing")) {
                    try appendFinding(allocator, &output, .service_requirement_without_provider, event);
                },
                .assertion_recorded => if (std.mem.eql(u8, event.status, "failure")) {
                    try appendFinding(allocator, &output, .assertion_failure, event);
                },
                else => {},
            }
        }

        return .{ .allocator = allocator, .items = try output.toOwnedSlice(allocator) };
    }

    fn findEvent(self: *const CausalStore, event_id: u64) ?CausalEvent {
        for (self.events.items) |event| {
            if (event.id == event_id) return event;
        }
        return null;
    }

    fn trimRetainedEvents(self: *CausalStore) void {
        const max_events = self.max_events orelse return;
        while (self.events.items.len > max_events) {
            const dropped = self.events.orderedRemove(0);
            deinitEventStrings(self.allocator, dropped);
            self.dropped_event_count += 1;
        }
    }

    fn appendCauseChain(self: *const CausalStore, allocator: Allocator, output: *std.ArrayList(CausalEvent), event_id: u64) Allocator.Error!void {
        const event = self.findEvent(event_id) orelse return;
        if (event.parent_id) |parent_id| {
            try self.appendCauseChain(allocator, output, parent_id);
        }
        try appendClonedEvent(allocator, output, event);
    }

    fn filterEvents(
        self: *const CausalStore,
        allocator: Allocator,
        comptime matches: anytype,
        expected: anytype,
    ) Allocator.Error!CausalSnapshot {
        var output = std.ArrayList(CausalEvent).empty;
        errdefer {
            for (output.items) |event| {
                deinitEventStrings(allocator, event);
            }
            output.deinit(allocator);
        }

        for (self.events.items) |event| {
            if (matches(event, expected)) {
                try appendClonedEvent(allocator, &output, event);
            }
        }

        return .{ .allocator = allocator, .events = try output.toOwnedSlice(allocator) };
    }

    fn hasFinalizedResource(self: *const CausalStore, acquired: CausalEvent) bool {
        for (self.events.items) |event| {
            if (event.kind != .resource_finalized) continue;
            if (event.scope_id != acquired.scope_id) continue;
            if (!std.mem.eql(u8, event.type_name, acquired.type_name)) continue;
            return true;
        }
        return false;
    }

    fn fiberCompletedAfter(self: *const CausalStore, fiber_id: u64, closed_event_id: u64) bool {
        for (self.events.items) |event| {
            if (event.id < closed_event_id) continue;
            if (event.fiber_id != fiber_id) continue;
            switch (event.kind) {
                .fiber_joined, .fiber_interrupted => return true,
                else => {},
            }
        }
        return false;
    }

    fn appendPendingFiberFindings(
        self: *const CausalStore,
        allocator: Allocator,
        output: *std.ArrayList(CausalFinding),
        closed: CausalEvent,
    ) Allocator.Error!void {
        const scope_id = closed.scope_id orelse return;
        for (self.events.items) |event| {
            if (event.scope_id != scope_id) continue;
            if (event.fiber_id == null) continue;
            if (event.kind != .fiber_forked and event.kind != .fiber_started) continue;
            if (!std.mem.eql(u8, event.status, "pending") and !std.mem.eql(u8, event.status, "running")) continue;
            if (self.fiberCompletedAfter(event.fiber_id.?, closed.id)) continue;
            try appendFinding(allocator, output, .fiber_pending_after_scope_close, event);
        }
    }
};

fn appendClonedEvent(allocator: Allocator, output: *std.ArrayList(CausalEvent), event: CausalEvent) Allocator.Error!void {
    const cloned = try cloneEvent(allocator, event);
    errdefer deinitEventStrings(allocator, cloned);
    try output.append(allocator, cloned);
}

fn appendFinding(
    allocator: Allocator,
    output: *std.ArrayList(CausalFinding),
    kind: CausalFindingKind,
    event: CausalEvent,
) Allocator.Error!void {
    const finding = try cloneFinding(allocator, .{
        .kind = kind,
        .event_id = event.id,
        .run_id = event.run_id,
        .scope_id = event.scope_id,
        .fiber_id = event.fiber_id,
        .label = event.label,
        .type_name = event.type_name,
        .redacted_detail = event.redacted_detail,
    });
    errdefer deinitFindingStrings(allocator, finding);
    try output.append(allocator, finding);
}

fn appendOptionalU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendRetentionSummary(output: *std.ArrayList(u8), allocator: Allocator, store: *const CausalStore) Allocator.Error!void {
    try output.appendSlice(allocator, "retention: max_events=");
    if (store.max_events) |max_events| {
        try output.print(allocator, "{d}", .{max_events});
    } else {
        try output.appendSlice(allocator, "unbounded");
    }
    try output.print(allocator, " dropped_events={d} oldest_retained_event=", .{store.dropped_event_count});
    try appendOptionalU64(output, allocator, store.oldestRetainedEventId());
    try output.append(allocator, '\n');
}

pub fn formatCausalReport(
    allocator: Allocator,
    label: []const u8,
    store: *const CausalStore,
) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "zigeffect causal report\nprogram: {s}\n", .{label});
    try output.print(allocator, "events: {d}\n", .{store.events.items.len});
    try appendRetentionSummary(&output, allocator, store);

    for (store.events.items) |event| {
        try output.print(
            allocator,
            "event: id={d} kind={s} run=",
            .{ event.id, @tagName(event.kind) },
        );
        try appendOptionalU64(&output, allocator, event.run_id);
        try output.appendSlice(allocator, " parent=");
        try appendOptionalU64(&output, allocator, event.parent_id);
        if (event.fiber_id != null) {
            try output.appendSlice(allocator, " fiber=");
            try appendOptionalU64(&output, allocator, event.fiber_id);
        }
        if (event.scope_id != null) {
            try output.appendSlice(allocator, " scope=");
            try appendOptionalU64(&output, allocator, event.scope_id);
        }
        if (event.trace_id != null) {
            try output.appendSlice(allocator, " trace=");
            try appendOptionalU64(&output, allocator, event.trace_id);
        }
        if (event.span_id != null) {
            try output.appendSlice(allocator, " span=");
            try appendOptionalU64(&output, allocator, event.span_id);
        }
        if (event.label.len > 0) try output.print(allocator, " label={s}", .{event.label});
        if (event.type_name.len > 0) try output.print(allocator, " type={s}", .{event.type_name});
        if (event.status.len > 0) try output.print(allocator, " status={s}", .{event.status});
        if (event.redacted_detail.len > 0) try output.print(allocator, " detail={s}", .{event.redacted_detail});
        try output.appendSlice(allocator, "\n");
    }

    return output.toOwnedSlice(allocator);
}

fn appendCiEventSummary(output: *std.ArrayList(u8), allocator: Allocator, event: CausalEvent) Allocator.Error!void {
    try output.print(
        allocator,
        "- event id={d} kind={s}",
        .{ event.id, @tagName(event.kind) },
    );
    if (event.run_id) |run_id| try output.print(allocator, " run={d}", .{run_id});
    if (event.scope_id) |scope_id| try output.print(allocator, " scope={d}", .{scope_id});
    if (event.fiber_id) |fiber_id| try output.print(allocator, " fiber={d}", .{fiber_id});
    if (event.label.len > 0) try output.print(allocator, " label={s}", .{event.label});
    if (event.type_name.len > 0) try output.print(allocator, " type={s}", .{event.type_name});
    if (event.status.len > 0) try output.print(allocator, " status={s}", .{event.status});
    try output.appendSlice(allocator, "\n");
}

fn appendCiFinding(output: *std.ArrayList(u8), allocator: Allocator, finding: CausalFinding) Allocator.Error!void {
    try output.print(
        allocator,
        "- finding event={d} kind={s}",
        .{ finding.event_id, @tagName(finding.kind) },
    );
    if (finding.run_id) |run_id| try output.print(allocator, " run={d}", .{run_id});
    if (finding.scope_id) |scope_id| try output.print(allocator, " scope={d}", .{scope_id});
    if (finding.fiber_id) |fiber_id| try output.print(allocator, " fiber={d}", .{fiber_id});
    if (finding.label.len > 0) try output.print(allocator, " label={s}", .{finding.label});
    if (finding.type_name.len > 0) try output.print(allocator, " type={s}", .{finding.type_name});
    try output.appendSlice(allocator, "\n");
}

fn appendCiNextQueries(output: *std.ArrayList(u8), allocator: Allocator, finding: CausalFinding) Allocator.Error!void {
    try output.print(allocator, "- causal.cause {d}\n", .{finding.event_id});
    try output.print(allocator, "- causal.lineage {d}\n", .{finding.event_id});
    if (finding.scope_id) |scope_id| try output.print(allocator, "- causal.resources {d}\n", .{scope_id});
    if (finding.fiber_id != null) try output.appendSlice(allocator, "- causal.fibers pending\n");
    if (finding.run_id) |run_id| {
        switch (finding.kind) {
            .retry_budget_exhausted => try output.print(allocator, "- causal.retries {d}\n", .{run_id}),
            .service_requirement_without_provider => try output.print(allocator, "- causal.requirements {d}\n", .{run_id}),
            else => {},
        }
    }
}

pub fn formatCausalCiReport(
    allocator: Allocator,
    label: []const u8,
    store: *const CausalStore,
) Allocator.Error![]const u8 {
    var findings = try store.findings(allocator);
    defer findings.deinit();

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(
        allocator,
        "zigeffect causal ci report\nprogram: {s}\nevents: {d}\nfindings: {d}\n",
        .{ label, store.events.items.len, findings.items.len },
    );
    try appendRetentionSummary(&output, allocator, store);

    try output.appendSlice(allocator, "event citations:\n");
    if (store.events.items.len == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (store.events.items) |event| {
            try appendCiEventSummary(&output, allocator, event);
        }
    }

    try output.appendSlice(allocator, "findings detail:\n");
    if (findings.items.len == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (findings.items) |finding| {
            try appendCiFinding(&output, allocator, finding);
        }
    }

    try output.appendSlice(allocator, "next queries:\n");
    if (findings.items.len == 0) {
        try output.appendSlice(allocator, "- causal.snapshot\n");
    } else {
        for (findings.items) |finding| {
            try appendCiNextQueries(&output, allocator, finding);
        }
    }

    return output.toOwnedSlice(allocator);
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: Allocator, value: ?u64) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalJsonUsize(output: *std.ArrayList(u8), allocator: Allocator, value: ?usize) Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

pub fn formatCausalJson(allocator: Allocator, store: *const CausalStore) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n  \"schema\": ");
    try appendJsonString(&output, allocator, causal_json_schema);
    try output.print(allocator, ",\n  \"schema_version\": {d},\n", .{causal_json_schema_version});
    try output.appendSlice(allocator, "  \"retention\": {\n    \"max_events\": ");
    try appendOptionalJsonUsize(&output, allocator, store.max_events);
    try output.print(allocator, ",\n    \"dropped_events\": {d},\n    \"oldest_retained_event_id\": ", .{store.dropped_event_count});
    try appendOptionalJsonU64(&output, allocator, store.oldestRetainedEventId());
    try output.appendSlice(allocator, "\n  },\n  \"events\": [\n");
    for (store.events.items, 0..) |event, index| {
        if (index > 0) try output.appendSlice(allocator, ",\n");
        try output.appendSlice(allocator, "    {\n");
        try output.print(allocator, "      \"id\": {d},\n", .{event.id});
        try output.appendSlice(allocator, "      \"kind\": ");
        try appendJsonString(&output, allocator, @tagName(event.kind));
        try output.appendSlice(allocator, ",\n      \"run_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.run_id);
        try output.appendSlice(allocator, ",\n      \"parent_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.parent_id);
        try output.appendSlice(allocator, ",\n      \"fiber_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.fiber_id);
        try output.appendSlice(allocator, ",\n      \"scope_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.scope_id);
        try output.appendSlice(allocator, ",\n      \"trace_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.trace_id);
        try output.appendSlice(allocator, ",\n      \"span_id\": ");
        try appendOptionalJsonU64(&output, allocator, event.span_id);
        try output.appendSlice(allocator, ",\n      \"label\": ");
        try appendJsonString(&output, allocator, event.label);
        try output.appendSlice(allocator, ",\n      \"type_name\": ");
        try appendJsonString(&output, allocator, event.type_name);
        try output.appendSlice(allocator, ",\n      \"status\": ");
        try appendJsonString(&output, allocator, event.status);
        try output.appendSlice(allocator, ",\n      \"redacted_detail\": ");
        try appendJsonString(&output, allocator, event.redacted_detail);
        try output.appendSlice(allocator, "\n    }");
    }
    try output.appendSlice(allocator, "\n  ]\n}\n");

    return output.toOwnedSlice(allocator);
}

fn appendDotLabel(output: *std.ArrayList(u8), allocator: Allocator, event: CausalEvent) Allocator.Error!void {
    try output.append(allocator, '"');
    try output.appendSlice(allocator, @tagName(event.kind));
    if (event.label.len > 0) {
        try output.append(allocator, ' ');
        for (event.label) |byte| {
            switch (byte) {
                '"' => try output.appendSlice(allocator, "\\\""),
                '\\' => try output.appendSlice(allocator, "\\\\"),
                '\n', '\r', '\t' => try output.append(allocator, ' '),
                else => try output.append(allocator, byte),
            }
        }
    }
    try output.append(allocator, '"');
}

pub fn formatCausalDot(allocator: Allocator, store: *const CausalStore) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "digraph zigeffect_causal {\n");
    for (store.events.items) |event| {
        try output.print(allocator, "  event_{d} [label=", .{event.id});
        try appendDotLabel(&output, allocator, event);
        try output.appendSlice(allocator, "];\n");
    }
    for (store.events.items) |event| {
        if (event.parent_id) |parent_id| {
            try output.print(allocator, "  event_{d} -> event_{d};\n", .{ parent_id, event.id });
        }
    }
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}
