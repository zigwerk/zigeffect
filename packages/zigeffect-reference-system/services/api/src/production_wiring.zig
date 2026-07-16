const std = @import("std");
const zstd = @import("zigeffect_std");
const http = @import("zigeffect_http");
const postgres = @import("zigeffect_postgres_libpq");
const otel = @import("zigeffect_otel");
const redis = @import("zigeffect_redis");
const s3 = @import("zigeffect_s3");
const transport = @import("zigeffect_transport");
const shared = @import("shared");
const kernel = zstd.fx.kernel;

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
        const status: u16 = switch (class) {
            .unauthorized => 401,
            .conflict => 409,
            .capacity => 429,
            .timeout => 504,
            .unavailable, .canceled => 503,
            .corrupt_data, .unsupported, .internal => 500,
        };
        return jsonResponse(allocator, status, .{ .error_code = @tagName(class) });
    }
};

pub fn compileContract() bool {
    return @hasDecl(http, "ServerService") and @hasDecl(http, "serverLayer") and
        @hasDecl(postgres, "SessionService") and @hasDecl(postgres, "sessionLayer") and
        @hasDecl(otel, "ExporterService") and @hasDecl(otel, "exporterLayer") and
        @hasDecl(redis, "ClientService") and @hasDecl(redis, "clientLayer") and
        @hasDecl(s3, "ClientService") and @hasDecl(s3, "clientLayer") and
        @hasDecl(transport, "ClientService") and @hasDecl(transport, "clientLayer") and
        @hasDecl(zstd, "ManagedRuntime");
}

pub const RuntimeInputs = struct {
    io: std.Io,
    environ: std.process.Environ,
    application_map: *http.ApplicationMapSlot,
};
const RuntimeInputsService = kernel.Service("reference/api/RuntimeInputs", RuntimeInputs);

pub const ConfigApi = struct {
    pub const operations: []const []const u8 = &.{"ReferenceApiConfig.read"};
    value: Config,
};
pub const ApplicationConfig = kernel.Service("reference/api/Config", ConfigApi);

const ConfigLifecycle = struct {
    fn acquire(ctx: *kernel.ContextView(.{RuntimeInputsService})) anyerror!ConfigApi {
        return .{ .value = try loadConfig(ctx.allocator(), ctx.service(RuntimeInputsService).environ) };
    }
    fn release(_: *ConfigApi) void {}
};

const SecretState = struct {
    allocator: std.mem.Allocator,
    database_url: zstd.Secrets.Value,
    s3_access: zstd.Secrets.Value,
    s3_secret: zstd.Secrets.Value,
    redis_password: zstd.Secrets.Value,
    transport_secret: zstd.Secrets.Value,
    ca: [:0]u8,
};
const RuntimeSecrets = kernel.Service("reference/api/Secrets", SecretState);

const SecretLifecycle = struct {
    fn acquire(ctx: *kernel.ContextView(.{RuntimeInputsService})) anyerror!SecretState {
        const allocator = ctx.allocator();
        const environ = ctx.service(RuntimeInputsService).environ;
        var provider = zstd.Secrets.EnvironmentProvider{ .environ = environ };
        var audit = zstd.Secrets.Audit.init(allocator);
        defer audit.deinit();
        var database_url = try resolve(&provider, allocator, "DATABASE_URL", &audit);
        errdefer database_url.deinit();
        var s3_access = try resolve(&provider, allocator, "S3_ACCESS_KEY", &audit);
        errdefer s3_access.deinit();
        var s3_secret = try resolve(&provider, allocator, "S3_SECRET_KEY", &audit);
        errdefer s3_secret.deinit();
        var redis_password = try resolve(&provider, allocator, "REDIS_PASSWORD", &audit);
        errdefer redis_password.deinit();
        var transport_secret = try resolve(&provider, allocator, "TRANSPORT_SECRET", &audit);
        errdefer transport_secret.deinit();
        const ca = try envZ(allocator, environ, "ZIGEFFECT_TRANSPORT_CA");
        errdefer allocator.free(ca);
        return .{ .allocator = allocator, .database_url = database_url, .s3_access = s3_access, .s3_secret = s3_secret, .redis_password = redis_password, .transport_secret = transport_secret, .ca = ca };
    }
    fn release(state: *SecretState) void {
        state.database_url.deinit();
        state.s3_access.deinit();
        state.s3_secret.deinit();
        state.redis_password.deinit();
        state.transport_secret.deinit();
        state.allocator.free(state.ca);
    }
};

