const std = @import("std");
const zstd = @import("zigeffect_std");
const http = @import("zigeffect_http");
const postgres = @import("zigeffect_postgres_libpq");
const otel = @import("zigeffect_otel");
const redis = @import("zigeffect_redis");
const s3 = @import("zigeffect_s3");
const transport = @import("zigeffect_transport");
const shared = @import("shared");

pub const Config = struct {
    port: u16,
    redis_port: u16,
    s3_port: u16,
    worker_transport_port: u16,
    otlp_port: u16,
    expected_connections: ?usize,
    allow_test_shutdown: bool,
};

pub const config_schema = zstd.Schema.structSchema(Config, .{
    zstd.Schema.field("port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("redis_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("s3_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("worker_transport_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("otlp_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("expected_connections", zstd.Schema.optional(zstd.Schema.integer().min(1).max(1_000_000))),
    zstd.Schema.field("allow_test_shutdown", zstd.Schema.boolean()),
});

const ApiHandler = struct {
    database: *postgres.Session,
    broker: *redis.Client,
    objects: *s3.Client,
    worker: *transport.Client,
    allow_test_shutdown: bool,

    pub fn handleAlloc(self: *ApiHandler, allocator: std.mem.Allocator, request: zstd.Http.Request) !zstd.Http.Response {
        if (std.mem.eql(u8, request.method, "GET") and std.mem.eql(u8, request.url, "/health/live")) return jsonResponse(allocator, 200, .{ .status = "live" });
        if (std.mem.eql(u8, request.method, "GET") and std.mem.eql(u8, request.url, "/health/ready")) return jsonResponse(allocator, 200, .{ .status = "ready" });
        if (self.allow_test_shutdown and std.mem.eql(u8, request.method, "POST") and std.mem.eql(u8, request.url, "/_test/shutdown")) {
            zstd.Application.Lifecycle.requestShutdownForTest(.terminate);
            return jsonResponse(allocator, 200, .{ .status = "draining" });
        }
        if (std.mem.eql(u8, request.method, "POST") and std.mem.eql(u8, request.url, "/orders")) return self.createOrder(allocator, request.body) catch |err| self.failureResponse(allocator, "create-order", err);
        if (std.mem.eql(u8, request.method, "GET") and std.mem.startsWith(u8, request.url, "/orders/")) return self.readOrder(allocator, request.url[8..]) catch |err| self.failureResponse(allocator, "read-order", err);
        return jsonResponse(allocator, 404, .{ .error_code = "not_found" });
    }

    fn createOrder(self: *ApiHandler, allocator: std.mem.Allocator, body: []const u8) !zstd.Http.Response {
        var decoded = try zstd.Schema.decodeDetailedJsonAlloc(allocator, shared.create_schema, body);
        defer decoded.deinit();
        if (!decoded.ok()) return jsonResponse(allocator, 400, .{ .error_code = "invalid_order" });
        const command = decoded.value.?;
        try shared.validateCreate(command);

        var existing = self.database.queryAlloc(allocator, .{ .sql = "select id,attachment_key,status,version from reference_orders where idempotency_key=$1", .binds = &.{.{ .text = command.idempotency_key }} }) catch return error.ReferenceOrderLookupFailed;
        defer existing.deinit(allocator);
        if (existing.rows.len != 0) {
            if (!std.mem.eql(u8, existing.rows[0].fields[0].value.text, command.id)) return jsonResponse(allocator, 409, .{ .error_code = "idempotency_mismatch" });
            return jsonResponse(allocator, 200, .{ .id = command.id, .status = existing.rows[0].fields[2].value.text, .version = existing.rows[0].fields[3].value.integer, .duplicate = true });
        }

        _ = self.objects.put(command.attachment_key, command.attachment, .{ .content_type = "application/octet-stream", .expected_sha256 = zstd.ObjectStorage.sha256(command.attachment), .only_if_absent = true }) catch return error.ReferenceObjectWriteFailed;
        self.database.begin() catch return error.ReferenceOrderBeginFailed;
        errdefer self.database.rollback() catch {};
        exec(self.database, allocator, .{ .sql = "insert into reference_orders(id,idempotency_key,attachment_key,status,version) values($1,$2,$3,'pending',1)", .binds = &.{ .{ .text = command.id }, .{ .text = command.idempotency_key }, .{ .text = command.attachment_key } } }) catch return error.ReferenceOrderInsertFailed;
        exec(self.database, allocator, .{ .sql = "insert into reference_outbox(idempotency_key,order_id,dispatched) values($1,$2,false)", .binds = &.{ .{ .text = command.idempotency_key }, .{ .text = command.id } } }) catch return error.ReferenceOutboxInsertFailed;
        self.database.commit() catch return error.ReferenceOrderCommitFailed;

        var transport_response = self.worker.sendAlloc(allocator, .{
            .kind = .request,
            .address = transport.fx.entityAddress("orders-worker", command.id),
            .payload = "dispatch-ready",
            .idempotency_key = command.idempotency_key,
            .origin_causal_event_id = std.hash.Wyhash.hash(0, command.idempotency_key),
            .policy = .{ .timeout_ms = 5_000, .max_retries = 2_500 },
        }) catch return error.ReferenceTransportDispatchFailed;
        defer transport_response.deinit(allocator);
        _ = self.broker.publish(.{ .subject = "orders", .payload = command.id, .idempotency_key = command.idempotency_key }) catch return error.ReferenceBrokerPublishFailed;
        exec(self.database, allocator, .{ .sql = "update reference_outbox set dispatched=true where idempotency_key=$1", .binds = &.{.{ .text = command.idempotency_key }} }) catch return error.ReferenceOutboxMarkFailed;
        return jsonResponse(allocator, 202, .{ .id = command.id, .status = "pending", .version = @as(i64, 1), .duplicate = false });
    }

    fn readOrder(self: *ApiHandler, allocator: std.mem.Allocator, id: []const u8) !zstd.Http.Response {
        if (id.len == 0 or id.len > 128) return jsonResponse(allocator, 400, .{ .error_code = "invalid_order_id" });
        var result = try self.database.queryAlloc(allocator, .{ .sql = "select id,attachment_key,status,version from reference_orders where id=$1", .binds = &.{.{ .text = id }} });
        defer result.deinit(allocator);
        if (result.rows.len == 0) return jsonResponse(allocator, 404, .{ .error_code = "order_not_found" });
        const fields = result.rows[0].fields;
        return jsonResponse(allocator, 200, .{ .id = fields[0].value.text, .attachment_key = fields[1].value.text, .status = fields[2].value.text, .version = fields[3].value.integer });
    }

    fn failureResponse(_: *ApiHandler, allocator: std.mem.Allocator, operation: []const u8, err: anyerror) !zstd.Http.Response {
        const class = zstd.External.classifyError(err);
        std.log.err("reference API boundary failed operation={s} class={s} error={s}", .{ operation, @tagName(class), @errorName(err) });
        const status: u16 = switch (class) { .unauthorized => 401, .conflict => 409, .capacity => 429, .timeout => 504, .unavailable, .canceled => 503, .corrupt_data, .unsupported, .internal => 500 };
        return jsonResponse(allocator, status, .{ .error_code = @tagName(class) });
    }
};

pub fn compileContract() bool {
    return @hasDecl(http, "Server") and @hasDecl(postgres, "Pool") and @hasDecl(otel, "Exporter") and @hasDecl(redis, "Client") and @hasDecl(s3, "Client") and @hasDecl(transport, "Client");
}

pub fn run(allocator: std.mem.Allocator, io: std.Io, environ: std.process.Environ) !void {
    const config = try loadConfig(allocator, environ);
    var secret_provider = zstd.Secrets.EnvironmentProvider{ .environ = environ };
    var audit = zstd.Secrets.Audit.init(allocator); defer audit.deinit();
    var database_url = try resolve(&secret_provider, allocator, "DATABASE_URL", &audit); defer database_url.deinit();
    var s3_access = try resolve(&secret_provider, allocator, "S3_ACCESS_KEY", &audit); defer s3_access.deinit();
    var s3_secret = try resolve(&secret_provider, allocator, "S3_SECRET_KEY", &audit); defer s3_secret.deinit();
    var redis_password = try resolve(&secret_provider, allocator, "REDIS_PASSWORD", &audit); defer redis_password.deinit();
    var transport_secret = try resolve(&secret_provider, allocator, "TRANSPORT_SECRET", &audit); defer transport_secret.deinit();
    const ca = try envZ(allocator, environ, "ZIGEFFECT_TRANSPORT_CA"); defer allocator.free(ca);

    var lifecycle_evidence = zstd.Application.Lifecycle.Evidence.init(allocator); defer lifecycle_evidence.deinit();
    var lifecycle = zstd.Application.Lifecycle.Manager.initWithEvidence(allocator, &lifecycle_evidence); defer lifecycle.deinit();
    try lifecycle.start();
    var signals = try zstd.Application.Lifecycle.SignalRegistration.install(); defer signals.deinit();
    var database = try postgres.Session.init(allocator, .{ .connection_url = database_url.expose() }); defer database.deinit();
    try migrate(&database, allocator);
    var broker = try redis.Client.init(allocator, io, .{ .port = config.redis_port, .namespace = "zigeffect-reference", .password = redis_password.expose() });
    var objects = try s3.Client.init(allocator, io, .{ .port = config.s3_port, .bucket = "zigeffect", .access_key = s3_access.expose(), .secret_key = s3_secret.expose() }); defer objects.deinit();
    var worker = try transport.Client.initAlloc(allocator, io, .{
        .port = config.worker_transport_port,
        .auth = .{ .mode = .shared_secret, .credential = transport_secret.expose() },
        .tls = .{ .ca_path = ca, .server_name = "localhost" },
        .reconnect_attempts = 2_500,
    }); defer worker.deinit();
    var exporter = try otel.Exporter.init(allocator, io, .{ .port = config.otlp_port, .retry_attempts = 1, .request_deadline_ms = 500 }); defer exporter.deinit();
    exporter.enqueue(.logs, "{\"resourceLogs\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"reference-api\"}}]},\"scopeLogs\":[{\"logRecords\":[{\"body\":{\"stringValue\":\"ready\"}}]}]}]}") catch {};
    exporter.flush() catch {};
    var handler = ApiHandler{ .database = &database, .broker = &broker, .objects = &objects, .worker = &worker, .allow_test_shutdown = config.allow_test_shutdown };
    var policy = try http.PolicyHandler.init(http.Handler.from(ApiHandler, &handler), .{ .secure_headers = true });
    var server = try http.Server.init(allocator, io, .{ .port = config.port, .max_requests_per_connection = 8 }, policy.asHandler()); defer server.deinit();
    try lifecycle.ready();
    var served: usize = 0;
    while (config.expected_connections == null or served < config.expected_connections.?) {
        _ = server.serveOne(allocator) catch |err| {
            if (zstd.Application.Lifecycle.requestedSignal() != .none) break;
            return err;
        };
        served += 1;
        if (zstd.Application.Lifecycle.requestedSignal() != .none) break;
    }
    try lifecycle.drain();
    _ = try server.shutdown(.{ .deadline_ms = 5_000 });
    _ = worker.close() catch {};
    exporter.shutdown() catch {};
    try lifecycle.stop();
}

fn loadConfig(allocator: std.mem.Allocator, environ: std.process.Environ) !Config {
    var layered = zstd.Config.LayeredConfig.init(allocator);
    defer layered.deinit();
    try putEnvironment(&layered, allocator, environ, "port", "ZIGEFFECT_API_PORT");
    try putEnvironment(&layered, allocator, environ, "redis_port", "ZIGEFFECT_REDIS_PORT");
    try putEnvironment(&layered, allocator, environ, "s3_port", "ZIGEFFECT_S3_PORT");
    try putEnvironment(&layered, allocator, environ, "worker_transport_port", "ZIGEFFECT_WORKER_TRANSPORT_PORT");
    try putEnvironment(&layered, allocator, environ, "otlp_port", "ZIGEFFECT_OTLP_PORT");
    if (envAlloc(allocator, environ, "ZIGEFFECT_EXPECTED_HTTP_CONNECTIONS")) |value| {
        defer allocator.free(value);
        try layered.putWithProvenance("expected_connections", value, false, .{ .kind = .environment, .source = "ZIGEFFECT_EXPECTED_HTTP_CONNECTIONS", .priority = 300 });
    } else |_| {}
    const shutdown = envAlloc(allocator, environ, "ZIGEFFECT_TEST_SHUTDOWN") catch null;
    defer if (shutdown) |value| allocator.free(value);
    try layered.putWithProvenance("allow_test_shutdown", if (shutdown != null and std.mem.eql(u8, shutdown.?, "1")) "true" else "false", false, .{ .kind = .environment, .source = "ZIGEFFECT_TEST_SHUTDOWN", .priority = 300 });
    var decoded = try layered.decodeDetailedAlloc(allocator, config_schema);
    defer decoded.deinit();
    if (!decoded.ok()) return error.InvalidProductionConfiguration;
    return decoded.value.?;
}

fn putEnvironment(layered: *zstd.Config.LayeredConfig, allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8, variable: []const u8) !void {
    const value = try envAlloc(allocator, environ, variable);
    defer allocator.free(value);
    try layered.putWithProvenance(key, value, false, .{ .kind = .environment, .source = variable, .priority = 300 });
}

fn migrate(session: *postgres.Session, allocator: std.mem.Allocator) !void {
    try exec(session, allocator, .{ .sql = "create table if not exists reference_orders (id text primary key, idempotency_key text unique not null, attachment_key text not null, status text not null, version bigint not null)" });
    try exec(session, allocator, .{ .sql = "create table if not exists reference_outbox (idempotency_key text primary key, order_id text not null, dispatched boolean not null default false)" });
}
fn exec(session: *postgres.Session, allocator: std.mem.Allocator, statement: zstd.Sql.Statement) !void { var result = try session.queryAlloc(allocator, statement); result.deinit(allocator); }
fn jsonResponse(allocator: std.mem.Allocator, status: u16, value: anytype) !zstd.Http.Response { const body = try zstd.Secrets.safeJsonAlloc(allocator, value, .{}); defer allocator.free(body); return zstd.Http.cloneResponseAlloc(allocator, .{ .status = status, .headers = &.{.{ .name = "Content-Type", .value = "application/json" }}, .body = body }); }
fn resolve(provider: *zstd.Secrets.EnvironmentProvider, allocator: std.mem.Allocator, key: []const u8, audit: *zstd.Secrets.Audit) !zstd.Secrets.Value { return provider.resolveAlloc(allocator, .{ .provider = "environment", .key = key }, audit); }
fn envAlloc(allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) ![]u8 { return std.process.Environ.getAlloc(environ, allocator, key) catch error.MissingProductionConfiguration; }
fn envZ(allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) ![:0]u8 { const value = try envAlloc(allocator, environ, key); defer allocator.free(value); return allocator.dupeZ(u8, value); }
fn envInt(comptime T: type, allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) !T { const value = try envAlloc(allocator, environ, key); defer allocator.free(value); return std.fmt.parseUnsigned(T, value, 10) catch error.InvalidProductionConfiguration; }
