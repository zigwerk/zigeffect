const std = @import("std");
const zstd = @import("zigeffect_std");
const postgres = @import("zigeffect_postgres_libpq");
const otel = @import("zigeffect_otel");
const redis = @import("zigeffect_redis");
const transport = @import("zigeffect_transport");
const storage = @import("zigeffect_storage_postgres");
const shared = @import("shared");
const kernel = zstd.fx.kernel;

pub const Config = struct { redis_port: u16, transport_port: u16, otlp_port: u16, poll_deadline_ms: u64, expected_orders: usize };
pub const config_schema = zstd.Schema.structSchema(Config, .{
    zstd.Schema.field("redis_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("transport_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("otlp_port", zstd.Schema.integer().min(1).max(65535)),
    zstd.Schema.field("poll_deadline_ms", zstd.Schema.integer().min(100).max(300_000)),
    zstd.Schema.field("expected_orders", zstd.Schema.integer().min(1).max(10_000)),
});

pub fn compileContract() bool {
    return @hasDecl(postgres, "SessionService") and @hasDecl(postgres, "PoolService") and
        @hasDecl(storage, "RunnerStorageService") and @hasDecl(storage, "migrationEffect") and
        @hasDecl(otel, "ExporterService") and @hasDecl(redis, "ClientService") and
        @hasDecl(transport, "ServerService") and @hasDecl(transport, "serveOneEffect") and
        @hasDecl(shared, "statechart") and @hasDecl(zstd, "ManagedRuntime");
}

pub const RuntimeInputs = struct { io: std.Io, environ: std.process.Environ };
const RuntimeInputsService = kernel.Service("reference/worker/RuntimeInputs", RuntimeInputs);
pub const ConfigApi = struct {
    pub const operations: []const []const u8 = &.{"ReferenceWorkerConfig.read"};
    value: Config,
};
pub const ApplicationConfig = kernel.Service("reference/worker/Config", ConfigApi);

const ConfigLifecycle = struct {
    fn acquire(ctx: *kernel.ContextView(.{RuntimeInputsService})) anyerror!ConfigApi {
        return .{ .value = try loadConfig(ctx.allocator(), ctx.service(RuntimeInputsService).environ) };
    }
    fn release(_: *ConfigApi) void {}
};

const SecretState = struct {
    allocator: std.mem.Allocator,
    database_url: zstd.Secrets.Value,
    redis_password: zstd.Secrets.Value,
    transport_secret: zstd.Secrets.Value,
    certificate: [:0]u8,
    private_key: [:0]u8,
};
const RuntimeSecrets = kernel.Service("reference/worker/Secrets", SecretState);
const SecretLifecycle = struct {
    fn acquire(ctx: *kernel.ContextView(.{RuntimeInputsService})) anyerror!SecretState {
        const allocator = ctx.allocator();
        const environ = ctx.service(RuntimeInputsService).environ;
        var provider = zstd.Secrets.EnvironmentProvider{ .environ = environ };
        var audit = zstd.Secrets.Audit.init(allocator);
        defer audit.deinit();
        var database_url = try resolve(&provider, allocator, "DATABASE_URL", &audit);
        errdefer database_url.deinit();
        var redis_password = try resolve(&provider, allocator, "REDIS_PASSWORD", &audit);
        errdefer redis_password.deinit();
        var transport_secret = try resolve(&provider, allocator, "TRANSPORT_SECRET", &audit);
        errdefer transport_secret.deinit();
        const certificate = try envZ(allocator, environ, "ZIGEFFECT_TRANSPORT_SERVER_CERT");
        errdefer allocator.free(certificate);
        const private_key = try envZ(allocator, environ, "ZIGEFFECT_TRANSPORT_SERVER_KEY");
        errdefer allocator.free(private_key);
        return .{ .allocator = allocator, .database_url = database_url, .redis_password = redis_password, .transport_secret = transport_secret, .certificate = certificate, .private_key = private_key };
    }
    fn release(state: *SecretState) void {
        state.database_url.deinit();
        state.redis_password.deinit();
        state.transport_secret.deinit();
        state.allocator.free(state.certificate);
        state.allocator.free(state.private_key);
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
const PoolConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ RuntimeInputsService, RuntimeSecrets })) postgres.PoolLayerConfig {
        return .{ .io = ctx.service(RuntimeInputsService).io, .config = .{ .session = .{ .connection_url = ctx.service(RuntimeSecrets).database_url.expose() }, .size = 2 } };
    }
};
const RedisConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets })) redis.ClientConfig {
        return .{ .io = ctx.service(RuntimeInputsService).io, .options = .{ .port = ctx.service(ApplicationConfig).value.redis_port, .namespace = "zigeffect-reference", .password = ctx.service(RuntimeSecrets).redis_password.expose() } };
    }
};
const ExporterConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeInputsService })) otel.ExporterLayerConfig {
        return .{ .io = ctx.service(RuntimeInputsService).io, .options = .{ .port = ctx.service(ApplicationConfig).value.otlp_port, .retry_attempts = 1, .request_deadline_ms = 500 } };
    }
};
fn sessionConfigLayer() @TypeOf(kernel.Layer.sync(postgres.SessionConfigService, .{RuntimeSecrets}, SessionConfigFactory.make)) {
    return kernel.Layer.sync(postgres.SessionConfigService, .{RuntimeSecrets}, SessionConfigFactory.make);
}
fn poolConfigLayer() @TypeOf(kernel.Layer.sync(postgres.PoolConfigService, .{ RuntimeInputsService, RuntimeSecrets }, PoolConfigFactory.make)) {
    return kernel.Layer.sync(postgres.PoolConfigService, .{ RuntimeInputsService, RuntimeSecrets }, PoolConfigFactory.make);
}
fn redisConfigLayer() @TypeOf(kernel.Layer.sync(redis.ClientConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets }, RedisConfigFactory.make)) {
    return kernel.Layer.sync(redis.ClientConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets }, RedisConfigFactory.make);
}
fn exporterConfigLayer() @TypeOf(kernel.Layer.sync(otel.ExporterConfigService, .{ ApplicationConfig, RuntimeInputsService }, ExporterConfigFactory.make)) {
    return kernel.Layer.sync(otel.ExporterConfigService, .{ ApplicationConfig, RuntimeInputsService }, ExporterConfigFactory.make);
}

