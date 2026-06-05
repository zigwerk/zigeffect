const std = @import("std");
const fx = @import("zigeffect");

pub fn buildSampleReport(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "sample readiness",
        .type_name = "SampleReadiness",
    });
    const resource = try store.record(.{
        .kind = .resource_acquired,
        .run_id = run_id,
        .scope_id = scope_id,
        .label = "database",
        .type_name = "DatabaseConnection",
        .status = "success",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .parent_id = started,
        .label = "DatabaseLayer",
        .type_name = @typeName(fx.Config),
        .status = "missing",
    });
    _ = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = resource,
        .status = "failure",
        .type_name = "MissingConfig",
    });

    return fx.formatCausalCiReport(allocator, "sample readiness", &store);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const report = try buildSampleReport(allocator);
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
}

test "sample causal report includes findings and next queries" {
    const report = try buildSampleReport(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal ci report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "findings: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next queries:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal.requirements") != null);
}
