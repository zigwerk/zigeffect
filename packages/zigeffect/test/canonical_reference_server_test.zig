const std = @import("std");
const fx = @import("zigeffect");

const kernel = fx.kernel;

pub const Todo = struct {
    id: u32,
    title: []const u8,
};

pub const RepositoryError = error{NotFound};

pub const AppConfig = kernel.Service("reference/AppConfig", struct {
    first_id: u32,
});

const RepositoryReadState = struct {
    repository: *Repository.API,
    id: u32,
};

const RepositoryReadBase = kernel.Effect(Todo, RepositoryError, .{});
pub const RepositoryRead = RepositoryReadBase.Stateful(RepositoryReadState);

pub const Repository = kernel.Service("reference/Repository", struct {
    first_id: u32,

    pub fn get(self: *@This(), id: u32) RepositoryRead {
        return RepositoryRead.init(.{ .repository = self, .id = id }, struct {
            fn run(state: RepositoryReadState, _: *RepositoryRead.Context) RepositoryError!Todo {
                if (state.id < state.repository.first_id or state.id > state.repository.first_id + 1) {
                    return error.NotFound;
                }
                return .{
                    .id = state.id,
                    .title = if (state.id == state.repository.first_id) "compose layers" else "reuse runtime",
                };
            }
        }.run);
    }
});

pub const TodoApi = kernel.Service("reference/TodoApi", struct {
    repository: *Repository.API,

    pub fn get(self: *@This(), id: u32) RepositoryRead {
        return self.repository.get(id);
    }
});

const HealthCheckState = struct {
    health: *Health.API,
};

const HealthCheckBase = kernel.Effect(bool, error{}, .{});
pub const HealthCheck = HealthCheckBase.Stateful(HealthCheckState);

pub const Health = kernel.Service("reference/Health", struct {
    ready: bool,

    pub fn check(self: *@This()) HealthCheck {
        return HealthCheck.init(.{ .health = self }, struct {
            fn run(state: HealthCheckState, _: *HealthCheck.Context) error{}!bool {
                return state.health.ready;
            }
        }.run);
    }
});

pub const Request = union(enum) {
    get_todo: u32,
    health,
    application_map,
};

pub const ServeSummary = struct {
    requests: usize = 0,
    todos: usize = 0,
    health_checks: usize = 0,
    application_maps: usize = 0,
    application_map_bytes: usize = 0,
};

const ResolvedTodoApi = struct { api: *TodoApi.API, id: u32 };
const ResolveTodoApiBase = kernel.Effect(ResolvedTodoApi, error{}, .{TodoApi});
const ResolveTodoApi = ResolveTodoApiBase.Stateful(u32);

fn resolveTodoApi(id: u32) ResolveTodoApi {
    return ResolveTodoApi.init(id, struct {
        fn run(request_id: u32, ctx: *ResolveTodoApi.Context) error{}!ResolvedTodoApi {
            return .{ .api = ctx.service(TodoApi), .id = request_id };
        }
    }.run);
}

fn invokeTodoApi(resolved: ResolvedTodoApi) RepositoryRead {
    return resolved.api.get(resolved.id);
}

fn getEndpoint(id: u32) @TypeOf(resolveTodoApi(id).flatMap(invokeTodoApi).named("TodoApi.get")) {
    return resolveTodoApi(id).flatMap(invokeTodoApi).named("TodoApi.get");
}

const ResolveHealth = kernel.Effect(*Health.API, error{}, .{Health});
const resolve_health = ResolveHealth.fromFn(struct {
    fn run(ctx: *ResolveHealth.Context) error{}!*Health.API {
        return ctx.service(Health);
    }
}.run);

fn invokeHealth(health: *Health.API) HealthCheck {
    return health.check();
}

const health_endpoint = resolve_health.flatMap(invokeHealth).named("Health.check");

const ServeState = struct { requests: []const Request };
const ServeError = RepositoryError || std.mem.Allocator.Error || error{InvalidApplicationMap};
const ServeBase = kernel.Effect(ServeSummary, ServeError, .{ TodoApi, Health });
pub const Serve = ServeBase.Stateful(ServeState);

/// The transport owns one bounded RuntimeHandle and interprets every request
/// in a fresh child scope. A socket or gRPC adapter can drive the same shape.
pub fn serve(requests: []const Request) Serve {
    return Serve.init(.{ .requests = requests }, struct {
        fn run(state: ServeState, ctx: *Serve.Context) ServeError!ServeSummary {
            var runtime = ctx.runtime();
            var summary = ServeSummary{};
            for (state.requests) |request| {
                summary.requests += 1;
                switch (request) {
                    .get_todo => |id| {
                        _ = try runtime.run(getEndpoint(id));
                        summary.todos += 1;
                    },
                    .health => {
                        if (try runtime.run(health_endpoint)) summary.health_checks += 1;
                    },
                    .application_map => {
                        const json = try runtime.inspectJson(ctx.allocator(), .{ .max_recent_events = 32 });
                        defer ctx.allocator().free(json);
                        if (std.mem.indexOf(u8, json, TodoApi.service_key) == null or
                            std.mem.indexOf(u8, json, AppConfig.service_key) == null or
                            std.mem.indexOf(u8, json, "\"edges\"") == null or
                            std.mem.indexOf(u8, json, "\"recent_events\"") == null)
                        {
                            return error.InvalidApplicationMap;
                        }
                        summary.application_maps += 1;
                        summary.application_map_bytes += json.len;
                    },
                }
            }
            return summary;
        }
    }.run);
}

