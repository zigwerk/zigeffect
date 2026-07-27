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
};
pub const ApplicationInputs = kernel.Service("zgraphy/ApplicationInputs", ApplicationInputsApi);
pub const ApplicationServices = .{ApplicationInputs};

const common_options = [_]zstd.Cli.OptionSpec{
    .{ .name = "apply", .kind = .boolean },
    .{ .name = "configuration" },
    .{ .name = "correctness" },
    .{ .name = "budget", .kind = .integer },
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

/// Optional repository-root positional shared by the location-taking commands.
/// The resolved `--root` option still wins when both forms are supplied.
const root_positional = [_]zstd.Cli.PositionalSpec{
    .{ .name = "root", .kind = .optional },
};

const fixture_positionals = [_]zstd.Cli.PositionalSpec{
    .{ .name = "fixture-id", .kind = .required },
    .{ .name = "fixture-root", .kind = .optional },
};

const benchmark_commands = [_]zstd.Cli.CommandSpec{
    .{ .name = "corpus", .options = &common_options },
    .{ .name = "lexical", .options = &common_options, .positionals = &fixture_positionals },
    .{ .name = "zgraphy", .options = &common_options, .positionals = &fixture_positionals },
    .{ .name = "graphify", .options = &common_options, .positionals = &.{
        .{ .name = "fixture-id", .kind = .required },
        .{ .name = "graph.json", .kind = .required },
    } },
    .{ .name = "matrix", .options = &common_options, .positionals = &.{
        .{ .name = "graphify-run-root", .kind = .optional },
    } },
    .{ .name = "workload", .options = &common_options, .positionals = &.{
        .{ .name = "fixture-id", .kind = .required },
        .{ .name = "workload", .kind = .required },
        .{ .name = "fixture-root", .kind = .optional },
    } },
    .{ .name = "resources", .options = &common_options, .positionals = &.{
        .{ .name = "samples.json", .kind = .required },
    } },
    .{ .name = "freshness", .options = &common_options, .positionals = &.{
        .{ .name = "transitions.json", .kind = .required },
    } },
    .{ .name = "churn", .options = &common_options, .positionals = &.{
        .{ .name = "observations.json", .kind = .required },
    } },
    .{ .name = "performance", .options = &common_options, .positionals = &.{
        .{ .name = "samples.json", .kind = .required },
    } },
};

const commands = [_]zstd.Cli.CommandSpec{
    .{ .name = "init", .options = &common_options, .positionals = &root_positional },
    .{ .name = "build", .options = &common_options, .positionals = &root_positional },
    .{ .name = "ingest", .options = &common_options, .positionals = &root_positional },
    .{ .name = "status", .options = &common_options },
    .{ .name = "doctor", .options = &common_options, .positionals = &root_positional },
    .{ .name = "watch", .options = &common_options, .positionals = &root_positional },
    .{ .name = "gc", .options = &common_options, .positionals = &root_positional },
    .{ .name = "pin", .options = &common_options, .positionals = &.{
        .{ .name = "generation", .kind = .required },
    } },
    .{ .name = "unpin", .options = &common_options, .positionals = &.{
        .{ .name = "generation", .kind = .required },
    } },
    .{ .name = "query", .options = &common_options, .positionals = &.{
        .{ .name = "text", .kind = .required },
    } },
    .{ .name = "explain", .options = &common_options, .positionals = &.{
        .{ .name = "node-id-or-label", .kind = .required },
    } },
    .{ .name = "path", .options = &common_options, .positionals = &.{
        .{ .name = "from", .kind = .required },
        .{ .name = "to", .kind = .required },
    } },
    .{ .name = "parity", .options = &common_options },
    .{ .name = "schema", .options = &common_options, .positionals = &.{
        .{ .name = "relation", .kind = .optional },
    } },
    .{ .name = "contracts", .options = &common_options, .positionals = &.{
        .{ .name = "section", .kind = .optional },
    } },
    .{ .name = "security", .options = &common_options, .positionals = &.{
        .{ .name = "threat-id", .kind = .optional },
    } },
    .{ .name = "evaluation", .options = &common_options, .positionals = &.{
        .{ .name = "kind", .kind = .optional },
    } },
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

/// The concrete application-input layer type the resource factory returns. The
/// layer type depends only on the service/api, not the runtime inputs, so it is
/// stable to name from a comptime placeholder value.
pub const InputsLayer = @TypeOf(kernel.Layer.succeed(ApplicationInputs, ApplicationInputsApi{ .io = undefined, .root = undefined }));

/// Select the repository root for an executable command from immutable parsed
/// authority alone (see the technical plan's "Root selection"):
///
/// 1. the first parsed `--root` occurrence, if present;
/// 2. otherwise the optional positional root for exactly `init`, `build`,
///    `ingest`, `doctor`, `watch`, or `gc`;
/// 3. otherwise `.`.
///
/// Explicit `--root` always wins over a positional repository-root argument,
/// regardless of the option placement the grammar allows, because it is checked
/// first. Raw `argv` is never consulted; the parser already resolved the leaf
/// path, first-occurrence option values, and positionals.
pub fn selectRoot(parsed: zstd.Cli.ParsedCommand) []const u8 {
    if (parsed.optionValue("root")) |explicit_root| return explicit_root;
    if (parsed.path.len >= 2 and commandTakesPositionalRoot(parsed.path[1])) {
        if (parsed.positional(0)) |positional_root| return positional_root;
    }
    return ".";
}

/// The six location commands whose optional first positional is a repository
/// root. Every other command's positionals carry different meaning (generation,
/// query text, fixture ids, ...) and must never be treated as a root.
fn commandTakesPositionalRoot(command: []const u8) bool {
    return std.mem.eql(u8, command, "init") or
        std.mem.eql(u8, command, "build") or
        std.mem.eql(u8, command, "ingest") or
        std.mem.eql(u8, command, "doctor") or
        std.mem.eql(u8, command, "watch") or
        std.mem.eql(u8, command, "gc");
}

/// The zgraphy post-parse resource factory. `acquire` receives only the
/// immutable resolved `ParsedCommand`; it derives the selected root, opens it as
/// an owned directory, and builds the application-input layer over that same
/// handle. The framework closes the directory exactly once after checked
/// shutdown. It is never invoked for built-ins, parse/arity failures, missing
/// handlers, or completion failures.
pub const CommandResourceFactory = struct {
    const Self = @This();
    pub const LayerType = InputsLayer;

    pub fn acquire(
        self: Self,
        allocator: std.mem.Allocator,
        io: std.Io,
        parsed: zstd.Cli.ParsedCommand,
    ) anyerror!zstd.Application.CommandResources(LayerType) {
        _ = self;
        _ = allocator;
        // The only fallible step is opening the selected root. A failure here
        // acquires nothing, so there is no partial state to clean up; the
        // missing/inaccessible root surfaces as an infrastructure failure. The
        // opened handle is supplied to both the managed runtime root and the
        // application layer, so durable graph output lands relative to it.
        const root_path = selectRoot(parsed);
        const root = try std.Io.Dir.cwd().openDir(io, root_path, .{ .iterate = true, .follow_symlinks = false });
        return .{
            .root = root,
            .layer = rootLayer(.{ .io = io, .root = root }),
            .ownership = .close_directory,
        };
    }
};

/// Construct the zgraphy selected-root resource factory.
pub fn commandResources() CommandResourceFactory {
    return .{};
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