fn inputsLayer(inputs: RuntimeInputs) @TypeOf(kernel.Layer.succeed(RuntimeInputsService, inputs)) {
    return kernel.Layer.succeed(RuntimeInputsService, inputs);
}
fn configLayer() @TypeOf(kernel.Layer.scoped(ApplicationConfig, anyerror, .{RuntimeInputsService}, ConfigLifecycle.acquire, ConfigLifecycle.release)) {
    return kernel.Layer.scoped(ApplicationConfig, anyerror, .{RuntimeInputsService}, ConfigLifecycle.acquire, ConfigLifecycle.release);
}
fn secretsLayer() @TypeOf(kernel.Layer.scoped(RuntimeSecrets, anyerror, .{RuntimeInputsService}, SecretLifecycle.acquire, SecretLifecycle.release)) {
    return kernel.Layer.scoped(RuntimeSecrets, anyerror, .{RuntimeInputsService}, SecretLifecycle.acquire, SecretLifecycle.release);
}

const SessionConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{RuntimeSecrets})) postgres.SessionLayerConfig {
        return .{ .config = .{ .connection_url = ctx.service(RuntimeSecrets).database_url.expose() } };
    }
};
const RedisConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets })) redis.ClientConfig {
        return .{ .io = ctx.service(RuntimeInputsService).io, .options = .{ .port = ctx.service(ApplicationConfig).value.redis_port, .namespace = "zigeffect-reference", .password = ctx.service(RuntimeSecrets).redis_password.expose() } };
    }
};
const S3ConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets })) s3.ClientConfig {
        const secrets = ctx.service(RuntimeSecrets);
        return .{ .io = ctx.service(RuntimeInputsService).io, .options = .{ .port = ctx.service(ApplicationConfig).value.s3_port, .bucket = "zigeffect", .access_key = secrets.s3_access.expose(), .secret_key = secrets.s3_secret.expose() } };
    }
};
const TransportConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets })) transport.ClientConfig {
        const secrets = ctx.service(RuntimeSecrets);
        return .{ .io = ctx.service(RuntimeInputsService).io, .options = .{ .port = ctx.service(ApplicationConfig).value.worker_transport_port, .auth = .{ .mode = .shared_secret, .credential = secrets.transport_secret.expose() }, .tls = .{ .ca_path = secrets.ca, .server_name = "localhost" }, .reconnect_attempts = 2_500 } };
    }
};
const ExporterConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeInputsService })) otel.ExporterLayerConfig {
        return .{ .io = ctx.service(RuntimeInputsService).io, .options = .{ .port = ctx.service(ApplicationConfig).value.otlp_port, .retry_attempts = 1, .request_deadline_ms = 500 } };
    }
};
const HttpConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeInputsService })) http.ServerLayerConfig {
        return .{ .io = ctx.service(RuntimeInputsService).io, .options = .{ .host = "0.0.0.0", .port = ctx.service(ApplicationConfig).value.port, .max_requests_per_connection = 8 } };
    }
};