const MessageStorage = kernel.Service("reference/worker/MessageStorage", transport.fx.InMemoryMessageStorage);
const MessageStorageLifecycle = struct {
    fn acquire(ctx: *kernel.ContextView(.{})) anyerror!transport.fx.InMemoryMessageStorage {
        return transport.fx.InMemoryMessageStorage.init(ctx.allocator());
    }
    fn release(messages: *transport.fx.InMemoryMessageStorage) void {
        messages.deinit();
    }
};
fn messageStorageLayer() @TypeOf(kernel.Layer.scoped(MessageStorage, anyerror, .{}, MessageStorageLifecycle.acquire, MessageStorageLifecycle.release)) {
    return kernel.Layer.scoped(MessageStorage, anyerror, .{}, MessageStorageLifecycle.acquire, MessageStorageLifecycle.release);
}

const MessageHandler = kernel.Service("reference/worker/MessageHandler", transport.StorageHandler);
const MessageHandlerLifecycle = struct {
    fn acquire(ctx: *kernel.ContextView(.{MessageStorage})) anyerror!transport.StorageHandler {
        return transport.StorageHandler.init(ctx.allocator(), ctx.service(MessageStorage).asMessageStorage(), 32);
    }
    fn release(handler: *transport.StorageHandler) void {
        handler.deinit();
    }
};
fn messageHandlerLayer() @TypeOf(kernel.Layer.scoped(MessageHandler, anyerror, .{MessageStorage}, MessageHandlerLifecycle.acquire, MessageHandlerLifecycle.release)) {
    return kernel.Layer.scoped(MessageHandler, anyerror, .{MessageStorage}, MessageHandlerLifecycle.acquire, MessageHandlerLifecycle.release);
}
const ServerConfigFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets, MessageHandler })) transport.ServerConfig {
        const secrets = ctx.service(RuntimeSecrets);
        return .{ .io = ctx.service(RuntimeInputsService).io, .options = .{ .port = ctx.service(ApplicationConfig).value.transport_port, .limits = .{ .max_requests_per_connection = 1 }, .auth = .{ .mode = .shared_secret, .credential = secrets.transport_secret.expose() }, .tls = .{ .certificate_chain_path = secrets.certificate, .private_key_path = secrets.private_key } }, .handler = transport.Handler.from(transport.StorageHandler, ctx.service(MessageHandler)) };
    }
};
fn serverConfigLayer() @TypeOf(kernel.Layer.sync(transport.ServerConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets, MessageHandler }, ServerConfigFactory.make)) {
    return kernel.Layer.sync(transport.ServerConfigService, .{ ApplicationConfig, RuntimeInputsService, RuntimeSecrets, MessageHandler }, ServerConfigFactory.make);
}

