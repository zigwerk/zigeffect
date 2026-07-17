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

pub fn queryEffect(request: QueryRequest) QueryEffect {
    return QueryEffect.init(request, struct {
        fn run(value: QueryRequest, ctx: *QueryEffect.Context) anyerror!search.Results {
            const graph = ctx.service(RepositoryGraph).graph;
            const results = search.queryAlloc(ctx.allocator(), graph, value.text, value.options) catch |failure| {
                _ = ctx.recordCausal(.{
                    .kind = .activity_completed,
                    .service_key = RepositoryGraph.service_key,
                    .label = "zgraphy.query",
                    .status = "failure",
                    .redacted_detail = @errorName(failure),
                });
                return failure;
            };
            _ = ctx.recordCausal(.{
                .kind = .activity_completed,
                .service_key = RepositoryGraph.service_key,
                .label = "zgraphy.query",
                .status = "success",
                .redacted_detail = "bounded-hybrid-retrieval",
            });
            return results;
        }
    }.run);
}
