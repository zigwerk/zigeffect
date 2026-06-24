const std = @import("std");
const fx = @import("zigeffect");

const AlertCapture = struct {
    count: usize = 0,
    last_kind: ?fx.CausalEventKind = null,

    fn sink(self: *AlertCapture) fx.CausalOpsAlertSink {
        return .{
            .state = self,
            .emit = emit,
        };
    }

    fn emit(raw: ?*anyopaque, event: fx.CausalEvent) anyerror!void {
        const self: *AlertCapture = @ptrCast(@alignCast(raw.?));
        self.count += 1;
        self.last_kind = event.kind;
    }
};

test "ops alert sink emits alert facts only" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.record(.{ .kind = .run_started, .run_id = 1, .label = "not alert" });
    _ = try store.record(.{ .kind = .alert_emitted, .label = "retention threshold", .type_name = "retention.threshold" });

    var capture = AlertCapture{};
    const report = try fx.emitCausalOpsAlerts(&store, capture.sink());

    try std.testing.expectEqual(@as(usize, 2), report.scanned_events);
    try std.testing.expectEqual(@as(usize, 1), report.emitted_alerts);
    try std.testing.expectEqual(@as(usize, 1), capture.count);
    try std.testing.expectEqual(fx.CausalEventKind.alert_emitted, capture.last_kind.?);
}

test "ops runbook json summarizes deployment retention and redacts secrets" {
    const json = try fx.formatCausalOpsRunbookJson(std.testing.allocator, .{
        .deployment = .{
            .service = "zigeffect",
            .environment = "prod",
            .region = "eu-west",
            .cluster_id = "password=hunter2",
        },
        .retention = .{
            .max_events = 100,
            .alert_threshold = 3,
        },
        .retained_events = 120,
        .alert_count = 2,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.ops-runbook.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"service\":\"zigeffect\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"max_events\":100") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"alert_count\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.causal_redaction_marker) != null);
}
