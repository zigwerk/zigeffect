const std = @import("std");

pub const max_control_receipts: usize = 256;
pub const max_fleet_instances: usize = 512;
pub const control_receipt_schema = "zigeffect.statechart.control-receipt.v1";
pub const fleet_snapshot_schema = "zigeffect.statechart.fleet-snapshot.v1";

pub const ControlOperation = enum {
    inspect,
    start,
    signal,
    @"suspend",
    @"resume",
    cancel,
    retry,
    checkpoint,
    drain,
    restart,
    migrate,
};

pub const ControlDecision = enum { allow, deny, human_review };
pub const ControlStatus = enum { dry_run, applied, denied, stale, duplicate, failed };
pub const InstanceStatus = enum { pending, running, suspended, completed, failed, cancelled, stopped, draining, migrating };
pub const InstanceHealth = enum { healthy, degraded, stuck, failed, terminal };

pub const ControlError = error{
    InvalidControlRequest,
    ControlReceiptCapacityExceeded,
    FleetCapacityExceeded,
    InvalidFleetRecord,
    StaleFleetRecord,
};

pub fn ControlPlane(comptime Event: type) type {
    return struct {
        const Self = @This();

        pub const Request = struct {
            request_id: []const u8,
            machine_id: []const u8,
            instance_id: u64,
            operation: ControlOperation,
            expected_definition_fingerprint: u64,
            expected_fence_epoch: u64,
            reason: []const u8,
            dry_run: bool = false,
            event: ?Event = null,
            correlation_id: u64 = 0,
            trace_id: u64 = 0,
            boundary_id: u64 = 0,
        };

        pub const InstanceState = struct {
            definition_fingerprint: u64,
            fence_epoch: u64,
            status: InstanceStatus,
        };

        pub const Adapter = struct {
            context: *anyopaque,
            inspect_fn: *const fn (context: *anyopaque, instance_id: u64) anyerror!InstanceState,
            apply_fn: *const fn (context: *anyopaque, request: Request) anyerror!void,

            pub fn inspect(self: Adapter, instance_id: u64) anyerror!InstanceState {
                return self.inspect_fn(self.context, instance_id);
            }

            pub fn apply(self: Adapter, request: Request) anyerror!void {
                return self.apply_fn(self.context, request);
            }
        };

        pub const Policy = struct {
            context: *anyopaque,
            decide_fn: *const fn (context: *anyopaque, request: Request) ControlDecision,

            pub fn decide(self: Policy, request: Request) ControlDecision {
                return self.decide_fn(self.context, request);
            }
        };

        pub const Receipt = struct {
            schema: []const u8 = control_receipt_schema,
            schema_version: u32 = 1,
            request_id: []const u8,
            machine_id: []const u8,
            instance_id: u64,
            operation: ControlOperation,
            status: ControlStatus,
            decision: ControlDecision,
            observed_definition_fingerprint: u64,
            observed_fence_epoch: u64,
            request_fingerprint: u64,
            detail: []const u8,
            correlation_id: u64 = 0,
            trace_id: u64 = 0,
            boundary_id: u64 = 0,

            pub fn formatJsonAlloc(self: Receipt, allocator: std.mem.Allocator) ![]u8 {
                var output = std.ArrayList(u8).empty;
                errdefer output.deinit(allocator);
                try output.appendSlice(allocator, "{\"schema\":\"zigeffect.statechart.control-receipt.v1\",\"schema_version\":1,\"request_id\":");
                try appendJsonString(&output, allocator, self.request_id);
                try output.appendSlice(allocator, ",\"machine_id\":");
                try appendJsonString(&output, allocator, self.machine_id);
                try output.print(allocator, ",\"instance_id\":\"{d}\",\"operation\":\"{s}\",\"status\":\"{s}\",\"decision\":\"{s}\",\"observed_definition_fingerprint\":\"{d}\",\"observed_fence_epoch\":\"{d}\",\"request_fingerprint\":\"{d}\",\"detail\":", .{ self.instance_id, @tagName(self.operation), @tagName(self.status), @tagName(self.decision), self.observed_definition_fingerprint, self.observed_fence_epoch, self.request_fingerprint });
                try appendJsonString(&output, allocator, self.detail);
                try output.print(allocator, ",\"correlation_id\":\"{d}\",\"trace_id\":\"{d}\",\"boundary_id\":\"{d}\"}}", .{ self.correlation_id, self.trace_id, self.boundary_id });
                return output.toOwnedSlice(allocator);
            }
        };

        adapter: Adapter,
        policy: ?Policy = null,
        receipt_fingerprints: [max_control_receipts]u64 = undefined,
        receipt_count: usize = 0,

        pub fn init(adapter: Adapter) Self {
            return .{ .adapter = adapter };
        }

        pub fn execute(self: *Self, request: Request) anyerror!Receipt {
            try validateRequest(request);
            const fingerprint = requestFingerprint(request);
            for (self.receipt_fingerprints[0..self.receipt_count]) |existing| {
                if (existing == fingerprint) return .{
                    .request_id = request.request_id,
                    .machine_id = request.machine_id,
                    .instance_id = request.instance_id,
                    .operation = request.operation,
                    .status = .duplicate,
                    .decision = .deny,
                    .observed_definition_fingerprint = request.expected_definition_fingerprint,
                    .observed_fence_epoch = request.expected_fence_epoch,
                    .request_fingerprint = fingerprint,
                    .detail = "duplicate control request",
                    .correlation_id = request.correlation_id,
                    .trace_id = request.trace_id,
                    .boundary_id = request.boundary_id,
                };
            }
            if (self.receipt_count >= self.receipt_fingerprints.len) return error.ControlReceiptCapacityExceeded;
            self.receipt_fingerprints[self.receipt_count] = fingerprint;
            self.receipt_count += 1;

            const state = try self.adapter.inspect(request.instance_id);
            if (state.definition_fingerprint != request.expected_definition_fingerprint or
                state.fence_epoch != request.expected_fence_epoch)
            {
                return receipt(request, state, fingerprint, .stale, .deny, "definition fingerprint or fence epoch is stale");
            }

            const decision = if (self.policy) |policy| policy.decide(request) else .deny;
            if (decision != .allow) return receipt(
                request,
                state,
                fingerprint,
                .denied,
                decision,
                if (decision == .human_review) "human review required" else "control policy denied request",
            );
            if (request.dry_run) return receipt(request, state, fingerprint, .dry_run, decision, "validated dry run; no mutation performed");

            self.adapter.apply(request) catch {
                return receipt(request, state, fingerprint, .failed, decision, "runtime adapter failed");
            };
            return receipt(request, state, fingerprint, .applied, decision, "runtime control applied");
        }

        fn receipt(
            request: Request,
            state: InstanceState,
            fingerprint: u64,
            status: ControlStatus,
            decision: ControlDecision,
            detail: []const u8,
        ) Receipt {
            return .{
                .request_id = request.request_id,
                .machine_id = request.machine_id,
                .instance_id = request.instance_id,
                .operation = request.operation,
                .status = status,
                .decision = decision,
                .observed_definition_fingerprint = state.definition_fingerprint,
                .observed_fence_epoch = state.fence_epoch,
                .request_fingerprint = fingerprint,
                .detail = detail,
                .correlation_id = request.correlation_id,
                .trace_id = request.trace_id,
                .boundary_id = request.boundary_id,
            };
        }

        fn validateRequest(request: Request) ControlError!void {
            if (!validIdentifier(request.request_id) or !validIdentifier(request.machine_id) or
                request.instance_id == 0 or request.expected_definition_fingerprint == 0 or
                request.expected_fence_epoch == 0 or request.reason.len == 0 or request.reason.len > 1024)
            {
                return error.InvalidControlRequest;
            }
            if (request.operation == .signal and request.event == null) return error.InvalidControlRequest;
            if (request.operation != .signal and request.event != null) return error.InvalidControlRequest;
        }

        fn requestFingerprint(request: Request) u64 {
            var hasher = std.hash.Fnv1a_64.init();
            hashText(&hasher, request.request_id);
            hashText(&hasher, request.machine_id);
            hashInt(&hasher, request.instance_id);
            hashInt(&hasher, @intFromEnum(request.operation));
            hashInt(&hasher, request.expected_definition_fingerprint);
            hashInt(&hasher, request.expected_fence_epoch);
            hashText(&hasher, request.reason);
            hashInt(&hasher, @intFromBool(request.dry_run));
            if (request.event) |event| {
                hashInt(&hasher, 1);
                hashText(&hasher, @tagName(event));
            } else hashInt(&hasher, 0);
            hashInt(&hasher, request.correlation_id);
            hashInt(&hasher, request.trace_id);
            hashInt(&hasher, request.boundary_id);
            const value = hasher.final();
            return if (value == 0) 1 else value;
        }
    };
}

