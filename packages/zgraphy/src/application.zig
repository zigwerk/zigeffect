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
pub const ApplicationServices = .{ApplicationInputs};

const common_options = [_]zstd.Cli.OptionSpec{
    .{ .name = "apply", .kind = .boolean },
    .{ .name = "configuration" },
    .{ .name = "correctness" },
    .{ .name = "debounce-ms", .kind = .integer },
    .{ .name = "graphify-environment" },
    .{ .name = "graphify-python" },
    .{ .name = "json", .kind = .boolean },
    .{ .name = "limit", .kind = .integer },
    .{ .name = "machine" },
    .{ .name = "max-cycles", .kind = .integer },
    .{ .name = "max-drain-passes", .kind = .integer },
    .{ .name = "max-hops", .kind = .integer },
    .{ .name = "poll-ms", .kind = .integer },
    .{ .name = "quality" },
    .{ .name = "repetitions", .kind = .integer },
    .{ .name = "resources" },
    .{ .name = "retry-ms", .kind = .integer },
    .{ .name = "root" },
    .{ .name = "source-revision" },
    .{ .name = "warmups", .kind = .integer },
};

const benchmark_commands = [_]zstd.Cli.CommandSpec{
    .{ .name = "corpus", .options = &common_options },
    .{ .name = "lexical", .options = &common_options },
    .{ .name = "zgraphy", .options = &common_options },
    .{ .name = "graphify", .options = &common_options },
    .{ .name = "matrix", .options = &common_options },
    .{ .name = "workload", .options = &common_options },
    .{ .name = "resources", .options = &common_options },
    .{ .name = "freshness", .options = &common_options },
    .{ .name = "churn", .options = &common_options },
    .{ .name = "performance", .options = &common_options },
};

const commands = [_]zstd.Cli.CommandSpec{
    .{ .name = "init", .options = &common_options },
    .{ .name = "build", .options = &common_options },
    .{ .name = "ingest", .options = &common_options },
    .{ .name = "status", .options = &common_options },
    .{ .name = "doctor", .options = &common_options },
    .{ .name = "watch", .options = &common_options },
    .{ .name = "gc", .options = &common_options },
    .{ .name = "pin", .options = &common_options },
    .{ .name = "unpin", .options = &common_options },
    .{ .name = "query", .options = &common_options },
    .{ .name = "explain", .options = &common_options },
    .{ .name = "path", .options = &common_options },
    .{ .name = "parity", .options = &common_options },
    .{ .name = "schema", .options = &common_options },
    .{ .name = "contracts", .options = &common_options },
    .{ .name = "security", .options = &common_options },
    .{ .name = "evaluation", .options = &common_options },
    .{ .name = "benchmark", .options = &common_options, .subcommands = &benchmark_commands, .default_subcommand = "corpus" },
};

pub const command_spec = zstd.Cli.CommandSpec{
    .name = "zgraphy",
    .description = "local Zig repository knowledge graph",
    .subcommands = &commands,
};