pub const LeaseApi = struct {
    pub const operations: []const []const u8 = &.{"WorkerLease.current"};
    storage: *storage.PostgresRunnerStorage,
    owner: transport.fx.RunnerAddress,
    lease: transport.fx.ShardLease,
};
pub const WorkerLease = kernel.Service("reference/worker/Lease", LeaseApi);
const LeaseLifecycle = struct {
    fn acquire(ctx: *kernel.ContextView(.{ ApplicationConfig, RuntimeInputsService, storage.RunnerStorageService })) anyerror!LeaseApi {
        const durable = &ctx.service(storage.RunnerStorageService).storage;
        const owner = transport.fx.RunnerAddress{ .machine_id = 1, .runner_id = 1 };
        var clock = zstd.Clock.RealClock.init(ctx.service(RuntimeInputsService).io);
        const now = clock.asService().snapshot().wall_millis;
        const lease = try durable.acquire(.{ .shard_id = 1, .owner = owner, .now_ms = now, .ttl_ms = ctx.service(ApplicationConfig).value.poll_deadline_ms + 10_000 });
        return .{ .storage = durable, .owner = owner, .lease = lease };
    }
    fn release(api: *LeaseApi) void {
        api.storage.release(.{ .shard_id = api.lease.shard_id, .owner = api.owner }) catch {};
    }
};
fn leaseLayer() @TypeOf(kernel.Layer.scoped(WorkerLease, anyerror, .{ ApplicationConfig, RuntimeInputsService, storage.RunnerStorageService }, LeaseLifecycle.acquire, LeaseLifecycle.release)) {
    return kernel.Layer.scoped(WorkerLease, anyerror, .{ ApplicationConfig, RuntimeInputsService, storage.RunnerStorageService }, LeaseLifecycle.acquire, LeaseLifecycle.release);
}

pub const OrderProcessorApi = struct {
    pub const operations: []const []const u8 = &.{"OrderWorkflow.process"};
    database: *postgres.Session,
    pool: *postgres.Pool,
    broker: *redis.Client,
    lease: *LeaseApi,
};
pub const OrderProcessor = kernel.Service("reference/worker/OrderProcessor", OrderProcessorApi);
const OrderProcessorFactory = struct {
    fn make(ctx: *kernel.ContextView(.{ postgres.SessionService, postgres.PoolService, redis.ClientService, WorkerLease })) OrderProcessorApi {
        return .{ .database = &ctx.service(postgres.SessionService).session, .pool = &ctx.service(postgres.PoolService).pool, .broker = &ctx.service(redis.ClientService).client, .lease = ctx.service(WorkerLease) };
    }
};
fn orderProcessorLayer() @TypeOf(kernel.Layer.sync(OrderProcessor, .{ postgres.SessionService, postgres.PoolService, redis.ClientService, WorkerLease }, OrderProcessorFactory.make)) {
    return kernel.Layer.sync(OrderProcessor, .{ postgres.SessionService, postgres.PoolService, redis.ClientService, WorkerLease }, OrderProcessorFactory.make);
}

