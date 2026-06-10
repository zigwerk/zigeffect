const std = @import("std");
const fx = @import("zigeffect");

const LocalActorReport = struct {
    address: fx.EntityAddress,
    processed: usize,
    final_value: u64,
    reply_payload: []const u8,
};

fn runLocalActorExample(allocator: std.mem.Allocator) !LocalActorReport {
    var runtime = fx.LocalEntityRuntime.init(allocator, .{});
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "local-example");
    const ref = try runtime.registerEntity(.{
        .address = address,
        .name = "counter-local-example",
    }, 1_000);

    var counter_value: u64 = 0;
    const scope = try runtime.entityScope(address);
    try scope.provideService("counter-value", &counter_value);

    const tell = try ref.tell("text", "inc", "increment counter");
    defer fx.deinitEntityEnvelope(allocator, tell);
    var ask = try ref.ask("text", "get", "read counter");
    defer ask.deinit(allocator);

    const Handler = struct {
        pub fn handle(entity_scope: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            const raw = (try entity_scope.service("counter-value")).?;
            const value: *u64 = @ptrCast(@alignCast(raw));
            if (std.mem.eql(u8, envelope.payload, "inc")) {
                value.* += 1;
                return .noreply;
            }
            if (envelope.kind == .ask and std.mem.eql(u8, envelope.payload, "get")) {
                return .{ .reply = "value=1" };
            }
            return .noreply;
        }
    };

    var processed: usize = 0;
    var first = try runtime.processNext(address, Handler, 1_100);
    defer first.deinit(allocator);
    processed += 1;
    var second = try runtime.processNext(address, Handler, 1_200);
    defer second.deinit(allocator);
    processed += 1;
    if (!second.replied) return error.ExpectedActorReply;
    if (runtime.pendingCount(address) != 0) return error.ExpectedEmptyMailbox;

    const reply = try runtime.takeReply(ask.correlation_id);
    defer fx.deinitEntityEnvelope(allocator, reply);
    if (!std.mem.eql(u8, reply.payload, "value=1")) return error.ExpectedActorReplyPayload;

    return .{
        .address = address,
        .processed = processed,
        .final_value = counter_value,
        .reply_payload = "value=1",
    };
}

pub fn main() !void {
    const report = try runLocalActorExample(std.heap.page_allocator);
    std.debug.print(
        "local actor: entity_type={s} processed={d} value={d} reply={s}\n",
        .{ report.address.entity_type.name, report.processed, report.final_value, report.reply_payload },
    );
}

test "local actor processes tell ask state and reply" {
    const report = try runLocalActorExample(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), report.processed);
    try std.testing.expectEqual(@as(u64, 1), report.final_value);
    try std.testing.expectEqualStrings("value=1", report.reply_payload);
}
