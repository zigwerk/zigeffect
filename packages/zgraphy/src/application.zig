const std = @import("std");
const zstd = @import("zigeffect_std");
const model = @import("model.zig");
const search = @import("search.zig");

const kernel = zstd.fx.kernel;

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