const ProcessOrder = kernel.Effect(void, anyerror, .{OrderProcessor}).Stateful(*const zstd.Broker.Delivery);
fn processOrder(delivery: *const zstd.Broker.Delivery) ProcessOrder {
    return ProcessOrder.init(delivery, struct {
        fn run(item: *const zstd.Broker.Delivery, ctx: *ProcessOrder.Context) anyerror!void {
            const service = ctx.service(OrderProcessor);
            var journal = try storage.PostgresJournalStore.init(ctx.allocator(), service.pool, .{ .storage = .{ .table_prefix = "reference_runtime" }, .workflow_id = std.hash.Wyhash.hash(0, item.payload), .execution_id = 1, .required_fence = .{ .shard_id = service.lease.lease.shard_id, .epoch = service.lease.lease.epoch } });
            const started_key = try std.fmt.allocPrint(ctx.allocator(), "{s}-started", .{item.idempotency_key});
            defer ctx.allocator().free(started_key);
            const completed_key = try std.fmt.allocPrint(ctx.allocator(), "{s}-completed", .{item.idempotency_key});
            defer ctx.allocator().free(completed_key);
            _ = try journal.appendIdempotent(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = journal.config.workflow_id, .execution_id = 1, .idempotency_key = item.idempotency_key } });
            _ = try journal.appendIdempotent(.{ .event = .{ .sequence = 2, .kind = .activity_started, .workflow_id = journal.config.workflow_id, .execution_id = 1, .activity_id = 1, .name = "complete-order", .idempotency_key = started_key } });
            try service.database.begin();
            errdefer service.database.rollback() catch {};
            const processing = try shared.advance(.pending, .claim);
            _ = ctx.recordCausal(.{ .kind = .statechart_event_recorded, .service_key = OrderProcessor.service_key, .artifact_id = "statechart:orders.processing", .domain_entity_ref = item.payload, .label = "claim", .status = "committed", .redacted_detail = "pending -> processing" });
            const completed = try shared.advance(processing, .complete);
            _ = ctx.recordCausal(.{ .kind = .statechart_event_recorded, .service_key = OrderProcessor.service_key, .artifact_id = "statechart:orders.processing", .domain_entity_ref = item.payload, .label = "complete", .status = "committed", .redacted_detail = "processing -> completed" });
            try exec(service.database, ctx.allocator(), .{ .sql = "update reference_orders set status=$2,version=version+1 where id=$1 and status='pending'", .binds = &.{ .{ .text = item.payload }, .{ .text = @tagName(processing) } } });
            try exec(service.database, ctx.allocator(), .{ .sql = "update reference_orders set status=$2,version=version+1 where id=$1 and status='processing'", .binds = &.{ .{ .text = item.payload }, .{ .text = @tagName(completed) } } });
            try service.database.commit();
            _ = try journal.appendIdempotent(.{ .event = .{ .sequence = 3, .kind = .activity_completed, .workflow_id = journal.config.workflow_id, .execution_id = 1, .activity_id = 1, .name = "complete-order", .idempotency_key = completed_key } });
            try service.broker.ack(item.id, "worker-process");
            _ = zstd.Service.recordSemantic(ctx, .activity_completed, OrderProcessor.service_key, "OrderWorkflow.process", "success", "workflow journal and statechart committed");
        }
    }.run);
}

