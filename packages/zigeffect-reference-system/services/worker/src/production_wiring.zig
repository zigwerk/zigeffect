const std = @import("std");
const zstd = @import("zigeffect_std");
const postgres = @import("zigeffect_postgres_libpq");
const otel = @import("zigeffect_otel");
const redis = @import("zigeffect_redis");
const transport = @import("zigeffect_transport");
const storage = @import("zigeffect_storage_postgres");
const shared = @import("shared");

pub const Config = struct { redis_port: u16, transport_port: u16, otlp_port: u16, poll_deadline_ms: u64, expected_orders: usize };
pub const config_schema = zstd.Schema.structSchema(Config, .{
    zstd.Schema.field("redis_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("transport_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("otlp_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("poll_deadline_ms", zstd.Schema.integer().min(100).max(300_000)),
    zstd.Schema.field("expected_orders", zstd.Schema.integer().min(1).max(10_000)),
});

pub fn compileContract() bool { return @hasDecl(postgres, "Session") and @hasDecl(storage, "PostgresRunnerStorage") and @hasDecl(otel, "Exporter") and @hasDecl(redis, "Client") and @hasDecl(transport, "Server") and @hasDecl(shared, "statechart"); }

pub fn run(allocator: std.mem.Allocator, io: std.Io, environ: std.process.Environ) !void {
    const config = try loadConfig(allocator, environ);
    var secret_provider = zstd.Secrets.EnvironmentProvider{ .environ = environ };
    var audit = zstd.Secrets.Audit.init(allocator); defer audit.deinit();
    var database_url = try resolve(&secret_provider, allocator, "DATABASE_URL", &audit); defer database_url.deinit();
    var redis_password = try resolve(&secret_provider, allocator, "REDIS_PASSWORD", &audit); defer redis_password.deinit();
    var transport_secret = try resolve(&secret_provider, allocator, "TRANSPORT_SECRET", &audit); defer transport_secret.deinit();
    const certificate = try envZ(allocator, environ, "ZIGEFFECT_TRANSPORT_SERVER_CERT"); defer allocator.free(certificate);
    const private_key = try envZ(allocator, environ, "ZIGEFFECT_TRANSPORT_SERVER_KEY"); defer allocator.free(private_key);

    var evidence = zstd.Application.Lifecycle.Evidence.init(allocator); defer evidence.deinit();
    var lifecycle = zstd.Application.Lifecycle.Manager.initWithEvidence(allocator, &evidence); defer lifecycle.deinit();
    try lifecycle.start();
    var signals = try zstd.Application.Lifecycle.SignalRegistration.install(); defer signals.deinit();
    var database = try postgres.Session.init(allocator, .{ .connection_url = database_url.expose() }); defer database.deinit();
    var migration = try storage.migrateAlloc(allocator, &database, .{ .table_prefix = "reference_runtime" }, .postgresql); defer migration.deinit();
    var pool = try postgres.Pool.initAlloc(allocator, io, .{ .session = .{ .connection_url = database_url.expose() }, .size = 2 }); defer pool.deinit();
    var durable = try storage.PostgresRunnerStorage.init(allocator, &pool, .{ .table_prefix = "reference_runtime" });
    const lease_owner = transport.fx.RunnerAddress{ .machine_id = 1, .runner_id = 1 };
    var clock = zstd.Clock.RealClock.init(io);
    const lease_now = clock.asService().snapshot().wall_millis;
    const lease = try durable.acquire(.{ .shard_id = 1, .owner = lease_owner, .now_ms = lease_now, .ttl_ms = config.poll_deadline_ms + 10_000 });
    defer durable.release(.{ .shard_id = lease.shard_id, .owner = lease_owner }) catch {};
    var broker = try redis.Client.init(allocator, io, .{ .port = config.redis_port, .namespace = "zigeffect-reference", .password = redis_password.expose() });
    var message_storage = transport.fx.InMemoryMessageStorage.init(allocator); defer message_storage.deinit();
    var handler = try transport.StorageHandler.init(allocator, message_storage.asMessageStorage(), 32); defer handler.deinit();
    var server = try transport.Server.init(allocator, io, .{
        .port = config.transport_port,
        .limits = .{ .max_requests_per_connection = 1 },
        .auth = .{ .mode = .shared_secret, .credential = transport_secret.expose() },
        .tls = .{ .certificate_chain_path = certificate, .private_key_path = private_key },
    }, transport.Handler.from(transport.StorageHandler, &handler));
    defer server.deinit();
    var server_context = ServerContext{ .server = &server, .allocator = allocator, .expected = config.expected_orders };
    const server_thread = try std.Thread.spawn(.{}, ServerContext.run, .{&server_context});

    var exporter = try otel.Exporter.init(allocator, io, .{ .port = config.otlp_port, .retry_attempts = 1, .request_deadline_ms = 500 }); defer exporter.deinit();
    exporter.enqueue(.logs, "{\"resourceLogs\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"reference-worker\"}}]},\"scopeLogs\":[{\"logRecords\":[{\"body\":{\"stringValue\":\"ready\"}}]}]}]}") catch {};
    exporter.flush() catch {};
    try lifecycle.ready();

    const started = std.Io.Clock.Timestamp.now(io, .awake);
    var processed: usize = 0;
    while (processed < config.expected_orders and elapsedMs(started, std.Io.Clock.Timestamp.now(io, .awake)) < config.poll_deadline_ms and zstd.Application.Lifecycle.requestedSignal() == .none) {
        if (try broker.pollAlloc(allocator, "orders", "worker-process", 2_000)) |delivery_value| {
            var delivery = delivery_value; defer delivery.deinit();
            var journal = try storage.PostgresJournalStore.init(allocator, &pool, .{
                .storage = .{ .table_prefix = "reference_runtime" },
                .workflow_id = std.hash.Wyhash.hash(0, delivery.payload),
                .execution_id = 1,
                .required_fence = .{ .shard_id = lease.shard_id, .epoch = lease.epoch },
            });
            const started_key = try std.fmt.allocPrint(allocator, "{s}-started", .{delivery.idempotency_key});
            defer allocator.free(started_key);
            const completed_key = try std.fmt.allocPrint(allocator, "{s}-completed", .{delivery.idempotency_key});
            defer allocator.free(completed_key);
            _ = try journal.appendIdempotent(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = journal.config.workflow_id, .execution_id = 1, .idempotency_key = delivery.idempotency_key } });
            _ = try journal.appendIdempotent(.{ .event = .{ .sequence = 2, .kind = .activity_started, .workflow_id = journal.config.workflow_id, .execution_id = 1, .activity_id = 1, .name = "complete-order", .idempotency_key = started_key } });
            try database.begin(); errdefer database.rollback() catch {};
            const processing = try shared.advance(.pending, .claim);
            const completed = try shared.advance(processing, .complete);
            try exec(&database, allocator, .{ .sql = "update reference_orders set status=$2,version=version+1 where id=$1 and status='pending'", .binds = &.{ .{ .text = delivery.payload }, .{ .text = @tagName(processing) } } });
            try exec(&database, allocator, .{ .sql = "update reference_orders set status=$2,version=version+1 where id=$1 and status='processing'", .binds = &.{ .{ .text = delivery.payload }, .{ .text = @tagName(completed) } } });
            try database.commit();
            _ = try journal.appendIdempotent(.{ .event = .{ .sequence = 3, .kind = .activity_completed, .workflow_id = journal.config.workflow_id, .execution_id = 1, .activity_id = 1, .name = "complete-order", .idempotency_key = completed_key } });
            try broker.ack(delivery.id, "worker-process");
            processed += 1;
        } else try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(10), .clock = .awake }).sleep(io);
    }
    if (processed != config.expected_orders) { server.drain(); server_thread.join(); return error.WorkerPollDeadlineExceeded; }
    server_thread.join();
    if (server_context.failure) |err| return err;
    try lifecycle.drain();
    server.drain();
    exporter.shutdown() catch {};
    try lifecycle.stop();
}