fn sessionConfigLayer() @TypeOf(kernel.Layer.sync(postgres.SessionConfigService, .{RuntimeSecrets}, SessionConfigFactory.make)) {
    return kernel.Layer.sync(postgres.SessionConfigService, .{RuntimeSecrets}, SessionConfigFactory.make);
}
fn redisConfigLayer() @TypeOf(kernel.Layer.sync(redis.ClientConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets }, RedisConfigFactory.make)) {
    return kernel.Layer.sync(redis.ClientConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets }, RedisConfigFactory.make);
}
fn s3ConfigLayer() @TypeOf(kernel.Layer.sync(s3.ClientConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets }, S3ConfigFactory.make)) {
    return kernel.Layer.sync(s3.ClientConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets }, S3ConfigFactory.make);
}
fn transportConfigLayer() @TypeOf(kernel.Layer.sync(transport.ClientConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets }, TransportConfigFactory.make)) {
    return kernel.Layer.sync(transport.ClientConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets }, TransportConfigFactory.make);
}
fn exporterConfigLayer() @TypeOf(kernel.Layer.sync(otel.ExporterConfigService, .{ ApplicationConfig, RuntimeInputsService }, ExporterConfigFactory.make)) {
    return kernel.Layer.sync(otel.ExporterConfigService, .{ ApplicationConfig, RuntimeInputsService }, ExporterConfigFactory.make);
}
fn httpConfigLayer() @TypeOf(kernel.Layer.sync(http.ServerConfigService, .{ ApplicationConfig, RuntimeInputsService }, HttpConfigFactory.make)) {
    return kernel.Layer.sync(http.ServerConfigService, .{ ApplicationConfig, RuntimeInputsService }, HttpConfigFactory.make);
}

const application_map_path = "/.well-known/zigeffect/application-map";

const ApplicationMapGuard = struct {
    credential: []const u8,

    pub fn check(self: *ApplicationMapGuard, request: zstd.Http.Request) ?zstd.External.Failure {
        const authorization = requestHeader(request, "authorization") orelse return denied();
        const prefix = "Bearer ";
        if (!std.mem.startsWith(u8, authorization, prefix) or
            !zstd.Security.secureEql(authorization[prefix.len..], self.credential)) return denied();
        return null;
    }

    fn denied() zstd.External.Failure {
        return .init("application-map", "authorize", .unauthorized, "invalid agent credential", "policy");
    }
};

const ApiRoutes = struct {
    api: *ApiHandler,
    application_map: *http.RuntimeApplicationMapHandler,

    pub fn handleAlloc(self: *ApiRoutes, allocator: std.mem.Allocator, request: zstd.Http.Request) !zstd.Http.Response {
        if (std.mem.eql(u8, request.url, application_map_path))
            return self.application_map.handleAlloc(allocator, request);
        return self.api.handleAlloc(allocator, request);
    }
};

const HandlerPartsApi = struct {
    handler: ApiHandler,
    guard: ApplicationMapGuard,
};
const HandlerParts = kernel.Service("reference/api/HandlerParts", HandlerPartsApi);
const HandlerPartsFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeSecrets, postgres.SessionService, redis.ClientService, s3.ClientService, transport.ClientService })) HandlerPartsApi {
        return .{ .handler = .{
            .database = &ctx.service(postgres.SessionService).session,
            .broker = &ctx.service(redis.ClientService).client,
            .objects = &ctx.service(s3.ClientService).client,
            .worker = &ctx.service(transport.ClientService).client,
            .allow_test_shutdown = ctx.service(ApplicationConfig).value.allow_test_shutdown,
        }, .guard = .{ .credential = ctx.service(RuntimeSecrets).transport_secret.expose() } };
    }
};
fn handlerPartsLayer() @TypeOf(kernel.Layer.sync(HandlerParts, .{ ApplicationConfig, RuntimeSecrets, postgres.SessionService, redis.ClientService, s3.ClientService, transport.ClientService }, HandlerPartsFactory.make)) {
    return kernel.Layer.sync(HandlerParts, .{ ApplicationConfig, RuntimeSecrets, postgres.SessionService, redis.ClientService, s3.ClientService, transport.ClientService }, HandlerPartsFactory.make);
}