fn foundationsLayer(inputs: RuntimeInputs) @TypeOf(secretsLayer().provideMerge(configLayer().provideMerge(inputsLayer(inputs)))) {
    return secretsLayer().provideMerge(configLayer().provideMerge(inputsLayer(inputs)));
}
fn sessionStack(foundations: anytype) @TypeOf(postgres.sessionLayer().provideMerge(sessionConfigLayer().provideMerge(foundations))) {
    return postgres.sessionLayer().provideMerge(sessionConfigLayer().provideMerge(foundations));
}
fn poolStack(foundations: anytype) @TypeOf(postgres.poolLayer().provideMerge(poolConfigLayer().provideMerge(foundations))) {
    return postgres.poolLayer().provideMerge(poolConfigLayer().provideMerge(foundations));
}
fn redisStack(foundations: anytype) @TypeOf(redis.clientLayer().provideMerge(redisConfigLayer().provideMerge(foundations))) {
    return redis.clientLayer().provideMerge(redisConfigLayer().provideMerge(foundations));
}
fn exporterStack(foundations: anytype) @TypeOf(otel.exporterLayer().provideMerge(exporterConfigLayer().provideMerge(foundations))) {
    return otel.exporterLayer().provideMerge(exporterConfigLayer().provideMerge(foundations));
}
fn baseResources(foundations: anytype) @TypeOf(kernel.Layer.mergeAll(.{ sessionStack(foundations), poolStack(foundations), redisStack(foundations), exporterStack(foundations), messageHandlerLayer().provideMerge(messageStorageLayer()) })) {
    return kernel.Layer.mergeAll(.{ sessionStack(foundations), poolStack(foundations), redisStack(foundations), exporterStack(foundations), messageHandlerLayer().provideMerge(messageStorageLayer()) });
}
fn runnerStack(resources: anytype) @TypeOf(storage.runnerStorageLayer().provideMerge(storage.runnerStorageConfigLayer(.{ .table_prefix = "reference_runtime" }).provideMerge(resources))) {
    return storage.runnerStorageLayer().provideMerge(storage.runnerStorageConfigLayer(.{ .table_prefix = "reference_runtime" }).provideMerge(resources));
}
fn workflowStack(resources: anytype) @TypeOf(orderProcessorLayer().provideMerge(leaseLayer().provideMerge(runnerStack(resources)))) {
    return orderProcessorLayer().provideMerge(leaseLayer().provideMerge(runnerStack(resources)));
}
fn serverStack(resources: anytype) @TypeOf(transport.serverLayer().provideMerge(serverConfigLayer().provideMerge(workflowStack(resources)))) {
    return transport.serverLayer().provideMerge(serverConfigLayer().provideMerge(workflowStack(resources)));
}

pub fn rootLayer(inputs: RuntimeInputs) @TypeOf(kernel.Layer.mergeAll(.{ serverStack(baseResources(foundationsLayer(inputs))), zstd.Application.Lifecycle.managerLayer(), zstd.Application.Lifecycle.signalLayer() })) {
    const foundations = foundationsLayer(inputs);
    const resources = baseResources(foundations);
    return kernel.Layer.mergeAll(.{ serverStack(resources), zstd.Application.Lifecycle.managerLayer(), zstd.Application.Lifecycle.signalLayer() });
}

fn discardMigration(receipt: storage.MigrationReceipt) void {
    var owned = receipt;
    owned.deinit();
}
const EmitReady = kernel.Effect(void, anyerror, .{otel.ExporterService});
fn emitReady() EmitReady {
    return EmitReady.fromFn(struct {
        fn run(ctx: *EmitReady.Context) anyerror!void {
            const exporter = &ctx.service(otel.ExporterService).exporter;
            try exporter.enqueue(.logs, "{\"resourceLogs\":[{\"resource\":{\"attributes\":[{\"key\":\"service.name\",\"value\":{\"stringValue\":\"reference-worker\"}}]},\"scopeLogs\":[{\"logRecords\":[{\"body\":{\"stringValue\":\"ready\"}}]}]}]}");
            try exporter.flush();
        }
    }.run);
}

