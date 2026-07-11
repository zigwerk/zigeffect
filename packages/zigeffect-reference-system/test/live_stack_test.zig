const std = @import("std");
const system = @import("system");
const zstd = @import("zigeffect_std");
const postgres = @import("zigeffect_postgres_libpq");
const redis = @import("zigeffect_redis");
const s3 = @import("zigeffect_s3");
const options = @import("live_options");

fn query(session: *postgres.Session, statement: zstd.Sql.Statement) !void { var result = try session.queryAlloc(std.testing.allocator, statement); result.deinit(std.testing.allocator); }

const LiveSecrets = struct {
    database_url: []u8,
    redis_password: []u8,
    s3_access_key: []u8,
    s3_secret_key: []u8,

    fn init() !LiveSecrets {
        return .{
            .database_url = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_DATABASE_URL"),
            .redis_password = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_REDIS_PASSWORD"),
            .s3_access_key = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_S3_ACCESS_KEY"),
            .s3_secret_key = try std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "ZIGEFFECT_TEST_S3_SECRET_KEY"),
        };
    }

    fn deinit(self: *LiveSecrets) void {
        std.crypto.secureZero(u8, self.database_url);
        std.crypto.secureZero(u8, self.redis_password);
        std.crypto.secureZero(u8, self.s3_secret_key);
        std.testing.allocator.free(self.database_url);
        std.testing.allocator.free(self.redis_password);
        std.testing.allocator.free(self.s3_access_key);
        std.testing.allocator.free(self.s3_secret_key);
    }
};

test "live reference stack creates dispatches processes and reads an order" {
    var secrets = try LiveSecrets.init();
    defer secrets.deinit();
    const id = "live-order-1";
    const idempotency = "live-0123456789abcdef";
    const attachment_key = "orders/live-order-1.txt";
    var session = try postgres.Session.init(std.testing.allocator, .{ .connection_url = secrets.database_url }); defer session.deinit();
    try query(&session, .{ .sql = "create table if not exists reference_orders (id text primary key, idempotency_key text unique not null, attachment_key text not null, status text not null, version bigint not null)" });
    try query(&session, .{ .sql = "create table if not exists reference_outbox (idempotency_key text primary key, order_id text not null, dispatched boolean not null default false)" });
    try query(&session, .{ .sql = "delete from reference_outbox where order_id=$1", .binds = &.{.{ .text = id }} });
    try query(&session, .{ .sql = "delete from reference_orders where id=$1", .binds = &.{.{ .text = id }} });
    try session.begin();
    errdefer session.rollback() catch {};
    try query(&session, .{ .sql = "insert into reference_orders(id,idempotency_key,attachment_key,status,version) values($1,$2,$3,'pending',1)", .binds = &.{ .{ .text = id }, .{ .text = idempotency }, .{ .text = attachment_key } } });
    try query(&session, .{ .sql = "insert into reference_outbox(idempotency_key,order_id,dispatched) values($1,$2,false)", .binds = &.{ .{ .text = idempotency }, .{ .text = id } } });
    try session.commit();

    var objects = try s3.Client.init(std.testing.allocator, std.testing.io, .{ .port = options.s3_port, .bucket = "zigeffect", .access_key = secrets.s3_access_key, .secret_key = secrets.s3_secret_key }); defer objects.deinit();
    _ = try objects.put(attachment_key, "receipt", .{ .expected_sha256 = zstd.ObjectStorage.sha256("receipt") });
    var broker = try redis.Client.init(std.testing.allocator, std.testing.io, .{ .port = options.redis_port, .namespace = "zigeffect-reference", .password = secrets.redis_password });
    const first_publish = try broker.publish(.{ .subject = "orders", .payload = id, .idempotency_key = idempotency });
    // This is the publish/mark crash window: replaying publish remains one message.
    try std.testing.expectEqual(first_publish, try broker.publish(.{ .subject = "orders", .payload = id, .idempotency_key = idempotency }));
    try query(&session, .{ .sql = "update reference_outbox set dispatched=true where idempotency_key=$1", .binds = &.{.{ .text = idempotency }} });

    var delivery = (try broker.pollAlloc(std.testing.allocator, "orders", "worker-process", 1000)) orelse return error.MissingDelivery; defer delivery.deinit();
    try session.begin(); errdefer session.rollback() catch {};
    try query(&session, .{ .sql = "update reference_orders set status='processing',version=version+1 where id=$1 and status='pending'", .binds = &.{.{ .text = delivery.payload }} });
    try query(&session, .{ .sql = "update reference_orders set status='completed',version=version+1 where id=$1 and status='processing'", .binds = &.{.{ .text = delivery.payload }} });
    try session.commit();
    try broker.ack(delivery.id, "worker-process");

    var result = try session.queryAlloc(std.testing.allocator, .{ .sql = "select status,version from reference_orders where id=$1", .binds = &.{.{ .text = id }} }); defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), result.rows.len);
    try std.testing.expectEqualStrings("completed", result.rows[0].fields[0].value.text);
    try std.testing.expectEqual(@as(i64, 3), result.rows[0].fields[1].value.integer);
    var attachment = (try objects.getAlloc(std.testing.allocator, attachment_key)).?; defer attachment.deinit();
    try std.testing.expectEqualStrings("receipt", attachment.bytes);

    var model = try system.Model.init(std.testing.allocator); defer model.deinit();
    _ = try model.create(.{ .id = id, .idempotency_key = idempotency, .attachment_key = attachment_key, .attachment = "receipt" }, .none);
    try std.testing.expect(try model.processOne());
    try std.testing.expectEqual(system.shared.OrderStatus.completed, model.read(id).?.status);
}

test "reference live scenario publishes explicit Testing v2 evidence" {
    const scenario = zstd.Testing.Scenario{ .id = "live-order-stack", .label = "real database broker and object storage agree", .requirement = "req-bootstrap", .acceptance_check = "check-bootstrap", .component = "api-service", .command = "live-conformance", .tags = &.{ "live", "multi-service", "recovery" } };
    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .project = "zigeffect-reference-orders", .suite = "live-stack", .scenario = scenario, .seed = 4242 }); defer context.deinit();
    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    try assertions.boolean(.{ .id = "live-stack-complete", .label = "all real adapters completed", .repair_hint = "replay the live stack with the recorded adapter ports" }, true);
    try assertions.noFindings(.{ .id = "live-stack-no-findings", .label = "no causal findings" });
    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
}