pub const command_help =
    \\zgraphy - local Zig repository knowledge graph
    \\
    \\Usage:
    \\  zgraphy init [root] [--json]
    \\  zgraphy build [root] [--json]
    \\  zgraphy ingest [root] [--json]
    \\  zgraphy watch [root] [--poll-ms N] [--debounce-ms N] [--retry-ms N] [--max-cycles N] [--max-drain-passes N] [--json]
    \\  zgraphy gc [root] [--apply] [--json]  # dry-run unless --apply
    \\  zgraphy pin <generation> [--root repository] [--json]
    \\  zgraphy unpin <generation> [--root repository] [--json]
    \\  zgraphy query <text> [--limit N] [--json]
    \\  zgraphy explain <node-id-or-label> [--json]
    \\  zgraphy path <from> <to> [--max-hops N] [--json]
    \\  zgraphy status [--json]
    \\  zgraphy doctor [root] [--json]
    \\  zgraphy parity [--json]
    \\  zgraphy schema [relation] [--json]
    \\  zgraphy contracts [provider|conformance|config|health|diagnostic|migration] [--json]
    \\  zgraphy security [ZG-THR-NNN] [--json]
    \\  zgraphy evaluation [extraction|retrieval|agent_task|performance|resource] [--json]
    \\  zgraphy benchmark corpus [--json]
    \\  zgraphy benchmark lexical <fixture-id> [fixture-root] [--json]
    \\  zgraphy benchmark zgraphy <fixture-id> [fixture-root] [--json]
    \\  zgraphy benchmark graphify <fixture-id> <graph.json> [--json]
    \\  zgraphy benchmark matrix [graphify-run-root] --source-revision <sha256> --graphify-python <version> --graphify-environment <sha256> [--json]
    \\  zgraphy benchmark workload <fixture-id> <cold-build|warm-unchanged-build|one-file-modify|rename|delete> [fixture-root] [--json]
    \\  zgraphy benchmark resources <samples.json> --source-revision <sha256> --graphify-python <version> --graphify-environment <sha256> --machine <sha256> --configuration <sha256> [--warmups N] [--repetitions N] [--json]
    \\  zgraphy benchmark freshness <transitions.json> [--json]
    \\  zgraphy benchmark churn <observations.json> [--json]
    \\  zgraphy benchmark performance <samples.json> --source-revision <sha256> --machine <sha256> --configuration <sha256> --correctness <sha256> --quality <sha256> --resources <sha256> --graphify-python <version> --graphify-environment <sha256> [--warmups N] [--repetitions N] [--json]
    \\  Add --root <repository-path> to any repository command.
    \\
;

const command_paths = [_][]const []const u8{
    &.{ "zgraphy", "init" },
    &.{ "zgraphy", "build" },
    &.{ "zgraphy", "ingest" },
    &.{ "zgraphy", "status" },
    &.{ "zgraphy", "doctor" },
    &.{ "zgraphy", "watch" },
    &.{ "zgraphy", "gc" },
    &.{ "zgraphy", "pin" },
    &.{ "zgraphy", "unpin" },
    &.{ "zgraphy", "query" },
    &.{ "zgraphy", "explain" },
    &.{ "zgraphy", "path" },
    &.{ "zgraphy", "parity" },
    &.{ "zgraphy", "schema" },
    &.{ "zgraphy", "contracts" },
    &.{ "zgraphy", "security" },
    &.{ "zgraphy", "evaluation" },
    &.{ "zgraphy", "benchmark", "corpus" },
    &.{ "zgraphy", "benchmark", "lexical" },
    &.{ "zgraphy", "benchmark", "zgraphy" },
    &.{ "zgraphy", "benchmark", "graphify" },
    &.{ "zgraphy", "benchmark", "matrix" },
    &.{ "zgraphy", "benchmark", "workload" },
    &.{ "zgraphy", "benchmark", "resources" },
    &.{ "zgraphy", "benchmark", "freshness" },
    &.{ "zgraphy", "benchmark", "churn" },
    &.{ "zgraphy", "benchmark", "performance" },
};

pub const CommandHandler = *const fn (*kernel.ContextView(ApplicationServices), zstd.Cli.ParsedCommand) anyerror!void;

pub const CommandApplication = struct {
    handlers: [command_paths.len]zstd.Cli.ServiceHandler(ApplicationServices, anyerror),

    pub fn init(run: CommandHandler) CommandApplication {
        var handlers = [_]zstd.Cli.ServiceHandler(ApplicationServices, anyerror){.{
            .path = command_paths[0],
            .run = run,
        }} ** command_paths.len;
        for (&handlers, command_paths) |*handler, path| {
            handler.* = .{ .path = path, .run = run };
        }
        return .{ .handlers = handlers };
    }

    pub fn application(self: *const CommandApplication) zstd.Cli.ServiceApplication(ApplicationServices, anyerror) {
        return .{
            .spec = command_spec,
            .version = "0.1.0",
            .help = command_help,
            .handlers = &self.handlers,
        };
    }
};

pub fn rootLayer(inputs: ApplicationInputsApi) @TypeOf(kernel.Layer.succeed(ApplicationInputs, inputs)) {
    return kernel.Layer.succeed(ApplicationInputs, inputs);
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