var config_acquisitions: usize = 0;
var config_finalizations: usize = 0;

fn acquireConfig(_: *kernel.ContextView(.{})) error{}!AppConfig.API {
    config_acquisitions += 1;
    return .{ .first_id = 10 };
}

fn releaseConfig(_: *AppConfig.API) void {
    config_finalizations += 1;
}

fn makeRepository(ctx: *kernel.ContextView(.{AppConfig})) Repository.API {
    return .{ .first_id = ctx.service(AppConfig).first_id };
}

fn makeApi(ctx: *kernel.ContextView(.{Repository})) TodoApi.API {
    return .{ .repository = ctx.service(Repository) };
}

fn makeHealth(ctx: *kernel.ContextView(.{AppConfig})) Health.API {
    return .{ .ready = ctx.service(AppConfig).first_id > 0 };
}

pub fn mainLayer() @TypeOf(kernel.Layer.mergeAll(.{
    kernel.Layer.sync(TodoApi, .{Repository}, makeApi).provide(
        kernel.Layer.sync(Repository, .{AppConfig}, makeRepository).provide(
            kernel.Layer.scoped(AppConfig, error{}, .{}, acquireConfig, releaseConfig),
        ),
    ),
    kernel.Layer.sync(Health, .{AppConfig}, makeHealth).provide(
        kernel.Layer.scoped(AppConfig, error{}, .{}, acquireConfig, releaseConfig),
    ),
})) {
    const config_live = kernel.Layer.scoped(AppConfig, error{}, .{}, acquireConfig, releaseConfig);
    const repository_live = kernel.Layer.sync(Repository, .{AppConfig}, makeRepository);
    const api_live = kernel.Layer.sync(TodoApi, .{Repository}, makeApi);
    const health_live = kernel.Layer.sync(Health, .{AppConfig}, makeHealth);

    const repository_ready = repository_live.provide(config_live);
    return api_live.provide(repository_ready).merge(health_live.provide(config_live));
}

const RecordingSupervisor = struct {
    started: usize = 0,
    ended: usize = 0,

    pub fn onStart(self: *RecordingSupervisor, _: u64, _: []const u8) void {
        self.started += 1;
    }

    pub fn onEnd(self: *RecordingSupervisor, _: u64, _: []const u8) void {
        self.ended += 1;
    }
};

fn containsEvent(snapshot: fx.CausalSnapshot, kind: fx.CausalEventKind) bool {
    for (snapshot.events) |event| {
        if (event.kind == kind) return true;
    }
    return false;
}

test "canonical reference server composes one graph and runs every endpoint through one managed runtime" {
    config_acquisitions = 0;
    config_finalizations = 0;
    var supervisor = RecordingSupervisor{};
    var causal_store = fx.CausalStore.init(std.testing.allocator);
    defer causal_store.deinit();

    const root = mainLayer();
    try std.testing.expect(kernel.contains(@TypeOf(root).OutputServices, TodoApi));
    try std.testing.expect(kernel.contains(@TypeOf(root).OutputServices, Health));
    try std.testing.expect(!kernel.contains(@TypeOf(root).OutputServices, Repository));
    try std.testing.expect(!kernel.contains(@TypeOf(root).OutputServices, AppConfig));
    try std.testing.expectEqual(@as(usize, 0), @TypeOf(root).InputServices.len);

    var runtime = try kernel.ManagedRuntime(@TypeOf(root)).make(
        std.testing.allocator,
        root,
        .{
            .causal_store = &causal_store,
            .observability = .{
                .supervisor = kernel.FiberSupervisor.from(RecordingSupervisor, &supervisor),
            },
        },
    );
    try std.testing.expectEqual(@as(usize, 1), config_acquisitions);

    const requests = [_]Request{
        .{ .get_todo = 10 },
        .health,
        .{ .get_todo = 11 },
        .application_map,
    };
    const summary = try runtime.run(serve(&requests));
    try std.testing.expectEqual(@as(usize, 4), summary.requests);
    try std.testing.expectEqual(@as(usize, 2), summary.todos);
    try std.testing.expectEqual(@as(usize, 1), summary.health_checks);
    try std.testing.expectEqual(@as(usize, 1), summary.application_maps);
    try std.testing.expect(summary.application_map_bytes > 0);
    try std.testing.expectEqual(@as(usize, 1), config_acquisitions);
    try std.testing.expectEqual(supervisor.started, supervisor.ended);
    try std.testing.expect(supervisor.started >= 4);

    var snapshot = try causal_store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(containsEvent(snapshot, .service_required));
    try std.testing.expect(containsEvent(snapshot, .fiber_forked));
    try std.testing.expect(containsEvent(snapshot, .fiber_joined));

    runtime.deinit();
    try std.testing.expectEqual(@as(usize, 1), config_finalizations);
}