const ApplicationMapHandler = kernel.Service("reference/api/ApplicationMapHandler", http.RuntimeApplicationMapHandler);
const ApplicationMapFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ RuntimeInputsService, HandlerParts })) anyerror!http.RuntimeApplicationMapHandler {
        return http.RuntimeApplicationMapHandler.init(
            ctx.service(RuntimeInputsService).application_map,
            application_map_path,
            http.Guard.from(ApplicationMapGuard, &ctx.service(HandlerParts).guard),
            .{ .max_recent_events = 256, .max_response_bytes = 2 * 1024 * 1024 },
        );
    }
};
fn applicationMapLayer() @TypeOf(kernel.Layer.effect(ApplicationMapHandler, anyerror, .{ RuntimeInputsService, HandlerParts }, ApplicationMapFactory.make)) {
    return kernel.Layer.effect(ApplicationMapHandler, anyerror, .{ RuntimeInputsService, HandlerParts }, ApplicationMapFactory.make);
}

const ApplicationRoutes = kernel.Service("reference/api/Routes", ApiRoutes);
const RoutesFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ HandlerParts, ApplicationMapHandler })) ApiRoutes {
        return .{ .api = &ctx.service(HandlerParts).handler, .application_map = ctx.service(ApplicationMapHandler) };
    }
};
fn routesLayer() @TypeOf(kernel.Layer.sync(ApplicationRoutes, .{ HandlerParts, ApplicationMapHandler }, RoutesFactory.make)) {
    return kernel.Layer.sync(ApplicationRoutes, .{ HandlerParts, ApplicationMapHandler }, RoutesFactory.make);
}

const ApplicationPolicy = kernel.Service("reference/api/Policy", http.PolicyHandler);
const PolicyFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ApplicationRoutes})) anyerror!http.PolicyHandler {
        return http.PolicyHandler.init(http.Handler.from(ApiRoutes, ctx.service(ApplicationRoutes)), .{ .secure_headers = true });
    }
};
fn policyLayer() @TypeOf(kernel.Layer.effect(ApplicationPolicy, anyerror, .{ApplicationRoutes}, PolicyFactory.make)) {
    return kernel.Layer.effect(ApplicationPolicy, anyerror, .{ApplicationRoutes}, PolicyFactory.make);
}
const HandlerFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ApplicationPolicy})) http.Handler {
        return ctx.service(ApplicationPolicy).asHandler();
    }
};
fn handlerLayer() @TypeOf(kernel.Layer.sync(http.HandlerService, .{ApplicationPolicy}, HandlerFactory.make)) {
    return kernel.Layer.sync(http.HandlerService, .{ApplicationPolicy}, HandlerFactory.make);
}

fn foundationsLayer(inputs: RuntimeInputs) @TypeOf(secretsLayer().provideMerge(configLayer().provideMerge(inputsLayer(inputs)))) {
    return secretsLayer().provideMerge(configLayer().provideMerge(inputsLayer(inputs)));
}
fn sessionStack(foundations: anytype) @TypeOf(postgres.sessionLayer().provideMerge(sessionConfigLayer().provideMerge(foundations))) {
    return postgres.sessionLayer().provideMerge(sessionConfigLayer().provideMerge(foundations));
}
fn redisStack(foundations: anytype) @TypeOf(redis.clientLayer().provideMerge(redisConfigLayer().provideMerge(foundations))) {
    return redis.clientLayer().provideMerge(redisConfigLayer().provideMerge(foundations));
}
fn s3Stack(foundations: anytype) @TypeOf(s3.clientLayer().provideMerge(s3ConfigLayer().provideMerge(foundations))) {
    return s3.clientLayer().provideMerge(s3ConfigLayer().provideMerge(foundations));
}
fn transportStack(foundations: anytype) @TypeOf(transport.clientLayer().provideMerge(transportConfigLayer().provideMerge(foundations))) {
    return transport.clientLayer().provideMerge(transportConfigLayer().provideMerge(foundations));
}
fn exporterStack(foundations: anytype) @TypeOf(otel.exporterLayer().provideMerge(exporterConfigLayer().provideMerge(foundations))) {
    return otel.exporterLayer().provideMerge(exporterConfigLayer().provideMerge(foundations));
}
fn resourceLayers(foundations: anytype) @TypeOf(kernel.Layer.mergeAll(.{ sessionStack(foundations), redisStack(foundations), s3Stack(foundations), transportStack(foundations), exporterStack(foundations) })) {
    return kernel.Layer.mergeAll(.{ sessionStack(foundations), redisStack(foundations), s3Stack(foundations), transportStack(foundations), exporterStack(foundations) });
}
fn handlerStack(resources: anytype) @TypeOf(handlerLayer().provideMerge(policyLayer().provideMerge(routesLayer().provideMerge(applicationMapLayer().provideMerge(handlerPartsLayer().provideMerge(resources)))))) {
    return handlerLayer().provideMerge(policyLayer().provideMerge(routesLayer().provideMerge(applicationMapLayer().provideMerge(handlerPartsLayer().provideMerge(resources)))));
}
fn serverStack(resources: anytype) @TypeOf(http.serverLayer().provideMerge(httpConfigLayer().provideMerge(handlerStack(resources)))) {
    return http.serverLayer().provideMerge(httpConfigLayer().provideMerge(handlerStack(resources)));
}