fn ServerContext(comptime Handle: type) type {
    return struct {
        runtime: Handle,
        expected: usize,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            for (0..self.expected) |_| {
                const handled = self.runtime.run(transport.serveOneEffect()) catch |failure| {
                    self.failure = failure;
                    return;
                };
                if (handled == 0) {
                    self.failure = error.NoTransportRequest;
                    return;
                }
            }
        }
    };
}
const WorkLoop = kernel.Effect(void, anyerror, .{ ApplicationConfig, RuntimeInputsService, OrderProcessor, redis.ClientService, transport.ServerService, zstd.Application.Lifecycle.ProcessSignals });
fn workLoop() WorkLoop {
    return WorkLoop.fromFn(struct {
        fn run(ctx: *WorkLoop.Context) anyerror!void {
            _ = ctx.service(zstd.Application.Lifecycle.ProcessSignals);
            const config = ctx.service(ApplicationConfig).value;
            const io = ctx.service(RuntimeInputsService).io;
            const server_handle = ctx.runtime();
            var server_context = ServerContext(@TypeOf(server_handle)){ .runtime = server_handle, .expected = config.expected_orders };
            const server_thread = try std.Thread.spawn(.{}, ServerContext(@TypeOf(server_handle)).run, .{&server_context});
            const started = std.Io.Clock.Timestamp.now(io, .awake);
            var processed: usize = 0;
            while (processed < config.expected_orders and elapsedMs(started, std.Io.Clock.Timestamp.now(io, .awake)) < config.poll_deadline_ms and zstd.Application.Lifecycle.requestedSignal() == .none) {
                if (try ctx.service(redis.ClientService).client.pollAlloc(ctx.allocator(), "orders", "worker-process", 2_000)) |delivery_value| {
                    var delivery = delivery_value;
                    defer delivery.deinit();
                    var child = ctx.runtime();
                    try child.run(processOrder(&delivery));
                    processed += 1;
                } else try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(10), .clock = .awake }).sleep(io);
            }
            if (processed != config.expected_orders) {
                ctx.service(transport.ServerService).server.drain();
                server_thread.join();
                return error.WorkerPollDeadlineExceeded;
            }
            server_thread.join();
            if (server_context.failure) |failure| return failure;
            _ = zstd.Service.recordSemantic(ctx, .activity_completed, OrderProcessor.service_key, "OrderWorkflow.loop", "success", "expected orders processed");
        }
    }.run);
}

pub fn program() @TypeOf(zstd.Application.Lifecycle.start().andThen(storage.migrationEffect(.{ .table_prefix = "reference_runtime" }, .postgresql).map(discardMigration)).andThen(emitReady()).andThen(zstd.Application.Lifecycle.ready()).andThen(workLoop()).andThen(zstd.Application.Lifecycle.drain()).andThen(transport.drainServerEffect()).andThen(otel.shutdownExporterEffect()).andThen(postgres.closePoolEffect()).andThen(zstd.Application.Lifecycle.stop()).named("reference.worker")) {
    return zstd.Application.Lifecycle.start().andThen(storage.migrationEffect(.{ .table_prefix = "reference_runtime" }, .postgresql).map(discardMigration)).andThen(emitReady()).andThen(zstd.Application.Lifecycle.ready()).andThen(workLoop()).andThen(zstd.Application.Lifecycle.drain()).andThen(transport.drainServerEffect()).andThen(otel.shutdownExporterEffect()).andThen(postgres.closePoolEffect()).andThen(zstd.Application.Lifecycle.stop()).named("reference.worker");
}

pub fn run(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, environ: std.process.Environ) !void {
    const layer = rootLayer(.{ .io = io, .environ = environ });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(allocator, io, root, layer, .{});
    defer runtime.deinit();
    try runtime.run(program());
    var inspection = try runtime.inspect(allocator, .{ .max_recent_events = 128 });
    defer inspection.deinit();
    if (inspection.services.len < 17 or inspection.causal.findings.len != 0) return error.InvalidApplicationSnapshot;
    const application_map = try runtime.agentMapJsonAlloc(allocator, .{ .max_recent_events = 128 });
    defer allocator.free(application_map);
    if (application_map.len == 0 or runtime.causalHealth().status != .healthy) return error.MissingApplicationEvidence;
    try runtime.shutdown();
}

fn exec(session: *postgres.Session, allocator: std.mem.Allocator, statement: zstd.Sql.Statement) !void {
    var result = try session.queryAlloc(allocator, statement);
    result.deinit(allocator);
}
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
fn elapsedMs(start: std.Io.Clock.Timestamp, end: std.Io.Clock.Timestamp) u64 {
    return @intCast(@max(0, start.durationTo(end).raw.toMilliseconds()));
}
