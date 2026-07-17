const std = @import("std");
const zstd = @import("zigeffect_std");
const model = @import("model.zig");
const search = @import("search.zig");

const kernel = zstd.fx.kernel;

/// Operational causal evidence for zgraphy's own CLI runtime. This must never
/// share the target application's `.zigeffect/graph` namespace: the indexer
/// imports that namespace as repository evidence, so sharing it would make an
/// unchanged build observe itself and churn the active generation.
pub const causal_graph_path = ".zgraphy/runtime/causal";

pub const ApplicationInputsApi = struct {
    pub const operations: []const []const u8 = &.{"ZgraphyCommand.dispatch"};
    io: std.Io,
    root: std.Io.Dir,
    args: []const []const u8,
};
pub const ApplicationInputs = kernel.Service("zgraphy/ApplicationInputs", ApplicationInputsApi);

pub fn rootLayer(inputs: ApplicationInputsApi) @TypeOf(kernel.Layer.mergeAll(.{
    kernel.Layer.succeed(ApplicationInputs, inputs),
    zstd.Application.Lifecycle.managerLayer(),
    zstd.Application.Lifecycle.signalLayer(),
})) {
    return kernel.Layer.mergeAll(.{
        kernel.Layer.succeed(ApplicationInputs, inputs),
        zstd.Application.Lifecycle.managerLayer(),
        zstd.Application.Lifecycle.signalLayer(),
    });
}

pub const RepositoryGraphApi = struct {
    pub const operations: []const []const u8 = &.{ "RepositoryGraph.query", "RepositoryGraph.path" };
    graph: *model.RepositoryGraph,
};

pub const RepositoryGraph = kernel.Service("zgraphy/RepositoryGraph", RepositoryGraphApi);

pub fn graphLayer(graph: *model.RepositoryGraph) @TypeOf(kernel.Layer.succeed(RepositoryGraph, RepositoryGraphApi{ .graph = graph })) {
    return kernel.Layer.succeed(RepositoryGraph, RepositoryGraphApi{ .graph = graph });
}

pub const QueryRequest = struct {
    text: []const u8,
    options: search.Options = .{},
};

const QueryBase = kernel.Effect(search.Results, anyerror, .{RepositoryGraph});
pub const QueryEffect = QueryBase.Stateful(QueryRequest);
pub const QueryProgram = kernel.NamedEffect(QueryEffect);

pub fn queryEffect(request: QueryRequest) QueryProgram {
    return QueryEffect.init(request, struct {
        fn run(value: QueryRequest, ctx: *QueryEffect.Context) anyerror!search.Results {
            const graph = ctx.service(RepositoryGraph).graph;
            return search.queryAlloc(ctx.allocator(), graph, value.text, value.options);
        }
    }.run).named("zgraphy.query");
}

/// Completes the process boundary while the managed runtime is still live.
/// Checked shutdown has precedence because a command result cannot be trusted
/// when its causal evidence failed to flush durably.
pub fn checkedCleanup(runtime: anytype, allocator: std.mem.Allocator) ?anyerror {
    var infrastructure_failure: ?anyerror = null;
    runtime.run(zstd.Application.Lifecycle.drain()) catch |failure| retainFirstFailure(&infrastructure_failure, failure);
    runtime.run(zstd.Application.Lifecycle.stop()) catch |failure| retainFirstFailure(&infrastructure_failure, failure);

    if (runtime.inspect(allocator, .{ .max_recent_events = 64 })) |application_value| {
        var application = application_value;
        defer application.deinit();
        if (application.services.len == 0) retainFirstFailure(&infrastructure_failure, error.InvalidApplicationSnapshot);
    } else |failure| {
        retainFirstFailure(&infrastructure_failure, failure);
    }
    if (runtime.causalHealth().status != .healthy) retainFirstFailure(&infrastructure_failure, error.CausalRuntimeUnhealthy);

    runtime.shutdown() catch |failure| return failure;
    return infrastructure_failure;
}

fn retainFirstFailure(current: *?anyerror, failure: anyerror) void {
    if (current.* == null) current.* = failure;
}