pub fn rootLayer(inputs: RuntimeInputs) @TypeOf(kernel.Layer.mergeAll(.{ serverStack(resourceLayers(foundationsLayer(inputs))), zstd.Application.Lifecycle.managerLayer(), zstd.Application.Lifecycle.signalLayer() })) {
    const foundations = foundationsLayer(inputs);
    const resources = resourceLayers(foundations);
    return kernel.Layer.mergeAll(.{ serverStack(resources), zstd.Application.Lifecycle.managerLayer(), zstd.Application.Lifecycle.signalLayer() });
}

const migrations = [_]zstd.Sql.Migration{
    .{ .id = "001_reference_orders", .sql = "create table if not exists reference_orders (id text primary key, idempotency_key text unique not null, attachment_key text not null, status text not null, version bigint not null)" },
    .{ .id = "002_reference_outbox", .sql = "create table if not exists reference_outbox (idempotency_key text primary key, order_id text not null, dispatched boolean not null default false)" },
};
fn discardMigrations(report: postgres.MigrationReport) void {
    var owned = report;
    owned.deinit();
}
const EmitReady = kernel.Effect(void, anyerror, .{otel.ExporterService});
fn emitReady() EmitReady {
    return EmitReady.fromFn(struct {
        fn run(ctx: *EmitReady.Context) anyerror!void {
            const exporter = &ctx.service(otel.ExporterService).exporter;
            try exporter.enqueue(.logs, "{\"resourceLogs\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"reference-api\"}}]},\"scopeLogs\":[{\"logRecords\":[{\"body\":{\"stringValue\":\"ready\"}}]}]}]}");
            try exporter.flush();
        }
    }.run);
}
const ServeConnections = kernel.Effect(void, anyerror, .{ ApplicationConfig, http.ServerService, zstd.Application.Lifecycle.ProcessSignals });
fn serveConnections() ServeConnections {
    return ServeConnections.fromFn(struct {
        fn run(ctx: *ServeConnections.Context) anyerror!void {
            _ = ctx.service(zstd.Application.Lifecycle.ProcessSignals);
            const expected = ctx.service(ApplicationConfig).value.expected_connections;
            var served: usize = 0;
            while (expected == null or served < expected.?) {
                _ = ctx.service(http.ServerService).server.serveOne(ctx.allocator()) catch |failure| {
                    if (zstd.Application.Lifecycle.requestedSignal() != .none) break;
                    return failure;
                };
                served += 1;
                if (zstd.Application.Lifecycle.requestedSignal() != .none) break;
            }
            _ = zstd.Service.recordSemantic(ctx, .activity_completed, http.ServerService.service_key, "reference.api.serve", "success", "bounded connections served");
        }
    }.run);
}
fn discardShutdown(_: http.ShutdownReport) void {}