const ServerContext = struct {
    server: *transport.Server,
    allocator: std.mem.Allocator,
    expected: usize,
    failure: ?anyerror = null,
    fn run(self: *ServerContext) void {
        for (0..self.expected) |_| {
            const handled = self.server.serveOne(self.allocator) catch |err| { self.failure = err; return; };
            if (handled == 0) { self.failure = error.NoTransportRequest; return; }
        }
    }
};

fn exec(session: *postgres.Session, allocator: std.mem.Allocator, statement: zstd.Sql.Statement) !void { var result = try session.queryAlloc(allocator, statement); result.deinit(allocator); }
fn loadConfig(allocator: std.mem.Allocator, environ: std.process.Environ) !Config {
    var layered = zstd.Config.LayeredConfig.init(allocator);
    defer layered.deinit();
    const entries = [_]struct { key: []const u8, variable: []const u8 }{
        .{ .key = "redis_port", .variable = "ZIGEFFECT_REDIS_PORT" },
        .{ .key = "transport_port", .variable = "ZIGEFFECT_WORKER_TRANSPORT_PORT" },
        .{ .key = "otlp_port", .variable = "ZIGEFFECT_OTLP_PORT" },
        .{ .key = "poll_deadline_ms", .variable = "ZIGEFFECT_WORKER_POLL_DEADLINE_MS" },
        .{ .key = "expected_orders", .variable = "ZIGEFFECT_EXPECTED_ORDERS" },
    };
    for (entries) |entry| {
        const value = try envAlloc(allocator, environ, entry.variable);
        defer allocator.free(value);
        try layered.putWithProvenance(entry.key, value, false, .{ .kind = .environment, .source = entry.variable, .priority = 300 });
    }
    var decoded = try layered.decodeDetailedAlloc(allocator, config_schema);
    defer decoded.deinit();
    if (!decoded.ok()) return error.InvalidProductionConfiguration;
    return decoded.value.?;
}
fn resolve(provider: *zstd.Secrets.EnvironmentProvider, allocator: std.mem.Allocator, key: []const u8, audit: *zstd.Secrets.Audit) !zstd.Secrets.Value { return provider.resolveAlloc(allocator, .{ .provider = "environment", .key = key }, audit); }
fn envAlloc(allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) ![]u8 { return std.process.Environ.getAlloc(environ, allocator, key) catch error.MissingProductionConfiguration; }
fn envZ(allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) ![:0]u8 { const value = try envAlloc(allocator, environ, key); defer allocator.free(value); return allocator.dupeZ(u8, value); }
fn envInt(comptime T: type, allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) !T { const value = try envAlloc(allocator, environ, key); defer allocator.free(value); return std.fmt.parseUnsigned(T, value, 10) catch error.InvalidProductionConfiguration; }
fn elapsedMs(start: std.Io.Clock.Timestamp, end: std.Io.Clock.Timestamp) u64 { return @intCast(@max(0, start.durationTo(end).raw.toMilliseconds())); }
