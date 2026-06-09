const std = @import("std");
const fx = @import("zigeffect");

test "cluster entity public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "identity"));
    try std.testing.expect(@hasDecl(fx.cluster, "mailbox"));
    try std.testing.expect(@hasDecl(fx.cluster, "entity"));
    try std.testing.expect(@hasDecl(fx.cluster, "EntityType"));
    try std.testing.expect(@hasDecl(fx.cluster, "EntityId"));
    try std.testing.expect(@hasDecl(fx.cluster, "EntityAddress"));
    try std.testing.expect(@hasDecl(fx.cluster, "entityId"));
    try std.testing.expect(@hasDecl(fx.cluster, "entityAddress"));
    try std.testing.expect(@hasDecl(fx, "EntityAddress"));
}

test "entity ids are stable and entity-type sensitive" {
    const first = fx.entityId("counter", "tenant-1");
    const second = fx.entityId("counter", "tenant-1");
    const other_type = fx.entityId("ledger", "tenant-1");
    const other_key = fx.entityId("counter", "tenant-2");

    try std.testing.expectEqual(first, second);
    try std.testing.expect(first != other_type);
    try std.testing.expect(first != other_key);

    const address = fx.entityAddress("counter", "tenant-1");
    try std.testing.expectEqual(first, address.id);
    try std.testing.expectEqualStrings("counter", address.entity_type.name);
    try std.testing.expect(address.eql(fx.EntityAddress{
        .entity_type = fx.EntityType.init("counter"),
        .id = first,
    }));
}

test "local mailbox store returns entity messages in fifo order" {
    var store = fx.LocalMailboxStore.init(std.testing.allocator);
    defer store.deinit();

    const counter = fx.entityAddress("counter", "one");
    const ledger = fx.entityAddress("ledger", "one");

    const first = try store.offer(.{ .kind = .tell, .address = counter, .payload_type_name = "text", .payload = "first" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, first);
    const second = try store.offer(.{ .kind = .tell, .address = counter, .payload_type_name = "text", .payload = "second" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, second);
    const other = try store.offer(.{ .kind = .tell, .address = ledger, .payload_type_name = "text", .payload = "ledger" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, other);

    try std.testing.expectEqual(@as(usize, 2), store.pendingCount(counter));
    try std.testing.expectEqual(@as(usize, 1), store.pendingCount(ledger));

    const taken_first = try store.take(counter);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_first);
    const taken_second = try store.take(counter);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_second);
    const taken_other = try store.take(ledger);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_other);

    try std.testing.expectEqualStrings("first", taken_first.payload);
    try std.testing.expectEqualStrings("second", taken_second.payload);
    try std.testing.expectEqualStrings("ledger", taken_other.payload);
    try std.testing.expect(taken_first.sequence < taken_second.sequence);
    try std.testing.expectError(error.MailboxEmpty, store.take(counter));
}

test "local mailbox store keeps ask correlations and replies" {
    var store = fx.LocalMailboxStore.init(std.testing.allocator);
    defer store.deinit();

    const address = fx.entityAddress("counter", "one");
    const ask = try store.offer(.{ .kind = .ask, .address = address, .payload_type_name = "text", .payload = "question" });
    defer fx.deinitEntityEnvelope(std.testing.allocator, ask);

    try std.testing.expect(ask.correlation_id != null);
    const reply = try store.storeReply(.{
        .kind = .reply,
        .address = address,
        .correlation_id = ask.correlation_id,
        .payload_type_name = "text",
        .payload = "answer",
    });
    defer fx.deinitEntityEnvelope(std.testing.allocator, reply);

    const taken_reply = try store.takeReply(ask.correlation_id.?);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken_reply);
    try std.testing.expectEqualStrings("answer", taken_reply.payload);
    try std.testing.expectError(error.ReplyNotFound, store.takeReply(ask.correlation_id.?));
}

test "local entity runtime registers entities refs services and finalizers" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    const ref = try runtime.registerEntity(.{
        .address = address,
        .name = "counter-one",
        .idle_timeout_ms = 500,
    }, 1_000);

    try std.testing.expect(ref.address.eql(address));
    try std.testing.expectEqual(fx.EntityStatus.running, try runtime.status(address));
    try std.testing.expectError(error.DuplicateEntity, runtime.registerEntity(.{
        .address = address,
        .name = "dupe",
    }, 1_100));

    var value: u32 = 42;
    const scope = try runtime.entityScope(address);
    try scope.provideService("counter-state", &value);
    try std.testing.expectError(error.DuplicateEntityService, scope.provideService("counter-state", &value));
    const raw = (try scope.service("counter-state")).?;
    const typed: *u32 = @ptrCast(@alignCast(raw));
    try std.testing.expectEqual(@as(u32, 42), typed.*);
}

