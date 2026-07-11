const std = @import("std");
const fx = @import("zigeffect");

const Event = enum { approve, retry };
const Control = fx.statechart.ControlPlane(Event);

const FakeRuntime = struct {
    applies: usize = 0,
    fingerprint: u64 = 42,
    fence_epoch: u64 = 7,
    status: fx.statechart.InstanceStatus = .running,

    fn inspect(context: *anyopaque, _: u64) anyerror!Control.InstanceState {
        const self: *FakeRuntime = @ptrCast(@alignCast(context));
        return .{ .definition_fingerprint = self.fingerprint, .fence_epoch = self.fence_epoch, .status = self.status };
    }

    fn apply(context: *anyopaque, _: Control.Request) anyerror!void {
        const self: *FakeRuntime = @ptrCast(@alignCast(context));
        self.applies += 1;
    }
};

const Policy = struct {
    decision: fx.statechart.ControlDecision,

    fn decide(context: *anyopaque, _: Control.Request) fx.statechart.ControlDecision {
        const self: *Policy = @ptrCast(@alignCast(context));
        return self.decision;
    }
};

fn request(id: []const u8, operation: fx.statechart.ControlOperation) Control.Request {
    return .{
        .request_id = id,
        .machine_id = "agent.review",
        .instance_id = 91,
        .operation = operation,
        .expected_definition_fingerprint = 42,
        .expected_fence_epoch = 7,
        .reason = "operator review",
        .event = if (operation == .signal) .approve else null,
    };
}

test "statechart control plane is default deny and dry run never mutates" {
    var runtime = FakeRuntime{};
    var controller = Control.init(.{ .context = &runtime, .inspect_fn = FakeRuntime.inspect, .apply_fn = FakeRuntime.apply });

    const denied = try controller.execute(request("request-denied", .@"suspend"));
    try std.testing.expectEqual(fx.statechart.ControlStatus.denied, denied.status);
    try std.testing.expectEqual(@as(usize, 0), runtime.applies);

    var allow = Policy{ .decision = .allow };
    controller.policy = .{ .context = &allow, .decide_fn = Policy.decide };
    var dry = request("request-dry", .cancel);
    dry.dry_run = true;
    const preview = try controller.execute(dry);
    try std.testing.expectEqual(fx.statechart.ControlStatus.dry_run, preview.status);
    try std.testing.expectEqual(@as(usize, 0), runtime.applies);
}

test "statechart control plane applies once and rejects stale authority" {
    var runtime = FakeRuntime{};
    var allow = Policy{ .decision = .allow };
    var controller = Control.init(.{ .context = &runtime, .inspect_fn = FakeRuntime.inspect, .apply_fn = FakeRuntime.apply });
    controller.policy = .{ .context = &allow, .decide_fn = Policy.decide };

    const applied = try controller.execute(request("request-apply", .signal));
    try std.testing.expectEqual(fx.statechart.ControlStatus.applied, applied.status);
    try std.testing.expectEqual(@as(usize, 1), runtime.applies);
    const receipt_json = try applied.formatJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(receipt_json);
    try std.testing.expect(std.mem.indexOf(u8, receipt_json, "zigeffect.statechart.control-receipt.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt_json, "\"instance_id\":\"91\"") != null);
    const duplicate = try controller.execute(request("request-apply", .signal));
    try std.testing.expectEqual(fx.statechart.ControlStatus.duplicate, duplicate.status);
    try std.testing.expectEqual(@as(usize, 1), runtime.applies);

    var stale_definition = request("request-stale-definition", .@"resume");
    stale_definition.expected_definition_fingerprint = 41;
    try std.testing.expectEqual(fx.statechart.ControlStatus.stale, (try controller.execute(stale_definition)).status);
    var stale_fence = request("request-stale-fence", .@"resume");
    stale_fence.expected_fence_epoch = 6;
    try std.testing.expectEqual(fx.statechart.ControlStatus.stale, (try controller.execute(stale_fence)).status);
    try std.testing.expectEqual(@as(usize, 1), runtime.applies);
}

test "statechart fleet registry tracks bounded instance health and pending work" {
    var registry = fx.statechart.FleetRegistry.init();
    try registry.upsert(.{
        .machine_id = "agent.review",
        .instance_id = 1,
        .definition_fingerprint = 42,
        .version = 2,
        .status = .running,
        .health = .healthy,
        .owner = "runner-a",
        .fence_epoch = 4,
        .pending_commands = 2,
    });
    try registry.upsert(.{
        .machine_id = "agent.review",
        .instance_id = 2,
        .definition_fingerprint = 42,
        .version = 2,
        .status = .suspended,
        .health = .degraded,
        .owner = "runner-b",
        .fence_epoch = 8,
        .pending_timers = 1,
    });
    const summary = registry.summary();
    try std.testing.expectEqual(@as(usize, 2), summary.instances);
    try std.testing.expectEqual(@as(usize, 1), summary.running);
    try std.testing.expectEqual(@as(usize, 1), summary.degraded);
    try std.testing.expectEqual(@as(?u64, 8), registry.find(2).?.fence_epoch);
    const fleet_json = try registry.formatJsonAlloc(std.testing.allocator);
    defer std.testing.allocator.free(fleet_json);
    try std.testing.expect(std.mem.indexOf(u8, fleet_json, "zigeffect.statechart.fleet-snapshot.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, fleet_json, "\"instance_id\":\"2\"") != null);

    var stale = registry.find(2).?;
    stale.fence_epoch = 7;
    try std.testing.expectError(error.StaleFleetRecord, registry.upsert(stale));
}
