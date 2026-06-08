const std = @import("std");
const fx = @import("zigeffect");

test "formatCausalDot emits graph attributes contextual labels and parent edges" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "readiness \"quoted\"\nnext",
        .type_name = "DotRun",
        .status = "success",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .parent_id = started,
        .scope_id = 3,
        .label = "Config",
        .type_name = "ConfigService",
        .status = "missing",
    });

    const dot = try fx.formatCausalDot(std.testing.allocator, &store);
    defer std.testing.allocator.free(dot);

    try std.testing.expect(std.mem.indexOf(u8, dot, "digraph zigeffect_causal {") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "graph [rankdir=\"LR\", labelloc=\"t\", label=\"zigeffect causal graph\"];") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "node [shape=\"box\", style=\"rounded,filled\", fontname=\"Menlo\", fontsize=\"10\"];") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "edge [fontname=\"Menlo\", fontsize=\"9\", color=\"#64748b\"];") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 [label=\"event 1\\nrun_started\\nreadiness \\\"quoted\\\" next\\nstatus=success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "tooltip=\"run=1 type=DotRun\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_2 [label=\"event 2\\nservice_required\\nConfig\\nstatus=missing\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "tooltip=\"run=1 scope=3 type=ConfigService\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, dot, "event_1 -> event_2 [label=\"parent\"];") != null);
    try std.testing.expect(std.mem.endsWith(u8, dot, "}\n"));
}