test "entity scope finalizers run in reverse order on shutdown" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    _ = try runtime.registerEntity(.{
        .address = address,
        .name = "counter-one",
        .idle_timeout_ms = 0,
    }, 1_000);

    var releases = std.ArrayList(u8).empty;
    defer releases.deinit(std.testing.allocator);

    const Resource = struct {
        releases: *std.ArrayList(u8),
        marker: u8,
    };
    const release = struct {
        fn run(resource: *Resource) void {
            resource.releases.append(std.testing.allocator, resource.marker) catch unreachable;
        }
    }.run;

    var first = Resource{ .releases = &releases, .marker = 'a' };
    var second = Resource{ .releases = &releases, .marker = 'b' };
    const scope = try runtime.entityScope(address);
    try scope.addFinalizerFor(Resource, &first, release);
    try scope.addFinalizerFor(Resource, &second, release);

    runtime.shutdownIdle(1_001);
    try std.testing.expectEqual(fx.EntityStatus.stopped, try runtime.status(address));
    try std.testing.expectEqualStrings("ba", releases.items);
}

test "entity refs tell ask reply and process ordered messages" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-one" }, 1_000);

    const tell = try ref.tell("text", "inc", "first command");
    defer fx.deinitEntityEnvelope(std.testing.allocator, tell);
    var ask = try ref.ask("text", "get", "read current value");
    defer ask.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), runtime.pendingCount(address));

    var seen = std.ArrayList([]const u8).empty;
    defer seen.deinit(std.testing.allocator);
    const scope = try runtime.entityScope(address);
    try scope.provideService("seen", &seen);

    const Handler = struct {
        pub fn handle(entity_scope: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            const raw = (try entity_scope.service("seen")).?;
            const seen_messages: *std.ArrayList([]const u8) = @ptrCast(@alignCast(raw));
            try seen_messages.append(std.testing.allocator, envelope.payload);
            if (envelope.kind == .ask) return .{ .reply = "value=1" };
            return .noreply;
        }
    };

    var first = try runtime.processNext(address, Handler, 1_100);
    defer first.deinit(std.testing.allocator);
    var second = try runtime.processNext(address, Handler, 1_200);
    defer second.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("inc", seen.items[0]);
    try std.testing.expectEqualStrings("get", seen.items[1]);
    try std.testing.expect(!first.replied);
    try std.testing.expect(second.replied);

    const reply = try runtime.takeReply(ask.correlation_id);
    defer fx.deinitEntityEnvelope(std.testing.allocator, reply);
    try std.testing.expectEqual(fx.EntityEnvelopeKind.reply, reply.kind);
    try std.testing.expectEqualStrings("value=1", reply.payload);
}

test "interrupt envelope marks entity interrupted and closes scope" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "one");
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-one" }, 1_000);

    const interrupt = try ref.interrupt("shutdown");
    defer fx.deinitEntityEnvelope(std.testing.allocator, interrupt);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return .noreply;
        }
    };

    var result = try runtime.processNext(address, Handler, 1_100);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(fx.EntityEnvelopeKind.interrupt, result.envelope.kind);
    try std.testing.expectEqual(fx.EntityStatus.interrupted, try runtime.status(address));
}

test "idle shutdown only stops entities with empty expired mailboxes" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{});
    defer runtime.deinit();

    const idle = fx.entityAddress("counter", "idle");
    const busy = fx.entityAddress("counter", "busy");
    const ref_idle = try runtime.registerEntity(.{ .address = idle, .name = "idle", .idle_timeout_ms = 100 }, 1_000);
    const ref_busy = try runtime.registerEntity(.{ .address = busy, .name = "busy", .idle_timeout_ms = 100 }, 1_000);

    const queued = try ref_busy.tell("text", "work", "queued");
    defer fx.deinitEntityEnvelope(std.testing.allocator, queued);
    _ = ref_idle;

    runtime.shutdownIdle(1_101);
    try std.testing.expectEqual(fx.EntityStatus.stopped, try runtime.status(idle));
    try std.testing.expectEqual(fx.EntityStatus.running, try runtime.status(busy));
}