pub const FleetRecord = struct {
    machine_id: []const u8,
    instance_id: u64,
    definition_fingerprint: u64,
    version: u32,
    status: InstanceStatus,
    health: InstanceHealth,
    owner: []const u8,
    fence_epoch: u64,
    parent_instance_id: ?u64 = null,
    pending_commands: usize = 0,
    pending_timers: usize = 0,
    pending_signals: usize = 0,
    pending_children: usize = 0,
    mailbox_depth: usize = 0,
};

pub const FleetSummary = struct {
    instances: usize = 0,
    running: usize = 0,
    suspended: usize = 0,
    degraded: usize = 0,
    stuck: usize = 0,
    failed: usize = 0,
    terminal: usize = 0,
};

pub const FleetRegistry = struct {
    records: [max_fleet_instances]FleetRecord = undefined,
    count: usize = 0,

    pub fn init() FleetRegistry {
        return .{};
    }

    pub fn upsert(self: *FleetRegistry, record: FleetRecord) ControlError!void {
        if (!validIdentifier(record.machine_id) or !validIdentifier(record.owner) or
            record.instance_id == 0 or record.definition_fingerprint == 0 or
            record.version == 0 or record.fence_epoch == 0)
        {
            return error.InvalidFleetRecord;
        }
        for (self.records[0..self.count]) |*existing| {
            if (existing.instance_id != record.instance_id) continue;
            if (record.fence_epoch < existing.fence_epoch or
                (record.fence_epoch == existing.fence_epoch and !std.mem.eql(u8, record.owner, existing.owner)))
            {
                return error.StaleFleetRecord;
            }
            existing.* = record;
            return;
        }
        if (self.count >= self.records.len) return error.FleetCapacityExceeded;
        self.records[self.count] = record;
        self.count += 1;
    }

    pub fn find(self: *const FleetRegistry, instance_id: u64) ?FleetRecord {
        for (self.records[0..self.count]) |record| if (record.instance_id == instance_id) return record;
        return null;
    }

    pub fn instances(self: *const FleetRegistry) []const FleetRecord {
        return self.records[0..self.count];
    }

    pub fn summary(self: *const FleetRegistry) FleetSummary {
        var result = FleetSummary{ .instances = self.count };
        for (self.instances()) |record| {
            if (record.status == .running) result.running += 1;
            if (record.status == .suspended) result.suspended += 1;
            switch (record.health) {
                .healthy => {},
                .degraded => result.degraded += 1,
                .stuck => result.stuck += 1,
                .failed => result.failed += 1,
                .terminal => result.terminal += 1,
            }
        }
        return result;
    }

    pub fn formatJsonAlloc(self: *const FleetRegistry, allocator: std.mem.Allocator) ![]u8 {
        const totals = self.summary();
        var output = std.ArrayList(u8).empty;
        errdefer output.deinit(allocator);
        try output.print(allocator, "{{\"schema\":\"{s}\",\"schema_version\":1,\"summary\":{{\"instances\":{d},\"running\":{d},\"suspended\":{d},\"degraded\":{d},\"stuck\":{d},\"failed\":{d},\"terminal\":{d}}},\"instances\":[", .{ fleet_snapshot_schema, totals.instances, totals.running, totals.suspended, totals.degraded, totals.stuck, totals.failed, totals.terminal });
        for (self.instances(), 0..) |record, index| {
            if (index != 0) try output.append(allocator, ',');
            try output.appendSlice(allocator, "{\"machine_id\":");
            try appendJsonString(&output, allocator, record.machine_id);
            try output.print(allocator, ",\"instance_id\":\"{d}\",\"definition_fingerprint\":\"{d}\",\"version\":{d},\"status\":\"{s}\",\"health\":\"{s}\",\"owner\":", .{ record.instance_id, record.definition_fingerprint, record.version, @tagName(record.status), @tagName(record.health) });
            try appendJsonString(&output, allocator, record.owner);
            try output.print(allocator, ",\"fence_epoch\":\"{d}\",\"parent_instance_id\":", .{record.fence_epoch});
            if (record.parent_instance_id) |parent| try output.print(allocator, "\"{d}\"", .{parent}) else try output.appendSlice(allocator, "null");
            try output.print(allocator, ",\"pending_commands\":{d},\"pending_timers\":{d},\"pending_signals\":{d},\"pending_children\":{d},\"mailbox_depth\":{d}}}", .{ record.pending_commands, record.pending_timers, record.pending_signals, record.pending_children, record.mailbox_depth });
        }
        try output.appendSlice(allocator, "]}");
        return output.toOwnedSlice(allocator);
    }
};

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(encoded);
    try output.appendSlice(allocator, encoded);
}

fn validIdentifier(value: []const u8) bool {
    if (value.len == 0 or value.len > 128) return false;
    for (value) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == ':')) return false;
    return true;
}

fn hashText(hasher: *std.hash.Fnv1a_64, value: []const u8) void {
    hashInt(hasher, value.len);
    hasher.update(value);
}

fn hashInt(hasher: *std.hash.Fnv1a_64, value: anytype) void {
    var widened: u64 = @intCast(value);
    hasher.update(std.mem.asBytes(&widened));
}