pub fn program() @TypeOf(zstd.Application.Lifecycle.start().andThen(postgres.applyMigrationsEffect(.{}, &migrations).map(discardMigrations)).andThen(emitReady()).andThen(zstd.Application.Lifecycle.ready()).andThen(serveConnections()).andThen(zstd.Application.Lifecycle.drain()).andThen(http.shutdownServerEffect(.{ .deadline_ms = 5_000 }).map(discardShutdown)).andThen(otel.shutdownExporterEffect()).andThen(zstd.Application.Lifecycle.stop()).named("reference.api")) {
    return zstd.Application.Lifecycle.start().andThen(postgres.applyMigrationsEffect(.{}, &migrations).map(discardMigrations)).andThen(emitReady()).andThen(zstd.Application.Lifecycle.ready()).andThen(serveConnections()).andThen(zstd.Application.Lifecycle.drain()).andThen(http.shutdownServerEffect(.{ .deadline_ms = 5_000 }).map(discardShutdown)).andThen(otel.shutdownExporterEffect()).andThen(zstd.Application.Lifecycle.stop()).named("reference.api");
}

pub fn run(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, environ: std.process.Environ) !void {
    var application_map_slot = http.ApplicationMapSlot{};
    const layer = rootLayer(.{ .io = io, .environ = environ, .application_map = &application_map_slot });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(allocator, io, root, layer, .{});
    defer runtime.deinit();
    try application_map_slot.install(@TypeOf(runtime), &runtime);
    defer application_map_slot.clear();
    try runtime.run(program());
    var inspection = try runtime.inspect(allocator, .{ .max_recent_events = 128 });
    defer inspection.deinit();
    if (inspection.services.len < 16 or inspection.causal.findings.len != 0) return error.InvalidApplicationSnapshot;
    const application_map = try runtime.agentMapJsonAlloc(allocator, .{ .max_recent_events = 128 });
    defer allocator.free(application_map);
    if (application_map.len == 0 or runtime.causalHealth().status != .healthy) return error.MissingApplicationEvidence;
    try runtime.shutdown();
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
fn exec(session: *postgres.Session, allocator: std.mem.Allocator, statement: zstd.Sql.Statement) !void {
    var result = try session.queryAlloc(allocator, statement);
    result.deinit(allocator);
}
fn jsonResponse(allocator: std.mem.Allocator, status: u16, value: anytype) !zstd.Http.Response {
    const body = try zstd.Secrets.safeJsonAlloc(allocator, value, .{});
    defer allocator.free(body);
    return zstd.Http.cloneResponseAlloc(allocator, .{ .status = status, .headers = &.{.{ .name = "Content-Type", .value = "application/json" }}, .body = body });
}
fn requestHeader(request: zstd.Http.Request, name: []const u8) ?[]const u8 {
    for (request.headers) |header| if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
    return null;
}
fn resolve(provider: *zstd.Secrets.EnvironmentProvider, allocator: std.mem.Allocator, key: []const u8, audit: *zstd.Secrets.Audit) !zstd.Secrets.Value {
    return provider.resolveAlloc(allocator, .{ .provider = "environment", .key = key }, audit);
}
fn envAlloc(allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) ![]u8 {
    return std.process.Environ.getAlloc(environ, allocator, key) catch error.MissingProductionConfiguration;
}
fn envZ(allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) ![:0]u8 {
    const value = try envAlloc(allocator, environ, key);
    defer allocator.free(value);
    return allocator.dupeZ(u8, value);
}
fn envInt(comptime T: type, allocator: std.mem.Allocator, environ: std.process.Environ, key: []const u8) !T {
    const value = try envAlloc(allocator, environ, key);
    defer allocator.free(value);
    return std.fmt.parseUnsigned(T, value, 10) catch error.InvalidProductionConfiguration;
}
