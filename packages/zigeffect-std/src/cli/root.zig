const std = @import("std");
const Config = @import("../config/root.zig");
const Console = @import("../console/root.zig");
const Env = @import("../env/root.zig");
const Schema = @import("../schema/root.zig");
const Secrets = @import("../secrets/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const OptionKind = enum {
    string,
    boolean,
    integer,
};

pub const OptionSpec = struct {
    name: []const u8,
    short: ?u8 = null,
    kind: OptionKind = .string,
    required: bool = false,
    help: []const u8 = "",
    default_value: ?[]const u8 = null,
    env: ?[]const u8 = null,
    config_key: ?[]const u8 = null,
};

pub const OptionMeta = struct {
    long: []const u8,
    short: ?u8 = null,
    help: []const u8 = "",
    required: bool = false,
    default_value: ?[]const u8 = null,
    env: ?[]const u8 = null,
    config_key: ?[]const u8 = null,
    secret: bool = false,
};

pub const CommandSpec = struct {
    name: []const u8,
    description: []const u8 = "",
    options: []const OptionSpec = &.{},
    subcommands: []const CommandSpec = &.{},
    default_subcommand: ?[]const u8 = null,
};

pub const TypedCommandMeta = struct {
    name: []const u8,
    description: []const u8 = "",
    version: []const u8 = "",
};

pub const OptionSourceKind = enum { cli, env, config, default, missing };

pub const OptionSourceFact = struct {
    name: []const u8,
    source: OptionSourceKind,
    redacted_value: []const u8,
};

pub const BuiltinRequest = enum {
    help,
    version,
    completions,
};

pub const CliError = error{
    UnknownOption,
    MissingOptionValue,
    MissingRequiredOption,
    UnknownSubcommand,
    InvalidInteger,
};

pub const ExitCode = enum(i32) {
    success = 0,
    usage = 64,
    config = 78,
    io = 74,
    interrupted = 130,
    defect = 70,
};

pub const RunnerApi = struct {
    pub const operations: []const []const u8 = &.{ "Cli.run", "Cli.runTyped" };
};
pub const Runner = fx.kernel.Service("zigeffect/std/CliRunner", RunnerApi);

pub fn runnerLayer() @TypeOf(fx.kernel.Layer.succeed(Runner, RunnerApi{})) {
    return fx.kernel.Layer.succeed(Runner, .{});
}

pub const ParsedOption = struct {
    name: []const u8,
    value: ?[]const u8,
};

pub const ParsedCommand = struct {
    command: []const u8,
    path: []const []const u8,
    options: []const ParsedOption,
    positionals: []const []const u8,

    pub fn deinit(self: *ParsedCommand, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.options);
        allocator.free(self.positionals);
    }

    pub fn optionValue(self: ParsedCommand, name: []const u8) ?[]const u8 {
        for (self.options) |parsed_option| {
            if (std.mem.eql(u8, parsed_option.name, name)) return parsed_option.value;
        }
        return null;
    }
};

pub const CliRunFact = struct {
    kind: []const u8,
    detail: []const u8 = "",
};

pub const CliRunReceipt = struct {
    schema: []const u8 = "zigeffect.std.cli-run.v1",
    command: []const u8,
    status: []const u8,
    facts: []const CliRunFact,
};

pub const RunSummary = struct {
    command: []const u8,
    status: []const u8,
    exit_code: ExitCode,
    receipt_json: []const u8,

    pub fn deinit(self: *RunSummary, allocator: std.mem.Allocator) void {
        allocator.free(self.command);
        allocator.free(self.receipt_json);
    }
};

pub const command_identity_max_bytes: usize = 128;
pub const command_identity_max_segments: usize = 8;
pub const command_identity_max_segment_bytes: usize = 48;

pub const CommandIdentityError = error{
    EmptyCommandIdentity,
    EmptyCommandSegment,
    TooManyCommandSegments,
    CommandSegmentTooLong,
    CommandIdentityTooLong,
};

/// A bounded command label derived only from names in a successfully matched
/// command declaration. Option values, positionals, environment variables and
/// executable names never enter this buffer.
const CommandIdentity = struct {
    bytes: [command_identity_max_bytes]u8 = undefined,
    len: u8 = 0,
    segment_count: u8 = 0,

    pub fn slice(self: *const CommandIdentity) []const u8 {
        return self.bytes[0..@min(@as(usize, self.len), self.bytes.len)];
    }

    pub fn segmentCount(self: CommandIdentity) usize {
        return @min(@as(usize, self.segment_count), command_identity_max_segments);
    }
};

fn commandIdentityFromMatchedPath(path: []const []const u8) CommandIdentityError!CommandIdentity {
    if (path.len == 0) return error.EmptyCommandIdentity;
    if (path.len > command_identity_max_segments) return error.TooManyCommandSegments;

    var identity = CommandIdentity{};
    for (path, 0..) |segment, segment_index| {
        if (segment.len == 0) return error.EmptyCommandSegment;
        if (segment.len > command_identity_max_segment_bytes) return error.CommandSegmentTooLong;
        const separator_bytes: usize = if (segment_index == 0) 0 else 1;
        const next_len = @as(usize, identity.len) + separator_bytes + segment.len;
        if (next_len > command_identity_max_bytes) return error.CommandIdentityTooLong;
        if (separator_bytes != 0) {
            identity.bytes[identity.len] = '.';
            identity.len += 1;
        }
        @memcpy(identity.bytes[identity.len..][0..segment.len], segment);
        identity.len = @intCast(next_len);
    }
    identity.segment_count = @intCast(path.len);
    return identity;
}

const FrameworkPreflightTag = enum { parsed, typed };

pub fn isFrameworkServicePreflight(comptime Candidate: type) bool {
    if (!@hasDecl(Candidate, "FrameworkPreflightKind") or
        !@hasDecl(Candidate, "RequiredServices") or
        !@hasDecl(Candidate, "FailureType")) return false;
    if (@TypeOf(Candidate.FrameworkPreflightKind) != FrameworkPreflightTag) return false;
    return switch (Candidate.FrameworkPreflightKind) {
        .parsed => Candidate == ServicePreflight(Candidate.RequiredServices, Candidate.FailureType),
        .typed => blk: {
            if (!@hasDecl(Candidate, "ArgsType") or !@hasDecl(Candidate, "CommandType")) break :blk false;
            break :blk Candidate == ServiceTypedPreflight(
                Candidate.RequiredServices,
                Candidate.ArgsType,
                Candidate.FailureType,
                Candidate.CommandType,
            );
        },
    };
}

pub const ShortCircuitKind = enum {
    help,
    version,
    completions,
    usage,
};

pub const ShortCircuitStream = enum {
    stdout,
    stderr,
};

pub const ShortCircuit = struct {
    kind: ShortCircuitKind,
    exit_code: ExitCode,
    stream: ShortCircuitStream,
    output: []const u8,

    pub fn deinit(self: *ShortCircuit, allocator: std.mem.Allocator) void {
        allocator.free(self.output);
        self.* = undefined;
    }

    pub fn write(self: ShortCircuit, io: std.Io) !void {
        switch (self.stream) {
            .stdout => try std.Io.File.stdout().writeStreamingAll(io, self.output),
            .stderr => try std.Io.File.stderr().writeStreamingAll(io, self.output),
        }
    }
};

pub fn ServiceHandler(comptime Services: anytype, comptime Failure: type) type {
    return struct {
        path: []const []const u8,
        run: *const fn (*fx.kernel.ContextView(Services), ParsedCommand) Failure!void,
    };
}

pub fn ServiceApplication(comptime Services: anytype, comptime Failure: type) type {
    return struct {
        const Self = @This();

        spec: CommandSpec,
        version: []const u8 = "",
        handlers: []const ServiceHandler(Services, Failure),

        pub fn findHandler(self: Self, parsed: ParsedCommand) ?ServiceHandler(Services, Failure) {
            for (self.handlers) |handler| {
                if (commandPathsEqual(handler.path, parsed.path)) return handler;
            }
            return null;
        }
    };
}

fn ServiceCommandInput(comptime Services: anytype, comptime Failure: type) type {
    return struct {
        handler: ServiceHandler(Services, Failure),
        parsed: ParsedCommand,
    };
}

pub fn ServiceCommandEffect(comptime Services: anytype, comptime Failure: type) type {
    const Program = fx.kernel.Effect(void, Failure, Services);
    return Program.Stateful(ServiceCommandInput(Services, Failure));
}

fn serviceCommandEffect(
    comptime Services: anytype,
    comptime Failure: type,
    handler: ServiceHandler(Services, Failure),
    parsed: ParsedCommand,
) ServiceCommandEffect(Services, Failure) {
    const Program = fx.kernel.Effect(void, Failure, Services);
    const Input = ServiceCommandInput(Services, Failure);
    return Program.fromState(Input, .{ .handler = handler, .parsed = parsed }, struct {
        fn execute(input: Input, ctx: *Program.Context) Failure!void {
            return input.handler.run(ctx, input.parsed);
        }
    }.execute);
}

pub fn ServicePreflight(comptime Services: anytype, comptime Failure: type) type {
    return struct {
        const Self = @This();
        const App = ServiceApplication(Services, Failure);
        pub const FrameworkPreflightKind = FrameworkPreflightTag.parsed;
        pub const RequiredServices = Services;
        pub const FailureType = Failure;
        pub const CommandEffect = ServiceCommandEffect(Services, Failure);
        const SealedCommand = struct {
            identity: CommandIdentity,
            effect: CommandEffect,
        };
        const Seal = opaque {};

        allocator: std.mem.Allocator,
        application: App,
        parsed: ?ParsedCommand = null,
        short_circuit: ?ShortCircuit = null,
        sealed_command: ?*const Seal = null,

        pub fn deinit(self: *Self) void {
            if (self.sealed_command) |sealed| {
                const command: *SealedCommand = @ptrCast(@alignCast(@constCast(sealed)));
                self.allocator.destroy(command);
            }
            if (self.parsed) |*parsed| parsed.deinit(self.allocator);
            if (self.short_circuit) |*short_circuit| short_circuit.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn shouldRun(self: *const Self) bool {
            return self.sealed_command != null and self.short_circuit == null;
        }

        pub fn prepare(self: *const Self) error{InvalidCommandPreflight}!SealedCommand {
            if (!self.shouldRun()) return error.InvalidCommandPreflight;
            const command: *const SealedCommand = @ptrCast(@alignCast(self.sealed_command.?));
            return command.*;
        }

        pub fn commandEffect(self: *const Self) CommandEffect {
            return (self.prepare() catch unreachable).effect;
        }
    };
}

pub fn ServiceTypedHandler(comptime Services: anytype, comptime Args: type, comptime Failure: type) type {
    return *const fn (*fx.kernel.ContextView(Services), Args) Failure!void;
}

pub fn ServiceTypedApplication(
    comptime Services: anytype,
    comptime Args: type,
    comptime Failure: type,
    comptime Command: type,
) type {
    return struct {
        command: Command,
        handler: ServiceTypedHandler(Services, Args, Failure),
    };
}

fn ServiceTypedCommandInput(comptime Services: anytype, comptime Args: type, comptime Failure: type) type {
    return struct {
        handler: ServiceTypedHandler(Services, Args, Failure),
        args: Args,
    };
}

pub fn ServiceTypedCommandEffect(comptime Services: anytype, comptime Args: type, comptime Failure: type) type {
    const Program = fx.kernel.Effect(void, Failure, Services);
    return Program.Stateful(ServiceTypedCommandInput(Services, Args, Failure));
}

fn serviceTypedCommandEffect(
    comptime Services: anytype,
    comptime Args: type,
    comptime Failure: type,
    handler: ServiceTypedHandler(Services, Args, Failure),
    args: Args,
) ServiceTypedCommandEffect(Services, Args, Failure) {
    const Program = fx.kernel.Effect(void, Failure, Services);
    const Input = ServiceTypedCommandInput(Services, Args, Failure);
    return Program.fromState(Input, .{ .handler = handler, .args = args }, struct {
        fn execute(input: Input, ctx: *Program.Context) Failure!void {
            return input.handler(ctx, input.args);
        }
    }.execute);
}

pub fn ServiceTypedPreflight(
    comptime Services: anytype,
    comptime Args: type,
    comptime Failure: type,
    comptime Command: type,
) type {
    return struct {
        const Self = @This();
        const App = ServiceTypedApplication(Services, Args, Failure, Command);
        pub const FrameworkPreflightKind = FrameworkPreflightTag.typed;
        pub const RequiredServices = Services;
        pub const ArgsType = Args;
        pub const FailureType = Failure;
        pub const CommandType = Command;
        pub const CommandEffect = ServiceTypedCommandEffect(Services, Args, Failure);
        const SealedCommand = struct {
            identity: CommandIdentity,
            effect: CommandEffect,
        };
        const Seal = opaque {};

        allocator: std.mem.Allocator,
        application: App,
        decoded: ?TypedDecodeResult(Args) = null,
        short_circuit: ?ShortCircuit = null,
        sealed_command: ?*const Seal = null,

        pub fn deinit(self: *Self) void {
            if (self.sealed_command) |sealed| {
                const command: *SealedCommand = @ptrCast(@alignCast(@constCast(sealed)));
                self.allocator.destroy(command);
            }
            if (self.decoded) |*decoded| decoded.deinit();
            if (self.short_circuit) |*short_circuit| short_circuit.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn shouldRun(self: *const Self) bool {
            return self.sealed_command != null and self.short_circuit == null;
        }

        pub fn prepare(self: *const Self) error{InvalidCommandPreflight}!SealedCommand {
            if (!self.shouldRun()) return error.InvalidCommandPreflight;
            const command: *const SealedCommand = @ptrCast(@alignCast(self.sealed_command.?));
            return command.*;
        }

        pub fn commandEffect(self: *const Self) CommandEffect {
            return (self.prepare() catch unreachable).effect;
        }
    };
}

pub const HandlerContext = struct {
    allocator: std.mem.Allocator,
    console: fx.kernel.Console,
};

pub fn Handler(comptime Failure: type) type {
    return struct {
        path: []const []const u8,
        run: *const fn (*HandlerContext, ParsedCommand) Failure!void,
    };
}

pub fn Application(comptime Failure: type) type {
    return struct {
        const Self = @This();

        spec: CommandSpec,
        handlers: []const Handler(Failure),

        pub fn findHandler(self: Self, parsed: ParsedCommand) ?Handler(Failure) {
            for (self.handlers) |handler| {
                if (commandPathsEqual(handler.path, parsed.path)) return handler;
            }
            return null;
        }
    };
}

pub fn TypedOptionSpec(comptime SchemaT: type, comptime field_name: []const u8, comptime meta: OptionMeta) type {
    return struct {
        pub const FieldName = field_name;
        pub const Meta = meta;
        pub const SchemaType = SchemaT;

        schema: SchemaT,
    };
}

pub fn option(comptime field_name: []const u8, schema: anytype, comptime meta: OptionMeta) TypedOptionSpec(@TypeOf(schema), field_name, meta) {
    return .{ .schema = schema };
}

pub fn flag(comptime field_name: []const u8, comptime meta: OptionMeta) TypedOptionSpec(Schema.BooleanSchema, field_name, meta) {
    return .{ .schema = Schema.boolean() };
}

pub fn TypedCommand(comptime Args: type, comptime meta: TypedCommandMeta, comptime Options: type) type {
    const legacy_options = typedLegacyOptions(Options);
    return struct {
        pub const ArgsType = Args;
        pub const OptionsType = Options;
        pub const Meta = meta;

        options: Options,

        pub fn toCommandSpec(self: @This()) CommandSpec {
            _ = self;
            return .{
                .name = meta.name,
                .description = meta.description,
                .options = legacy_options[0..],
            };
        }
    };
}

pub fn typedCommand(comptime Args: type, comptime meta: TypedCommandMeta, options_value: anytype) TypedCommand(Args, meta, @TypeOf(options_value)) {
    return .{ .options = options_value };
}

pub fn TypedDecodeResult(comptime Args: type) type {
    return struct {
        allocator: std.mem.Allocator,
        value: ?Args = null,
        issues: Schema.IssueList,
        sources: []OptionSourceFact = &.{},

        pub fn ok(self: @This()) bool {
            return self.value != null and self.issues.len() == 0;
        }

        pub fn deinit(self: *@This()) void {
            for (self.sources) |source| {
                self.allocator.free(source.name);
                self.allocator.free(source.redacted_value);
            }
            self.allocator.free(self.sources);
            self.issues.deinit();
            self.* = undefined;
        }
    };
}

pub fn TypedHandler(comptime Args: type, comptime Failure: type) type {
    return *const fn (*HandlerContext, Args) Failure!void;
}

pub fn TypedApplication(comptime Args: type, comptime Failure: type, comptime Command: type) type {
    return struct {
        command: Command,
        handler: TypedHandler(Args, Failure),
    };
}

fn TypedRunInput(comptime Args: type, comptime HandlerFailure: type, comptime Command: type) type {
    return struct { app: TypedApplication(Args, HandlerFailure, Command), args: []const []const u8 };
}

pub fn runTyped(
    comptime Args: type,
    comptime HandlerFailure: type,
    comptime Command: type,
    app: TypedApplication(Args, HandlerFailure, Command),
    args: []const []const u8,
) fx.kernel.Effect(RunSummary, anyerror, .{Runner}).Stateful(TypedRunInput(Args, HandlerFailure, Command)) {
    const Run = fx.kernel.Effect(RunSummary, anyerror, .{Runner});
    const Input = TypedRunInput(Args, HandlerFailure, Command);
    return Run.fromState(Input, .{ .app = app, .args = args }, struct {
        fn execute(input: Input, ctx: *Run.Context) anyerror!RunSummary {
            _ = ctx.service(Runner);
            const allocator = ctx.allocator();
            const console = ctx.console();
            _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.runTyped", "started", Command.Meta.name);

            if (detectBuiltin(input.app.command, input.args)) |builtin| {
                const payload = switch (builtin) {
                    .help => try formatTypedHelp(allocator, input.app.command),
                    .version => try formatTypedVersion(allocator, input.app.command),
                    .completions => try formatTypedCompletions(allocator, input.app.command),
                };
                defer allocator.free(payload);
                try console.writeOut(payload);
                _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.runTyped", "success", @tagName(builtin));
                return buildRunSummary(allocator, Command.Meta.name, "success", .success, &.{
                    .{ .kind = "cli_builtin_completed", .detail = @tagName(builtin) },
                    .{ .kind = "cli_command_completed", .detail = "success" },
                });
            }

            var parsed = parse(allocator, input.app.command.toCommandSpec(), input.args) catch |failure| {
                try writeCliError(console, "parse", failure);
                _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.runTyped", "failure", @errorName(failure));
                return buildRunSummary(allocator, Command.Meta.name, "failure", exitCodeForError(failure), &.{
                    .{ .kind = "cli_parse_failed", .detail = @errorName(failure) },
                    .{ .kind = "cli_command_completed", .detail = "failure" },
                });
            };
            defer parsed.deinit(allocator);

            var decoded = try decodeTypedCommandAlloc(allocator, input.app.command, parsed, null, null);
            defer decoded.deinit();
            if (!decoded.ok()) {
                const issue_json = try decoded.issues.jsonAlloc(allocator);
                defer allocator.free(issue_json);
                try console.writeErr(issue_json);
                try console.writeErr("\n");
                _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.runTyped", "failure", "decode");
                return buildRunSummary(allocator, Command.Meta.name, "failure", .usage, &.{
                    .{ .kind = "cli_decode_failed", .detail = issue_json },
                    .{ .kind = "cli_command_completed", .detail = "failure" },
                });
            }

            var handler_context = HandlerContext{ .allocator = allocator, .console = console };
            input.app.handler(&handler_context, decoded.value.?) catch |failure| {
                try writeCliError(console, "handler", failure);
                _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.runTyped", "failure", @errorName(failure));
                return buildRunSummary(allocator, Command.Meta.name, "failure", exitCodeForError(failure), &.{
                    .{ .kind = "cli_decode_completed", .detail = "success" },
                    .{ .kind = "cli_handler_failed", .detail = @errorName(failure) },
                    .{ .kind = "cli_command_completed", .detail = "failure" },
                });
            };

            _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.runTyped", "success", Command.Meta.name);
            return buildRunSummary(allocator, Command.Meta.name, "success", .success, &.{
                .{ .kind = "cli_decode_completed", .detail = "success" },
                .{ .kind = "cli_handler_completed", .detail = "success" },
                .{ .kind = "cli_command_completed", .detail = "success" },
            });
        }
    }.execute);
}

fn RunInput(comptime HandlerFailure: type) type {
    return struct { app: Application(HandlerFailure), args: []const []const u8 };
}

pub fn runApplication(
    comptime HandlerFailure: type,
    app: Application(HandlerFailure),
    args: []const []const u8,
) fx.kernel.Effect(RunSummary, anyerror, .{Runner}).Stateful(RunInput(HandlerFailure)) {
    const Run = fx.kernel.Effect(RunSummary, anyerror, .{Runner});
    const Input = RunInput(HandlerFailure);
    return Run.fromState(Input, .{ .app = app, .args = args }, struct {
        fn execute(input: Input, ctx: *Run.Context) anyerror!RunSummary {
            _ = ctx.service(Runner);
            const allocator = ctx.allocator();
            const console = ctx.console();
            _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.run", "started", input.app.spec.name);

            var parsed = parse(allocator, input.app.spec, input.args) catch |failure| {
                try writeCliError(console, "parse", failure);
                _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.run", "failure", @errorName(failure));
                return buildRunSummary(allocator, input.app.spec.name, "failure", exitCodeForError(failure), &.{
                    .{ .kind = "cli_command_started", .detail = input.app.spec.name },
                    .{ .kind = "cli_parse_failed", .detail = @errorName(failure) },
                });
            };
            defer parsed.deinit(allocator);

            const command_text = try formatCommandPathAlloc(allocator, parsed.path);
            defer allocator.free(command_text);
            const handler = input.app.findHandler(parsed) orelse {
                const failure = CliError.UnknownSubcommand;
                try writeCliError(console, "handler", failure);
                return buildRunSummary(allocator, command_text, "failure", exitCodeForError(failure), &.{
                    .{ .kind = "cli_command_started", .detail = command_text },
                    .{ .kind = "cli_handler_missing", .detail = @errorName(failure) },
                });
            };

            var handler_context = HandlerContext{ .allocator = allocator, .console = console };
            handler.run(&handler_context, parsed) catch |failure| {
                try writeCliError(console, "handler", failure);
                _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.run", "failure", @errorName(failure));
                return buildRunSummary(allocator, command_text, "failure", exitCodeForError(failure), &.{
                    .{ .kind = "cli_command_started", .detail = command_text },
                    .{ .kind = "cli_handler_failed", .detail = @errorName(failure) },
                    .{ .kind = "cli_command_completed", .detail = "failure" },
                });
            };

            _ = StdService.recordSemantic(ctx, .span_recorded, Runner.service_key, "Cli.run", "success", command_text);
            return buildRunSummary(allocator, command_text, "success", .success, &.{
                .{ .kind = "cli_command_started", .detail = command_text },
                .{ .kind = "cli_handler_completed", .detail = "success" },
                .{ .kind = "cli_command_completed", .detail = "success" },
            });
        }
    }.execute);
}

const ServiceBuiltinMatch = struct {
    request: BuiltinRequest,
    command_path: []const []const u8 = &.{},
};

fn detectServiceBuiltin(spec: CommandSpec, args: []const []const u8) ?ServiceBuiltinMatch {
    if (args.len == 0) return .{ .request = .help };
    if (detectBuiltinNamed(spec.name, args)) |request| {
        return .{
            .request = request,
            .command_path = if (request == .completions and args.len > 1) args[1..] else &.{},
        };
    }
    if (std.mem.eql(u8, args[0], "help")) {
        return .{ .request = .help, .command_path = args[1..] };
    }
    if (std.mem.eql(u8, args[0], "completions")) {
        return .{ .request = .completions, .command_path = args[1..] };
    }
    const last = args[args.len - 1];
    if (std.mem.eql(u8, last, "--help") or std.mem.eql(u8, last, "-h")) {
        return .{ .request = .help, .command_path = args[0 .. args.len - 1] };
    }
    return null;
}

fn usageOutputAlloc(
    allocator: std.mem.Allocator,
    spec: CommandSpec,
    failure: anyerror,
) std.mem.Allocator.Error![]u8 {
    const help = try formatHelp(allocator, spec);
    defer allocator.free(help);
    return std.fmt.allocPrint(allocator, "usage: {s}\n{s}", .{ @errorName(failure), help });
}

fn typedUsageOutputAlloc(
    allocator: std.mem.Allocator,
    command: anytype,
    failure: anyerror,
) std.mem.Allocator.Error![]u8 {
    const help = try formatTypedHelp(allocator, command);
    defer allocator.free(help);
    return std.fmt.allocPrint(allocator, "usage: {s}\n{s}", .{ @errorName(failure), help });
}

fn serviceShortCircuit(
    comptime Services: anytype,
    comptime Failure: type,
    allocator: std.mem.Allocator,
    application: ServiceApplication(Services, Failure),
    kind: ShortCircuitKind,
    exit_code: ExitCode,
    stream: ShortCircuitStream,
    output: []const u8,
) ServicePreflight(Services, Failure) {
    return .{
        .allocator = allocator,
        .application = application,
        .short_circuit = .{
            .kind = kind,
            .exit_code = exit_code,
            .stream = stream,
            .output = output,
        },
    };
}

fn serviceTypedShortCircuit(
    comptime Services: anytype,
    comptime Args: type,
    comptime Failure: type,
    comptime Command: type,
    allocator: std.mem.Allocator,
    application: ServiceTypedApplication(Services, Args, Failure, Command),
    kind: ShortCircuitKind,
    exit_code: ExitCode,
    stream: ShortCircuitStream,
    output: []const u8,
) ServiceTypedPreflight(Services, Args, Failure, Command) {
    return .{
        .allocator = allocator,
        .application = application,
        .short_circuit = .{
            .kind = kind,
            .exit_code = exit_code,
            .stream = stream,
            .output = output,
        },
    };
}

pub fn preflightServiceApplication(
    comptime Services: anytype,
    comptime Failure: type,
    allocator: std.mem.Allocator,
    application: ServiceApplication(Services, Failure),
    args: []const []const u8,
) (std.mem.Allocator.Error || CommandIdentityError)!ServicePreflight(Services, Failure) {
    if (detectServiceBuiltin(application.spec, args)) |builtin| {
        const output = switch (builtin.request) {
            .help => help: {
                const active = activeCommandSpecForArgs(application.spec, builtin.command_path) catch |failure| {
                    const usage = try usageOutputAlloc(allocator, application.spec, failure);
                    return serviceShortCircuit(Services, Failure, allocator, application, .usage, .usage, .stderr, usage);
                };
                break :help try formatHelp(allocator, active);
            },
            .version => try std.fmt.allocPrint(allocator, "{s} {s}\n", .{ application.spec.name, application.version }),
            .completions => formatCompletions(allocator, application.spec, builtin.command_path) catch |failure| {
                const usage = try usageOutputAlloc(allocator, application.spec, failure);
                return serviceShortCircuit(Services, Failure, allocator, application, .usage, .usage, .stderr, usage);
            },
        };
        return serviceShortCircuit(
            Services,
            Failure,
            allocator,
            application,
            switch (builtin.request) {
                .help => .help,
                .version => .version,
                .completions => .completions,
            },
            .success,
            .stdout,
            output,
        );
    }

    var parsed = parse(allocator, application.spec, args) catch |failure| {
        const usage = try usageOutputAlloc(allocator, application.spec, failure);
        return serviceShortCircuit(Services, Failure, allocator, application, .usage, .usage, .stderr, usage);
    };
    errdefer parsed.deinit(allocator);

    if (application.findHandler(parsed) == null) {
        const usage = try usageOutputAlloc(allocator, application.spec, CliError.UnknownSubcommand);
        parsed.deinit(allocator);
        return serviceShortCircuit(Services, Failure, allocator, application, .usage, .usage, .stderr, usage);
    }

    const handler = application.findHandler(parsed).?;
    const identity = try commandIdentityFromMatchedPath(parsed.path[1..]);
    const sealed_command = try allocator.create(ServicePreflight(Services, Failure).SealedCommand);
    sealed_command.* = .{
        .identity = identity,
        .effect = serviceCommandEffect(Services, Failure, handler, parsed),
    };
    return .{
        .allocator = allocator,
        .application = application,
        .parsed = parsed,
        .sealed_command = @ptrCast(sealed_command),
    };
}

pub fn preflightServiceTyped(
    comptime Services: anytype,
    comptime Args: type,
    comptime Failure: type,
    comptime Command: type,
    allocator: std.mem.Allocator,
    application: ServiceTypedApplication(Services, Args, Failure, Command),
    args: []const []const u8,
) (anyerror || CommandIdentityError)!ServiceTypedPreflight(Services, Args, Failure, Command) {
    if (detectBuiltin(application.command, args)) |builtin| {
        const output = switch (builtin) {
            .help => try formatTypedHelp(allocator, application.command),
            .version => try formatTypedVersion(allocator, application.command),
            .completions => try formatTypedCompletions(allocator, application.command),
        };
        return serviceTypedShortCircuit(
            Services,
            Args,
            Failure,
            Command,
            allocator,
            application,
            switch (builtin) {
                .help => .help,
                .version => .version,
                .completions => .completions,
            },
            .success,
            .stdout,
            output,
        );
    }

    var parsed = parse(allocator, application.command.toCommandSpec(), args) catch |failure| {
        const usage = try typedUsageOutputAlloc(allocator, application.command, failure);
        return serviceTypedShortCircuit(Services, Args, Failure, Command, allocator, application, .usage, .usage, .stderr, usage);
    };
    defer parsed.deinit(allocator);

    var decoded = try decodeTypedCommandAlloc(allocator, application.command, parsed, null, null);
    errdefer decoded.deinit();
    if (!decoded.ok()) {
        const issue_json = try decoded.issues.jsonAlloc(allocator);
        decoded.deinit();
        return serviceTypedShortCircuit(Services, Args, Failure, Command, allocator, application, .usage, .usage, .stderr, issue_json);
    }

    const identity = try commandIdentityFromMatchedPath(&.{Command.Meta.name});
    const sealed_command = try allocator.create(ServiceTypedPreflight(Services, Args, Failure, Command).SealedCommand);
    sealed_command.* = .{
        .identity = identity,
        .effect = serviceTypedCommandEffect(
            Services,
            Args,
            Failure,
            application.handler,
            decoded.value.?,
        ),
    };
    return .{
        .allocator = allocator,
        .application = application,
        .decoded = decoded,
        .sealed_command = @ptrCast(sealed_command),
    };
}

pub fn parse(
    allocator: std.mem.Allocator,
    spec: CommandSpec,
    args: []const []const u8,
) !ParsedCommand {
    var active = spec;
    var consumed: usize = 0;
    var path = std.ArrayList([]const u8).empty;
    errdefer path.deinit(allocator);
    try path.append(allocator, spec.name);

    while (consumed < args.len and args[consumed].len > 0 and args[consumed][0] != '-') {
        if (findSubcommand(active, args[consumed])) |subcommand| {
            active = subcommand;
            consumed += 1;
            try path.append(allocator, subcommand.name);
        } else if (active.subcommands.len > 0) {
            return CliError.UnknownSubcommand;
        } else {
            break;
        }
    }

    if (active.default_subcommand) |default_name| {
        if (consumed == args.len or (args[consumed].len > 0 and args[consumed][0] == '-')) {
            const subcommand = findSubcommand(active, default_name) orelse return CliError.UnknownSubcommand;
            active = subcommand;
            try path.append(allocator, subcommand.name);
        }
    }

    var options = std.ArrayList(ParsedOption).empty;
    errdefer options.deinit(allocator);
    var positionals = std.ArrayList([]const u8).empty;
    errdefer positionals.deinit(allocator);

    var index = consumed;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--")) {
            index += 1;
            while (index < args.len) : (index += 1) {
                try positionals.append(allocator, args[index]);
            }
            break;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            const raw = arg[2..];
            const equals = std.mem.indexOfScalar(u8, raw, '=');
            const name = if (equals) |eq| raw[0..eq] else raw;
            const legacy_option = findOption(active, name) orelse return CliError.UnknownOption;
            const value: ?[]const u8 = switch (legacy_option.kind) {
                .boolean => "true",
                .string, .integer => blk: {
                    if (equals) |eq| break :blk raw[eq + 1 ..];
                    if (index + 1 >= args.len) return CliError.MissingOptionValue;
                    index += 1;
                    break :blk args[index];
                },
            };
            try validateOptionValue(legacy_option, value);
            try options.append(allocator, .{ .name = legacy_option.name, .value = value });
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len == 2) {
            const legacy_option = findShortOption(active, arg[1]) orelse return CliError.UnknownOption;
            const value: ?[]const u8 = switch (legacy_option.kind) {
                .boolean => "true",
                .string, .integer => blk: {
                    if (index + 1 >= args.len) return CliError.MissingOptionValue;
                    index += 1;
                    break :blk args[index];
                },
            };
            try validateOptionValue(legacy_option, value);
            try options.append(allocator, .{ .name = legacy_option.name, .value = value });
        } else {
            try positionals.append(allocator, arg);
        }
    }

    for (active.options) |legacy_option| {
        if (legacy_option.required and !hasParsedOption(options.items, legacy_option.name) and !optionHasDefaultSource(legacy_option)) {
            return CliError.MissingRequiredOption;
        }
    }

    const owned_path = try path.toOwnedSlice(allocator);
    errdefer allocator.free(owned_path);
    const owned_options = try options.toOwnedSlice(allocator);
    errdefer allocator.free(owned_options);
    const owned_positionals = try positionals.toOwnedSlice(allocator);
    errdefer allocator.free(owned_positionals);
    return .{
        .command = active.name,
        .path = owned_path,
        .options = owned_options,
        .positionals = owned_positionals,
    };
}

pub fn activeCommandSpec(root: CommandSpec, parsed: ParsedCommand) CliError!CommandSpec {
    if (parsed.path.len == 0 or !std.mem.eql(u8, parsed.path[0], root.name)) {
        return CliError.UnknownSubcommand;
    }

    var active = root;
    for (parsed.path[1..]) |name| {
        active = findSubcommand(active, name) orelse return CliError.UnknownSubcommand;
    }
    return active;
}

pub fn resolveOptionValue(
    allocator: std.mem.Allocator,
    parsed: ParsedCommand,
    active: CommandSpec,
    name: []const u8,
    env: ?*const Env.EnvMap,
    config: ?*const Config.LayeredConfig,
) (CliError || Env.EnvError || Config.ConfigError || std.mem.Allocator.Error)!?[]const u8 {
    _ = allocator;
    const legacy_option = findOption(active, name) orelse return CliError.UnknownOption;

    if (parsed.optionValue(name)) |value| {
        try validateOptionValue(legacy_option, value);
        return value;
    }

    if (legacy_option.env) |env_name| {
        if (env) |env_map| {
            if (env_map.get(env_name)) |value| {
                try validateOptionValue(legacy_option, value);
                return value;
            }
        }
    }

    if (legacy_option.config_key) |config_key| {
        if (config) |layered_config| {
            if (layered_config.get(config_key)) |value| {
                try validateOptionValue(legacy_option, value);
                return value;
            }
        }
    }

    if (legacy_option.default_value) |value| {
        try validateOptionValue(legacy_option, value);
        return value;
    }

    if (legacy_option.required) return CliError.MissingRequiredOption;
    return null;
}

pub fn decodeTypedCommandAlloc(
    allocator: std.mem.Allocator,
    command: anytype,
    parsed: ParsedCommand,
    env: ?*const Env.EnvMap,
    config: ?*const Config.LayeredConfig,
) std.mem.Allocator.Error!TypedDecodeResult(@TypeOf(command).ArgsType) {
    const Command = @TypeOf(command);
    const Args = Command.ArgsType;
    var issues = Schema.IssueList.init(allocator);
    errdefer issues.deinit();

    var sources = std.ArrayList(OptionSourceFact).empty;
    errdefer deinitSourceBuilder(allocator, &sources);

    var output: Args = undefined;
    var failed = false;

    const args_info = @typeInfo(Args).@"struct";
    inline for (args_info.fields) |field_info| {
        const option_spec = typedOptionForField(command.options, field_info.name);
        const OptionSpecType = @TypeOf(option_spec);
        const resolved = try resolveTypedOptionText(parsed, option_spec, env, config);
        const path = try std.fmt.allocPrint(allocator, "--{s}", .{OptionSpecType.Meta.long});
        defer allocator.free(path);

        if (resolved.value) |text| {
            try appendSourceFact(allocator, &sources, OptionSpecType.Meta.long, resolved.source, text, OptionSpecType.Meta.secret);
            field_decode: {
                const decoded = decodeOptionText(field_info.type, allocator, option_spec.schema, path, text, &issues) catch {
                    failed = true;
                    break :field_decode;
                };
                @field(output, field_info.name) = decoded;
            }
        } else if (field_info.type == bool) {
            try appendSourceFact(allocator, &sources, OptionSpecType.Meta.long, .default, "false", OptionSpecType.Meta.secret);
            @field(output, field_info.name) = false;
        } else if (comptime isOptionalType(field_info.type)) {
            try appendSourceFact(allocator, &sources, OptionSpecType.Meta.long, .missing, "", OptionSpecType.Meta.secret);
            @field(output, field_info.name) = null;
        } else {
            try appendSourceFact(allocator, &sources, OptionSpecType.Meta.long, .missing, "", OptionSpecType.Meta.secret);
            try issues.add(.{
                .path = path,
                .kind = .missing_field,
                .expected = OptionSpecType.Meta.long,
                .actual = "missing",
                .message = "required CLI option is missing",
            });
            failed = true;
        }
    }

    const source_slice = try sources.toOwnedSlice(allocator);
    if (failed or issues.len() != 0) {
        return .{
            .allocator = allocator,
            .value = null,
            .issues = issues,
            .sources = source_slice,
        };
    }
    return .{
        .allocator = allocator,
        .value = output,
        .issues = issues,
        .sources = source_slice,
    };
}

pub fn formatHelp(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    if (spec.subcommands.len == 0) {
        try output.print(allocator, "Usage: {s} [options]\n", .{spec.name});
    } else {
        try output.print(allocator, "Usage: {s} [command] [options]\n", .{spec.name});
    }
    if (spec.description.len != 0) {
        try output.print(allocator, "\n{s}\n", .{spec.description});
    }
    if (spec.subcommands.len != 0) {
        try output.appendSlice(allocator, "\nCommands:\n");
        const width = maxCommandNameWidth(spec.subcommands);
        for (spec.subcommands) |subcommand| {
            try output.print(allocator, "  {s}", .{subcommand.name});
            try appendSpaces(&output, allocator, width - subcommand.name.len + 2);
            try output.print(allocator, "{s}\n", .{subcommand.description});
        }
    }
    if (spec.options.len != 0) {
        try output.appendSlice(allocator, "\nOptions:\n");
        for (spec.options) |legacy_option| {
            switch (legacy_option.kind) {
                .string => try output.print(allocator, "  --{s} <value>  {s}\n", .{ legacy_option.name, legacy_option.help }),
                .integer => try output.print(allocator, "  --{s} <int>    {s}\n", .{ legacy_option.name, legacy_option.help }),
                .boolean => try output.print(allocator, "  --{s}       {s}\n", .{ legacy_option.name, legacy_option.help }),
            }
        }
    }
    return output.toOwnedSlice(allocator);
}

pub fn formatCompletions(allocator: std.mem.Allocator, spec: CommandSpec, args: []const []const u8) ![]const u8 {
    const active = try activeCommandSpecForArgs(spec, args);
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    for (active.subcommands) |subcommand| {
        try output.print(allocator, "command {s}", .{subcommand.name});
        if (subcommand.description.len != 0) {
            try output.print(allocator, " {s}", .{subcommand.description});
        }
        try output.append(allocator, '\n');
    }

    for (active.options) |legacy_option| {
        try output.print(allocator, "option --{s}", .{legacy_option.name});
        if (legacy_option.help.len != 0) {
            try output.print(allocator, " {s}", .{legacy_option.help});
        }
        try output.append(allocator, '\n');
    }

    return output.toOwnedSlice(allocator);
}

pub fn formatTypedHelp(allocator: std.mem.Allocator, command: anytype) std.mem.Allocator.Error![]const u8 {
    const Command = @TypeOf(command);
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "Usage: {s} [options]\n", .{Command.Meta.name});
    if (Command.Meta.description.len != 0) {
        try output.print(allocator, "\n{s}\n", .{Command.Meta.description});
    }

    if (typedOptionCount(Command.OptionsType) != 0) {
        try output.appendSlice(allocator, "\nOptions:\n");
        inline for (@typeInfo(Command.OptionsType).@"struct".fields) |field_info| {
            const Option = field_info.type;
            try output.print(allocator, "  --{s}", .{Option.Meta.long});
            if (Option.Meta.short) |short| try output.print(allocator, ", -{c}", .{short});
            try output.print(allocator, " <{s}>", .{optionHintForOutput(Option.SchemaType.Output)});
            if (Option.Meta.help.len != 0) try output.print(allocator, "  {s}", .{Option.Meta.help});
            if (Option.Meta.required) try output.appendSlice(allocator, " [required]");
            if (Option.Meta.env) |env_name| try output.print(allocator, " [env: {s}]", .{env_name});
            if (Option.Meta.config_key) |config_key| try output.print(allocator, " [config: {s}]", .{config_key});
            if (Option.Meta.default_value) |default_value| {
                const display_default = if (Option.Meta.secret or Secrets.containsSecret(default_value)) Secrets.redacted else default_value;
                try output.print(allocator, " [default: {s}]", .{display_default});
            }
            try output.append(allocator, '\n');
        }
    }

    return output.toOwnedSlice(allocator);
}

fn detectBuiltinNamed(command_name: []const u8, args: []const []const u8) ?BuiltinRequest {
    if (args.len == 0) return null;
    if (args.len == 1 and std.mem.eql(u8, args[0], "--help")) return .help;
    if (args.len == 1 and std.mem.eql(u8, args[0], "-h")) return .help;
    if (args.len == 1 and std.mem.eql(u8, args[0], "--version")) return .version;
    if (args.len == 1 and std.mem.eql(u8, args[0], "completions")) return .completions;
    if (args.len >= 1 and std.mem.eql(u8, args[0], "help")) {
        if (args.len == 1) return .help;
        if (std.mem.eql(u8, args[1], command_name)) return .help;
    }
    return null;
}

pub fn detectBuiltin(command: anytype, args: []const []const u8) ?BuiltinRequest {
    const Command = @TypeOf(command);
    return detectBuiltinNamed(Command.Meta.name, args);
}

pub fn formatTypedVersion(allocator: std.mem.Allocator, command: anytype) std.mem.Allocator.Error![]const u8 {
    const Command = @TypeOf(command);
    return std.fmt.allocPrint(allocator, "{s} {s}\n", .{ Command.Meta.name, Command.Meta.version });
}

pub fn formatTypedCompletions(allocator: std.mem.Allocator, command: anytype) std.mem.Allocator.Error![]const u8 {
    const Command = @TypeOf(command);
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    inline for (@typeInfo(Command.OptionsType).@"struct".fields) |field_info| {
        const Option = field_info.type;
        try output.print(allocator, "option --{s}", .{Option.Meta.long});
        if (Option.Meta.help.len != 0) try output.print(allocator, " {s}", .{Option.Meta.help});
        try output.append(allocator, '\n');
    }

    return output.toOwnedSlice(allocator);
}

pub fn exitCodeForError(err: anyerror) ExitCode {
    return switch (err) {
        CliError.UnknownOption,
        CliError.MissingOptionValue,
        CliError.MissingRequiredOption,
        CliError.UnknownSubcommand,
        CliError.InvalidInteger,
        => .usage,
        error.MissingVariable, error.MissingValue => .config,
        error.FileNotFound, error.AccessDenied, error.PathAlreadyExists => .io,
        error.Interrupted => .interrupted,
        else => .defect,
    };
}

pub fn formatRunReceiptJson(allocator: std.mem.Allocator, receipt: CliRunReceipt) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const command = try Secrets.redactAlloc(allocator, receipt.command);
    defer allocator.free(command);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringField(allocator, &output, "  ", "schema", receipt.schema, true);
    try appendJsonStringField(allocator, &output, "  ", "command", command, true);
    try appendJsonStringField(allocator, &output, "  ", "status", receipt.status, true);
    try output.appendSlice(allocator, "  \"facts\": [\n");
    for (receipt.facts, 0..) |fact, index| {
        const detail = try Secrets.redactAlloc(allocator, fact.detail);
        defer allocator.free(detail);

        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringField(allocator, &output, "      ", "kind", fact.kind, true);
        try appendJsonStringField(allocator, &output, "      ", "detail", detail, false);
        try output.appendSlice(allocator, "    }");
        if (index + 1 != receipt.facts.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ]\n");
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn buildRunSummary(
    allocator: std.mem.Allocator,
    command: []const u8,
    status: []const u8,
    exit_code: ExitCode,
    facts: []const CliRunFact,
) std.mem.Allocator.Error!RunSummary {
    const redacted_command = try Secrets.redactAlloc(allocator, command);
    errdefer allocator.free(redacted_command);

    const receipt_json = try formatRunReceiptJson(allocator, .{
        .command = redacted_command,
        .status = status,
        .facts = facts,
    });
    errdefer allocator.free(receipt_json);

    return .{
        .command = redacted_command,
        .status = status,
        .exit_code = exit_code,
        .receipt_json = receipt_json,
    };
}

fn writeCliError(console: fx.kernel.Console, phase: []const u8, err: anyerror) anyerror!void {
    try console.writeErr(phase);
    try console.writeErr(": ");
    try console.writeErr(@errorName(err));
    try console.writeErr("\n");
}

fn formatCommandPathAlloc(allocator: std.mem.Allocator, path: []const []const u8) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    for (path, 0..) |part, index| {
        if (index != 0) try output.append(allocator, ' ');
        try output.appendSlice(allocator, part);
    }

    return output.toOwnedSlice(allocator);
}

fn commandPathsEqual(left: []const []const u8, right: []const []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_part, right_part| {
        if (!std.mem.eql(u8, left_part, right_part)) return false;
    }
    return true;
}

fn findSubcommand(spec: CommandSpec, name: []const u8) ?CommandSpec {
    for (spec.subcommands) |subcommand| {
        if (std.mem.eql(u8, subcommand.name, name)) return subcommand;
    }
    return null;
}

fn findOption(spec: CommandSpec, name: []const u8) ?OptionSpec {
    for (spec.options) |legacy_option| {
        if (std.mem.eql(u8, legacy_option.name, name)) return legacy_option;
    }
    return null;
}

fn findShortOption(spec: CommandSpec, short: u8) ?OptionSpec {
    for (spec.options) |legacy_option| {
        if (legacy_option.short != null and legacy_option.short.? == short) return legacy_option;
    }
    return null;
}

fn activeCommandSpecForArgs(root: CommandSpec, args: []const []const u8) CliError!CommandSpec {
    var active = root;
    for (args) |arg| {
        if (arg.len == 0 or arg[0] == '-') break;
        if (findSubcommand(active, arg)) |subcommand| {
            active = subcommand;
        } else if (active.subcommands.len != 0) {
            return CliError.UnknownSubcommand;
        } else {
            break;
        }
    }
    return active;
}

fn maxCommandNameWidth(commands: []const CommandSpec) usize {
    var width: usize = 0;
    for (commands) |command| {
        width = @max(width, command.name.len);
    }
    return width;
}

fn appendSpaces(output: *std.ArrayList(u8), allocator: std.mem.Allocator, count: usize) std.mem.Allocator.Error!void {
    var index: usize = 0;
    while (index < count) : (index += 1) {
        try output.append(allocator, ' ');
    }
}

fn validateOptionValue(legacy_option: OptionSpec, value: ?[]const u8) CliError!void {
    if (legacy_option.kind == .integer) {
        _ = std.fmt.parseInt(i64, value orelse return CliError.MissingOptionValue, 10) catch {
            return CliError.InvalidInteger;
        };
    }
}

fn hasParsedOption(options: []const ParsedOption, name: []const u8) bool {
    for (options) |parsed_option| {
        if (std.mem.eql(u8, parsed_option.name, name)) return true;
    }
    return false;
}

fn optionHasDefaultSource(legacy_option: OptionSpec) bool {
    return legacy_option.default_value != null or legacy_option.env != null or legacy_option.config_key != null;
}

fn typedLegacyOptions(comptime Options: type) [typedOptionCount(Options)]OptionSpec {
    var specs: [typedOptionCount(Options)]OptionSpec = undefined;
    const options_info = @typeInfo(Options).@"struct";
    inline for (options_info.fields, 0..) |field_info, index| {
        const Option = field_info.type;
        specs[index] = .{
            .name = Option.Meta.long,
            .short = Option.Meta.short,
            .kind = optionKindForOutput(Option.SchemaType.Output),
            .required = Option.Meta.required,
            .help = Option.Meta.help,
            .default_value = Option.Meta.default_value,
            .env = Option.Meta.env,
            .config_key = Option.Meta.config_key,
        };
    }
    return specs;
}

fn typedOptionCount(comptime Options: type) usize {
    return @typeInfo(Options).@"struct".fields.len;
}

fn optionKindForOutput(comptime Output: type) OptionKind {
    return switch (@typeInfo(Output)) {
        .bool => .boolean,
        .int => .integer,
        .optional => |optional_info| optionKindForOutput(optional_info.child),
        else => .string,
    };
}

fn optionHintForOutput(comptime Output: type) []const u8 {
    return switch (@typeInfo(Output)) {
        .bool => "bool",
        .int => "int",
        .optional => |optional_info| optionHintForOutput(optional_info.child),
        else => "value",
    };
}

fn typedOptionForField(options: anytype, comptime field_name: []const u8) typedOptionTypeForField(@TypeOf(options), field_name) {
    inline for (@typeInfo(@TypeOf(options)).@"struct".fields) |field_info| {
        const option_value = @field(options, field_info.name);
        if (comptime std.mem.eql(u8, @TypeOf(option_value).FieldName, field_name)) return option_value;
    }
    @compileError("typed CLI option missing for field: " ++ field_name);
}

fn typedOptionTypeForField(comptime Options: type, comptime field_name: []const u8) type {
    inline for (@typeInfo(Options).@"struct".fields) |field_info| {
        if (std.mem.eql(u8, field_info.type.FieldName, field_name)) return field_info.type;
    }
    @compileError("typed CLI option missing for field: " ++ field_name);
}

const ResolvedOptionText = struct {
    value: ?[]const u8,
    source: OptionSourceKind,
};

fn resolveTypedOptionText(
    parsed: ParsedCommand,
    option_spec: anytype,
    env: ?*const Env.EnvMap,
    config: ?*const Config.LayeredConfig,
) std.mem.Allocator.Error!ResolvedOptionText {
    const meta = @TypeOf(option_spec).Meta;
    if (parsed.optionValue(meta.long)) |value| return .{ .value = value, .source = .cli };
    if (meta.env) |env_name| {
        if (env) |env_map| {
            if (env_map.get(env_name)) |value| return .{ .value = value, .source = .env };
        }
    }
    if (meta.config_key) |config_key| {
        if (config) |layered_config| {
            if (layered_config.get(config_key)) |value| return .{ .value = value, .source = .config };
        }
    }
    if (meta.default_value) |default_value| return .{ .value = default_value, .source = .default };
    return .{ .value = null, .source = .missing };
}

fn decodeOptionText(
    comptime Output: type,
    allocator: std.mem.Allocator,
    schema: anytype,
    path: []const u8,
    text: []const u8,
    issues: *Schema.IssueList,
) (Schema.SchemaError || std.mem.Allocator.Error)!Output {
    var ctx = Schema.ParseContext.init(allocator, issues);
    defer ctx.deinit();
    try ctx.path.appendSlice(allocator, path);

    const value = try cliTextJsonValue(Output, text);
    if (@hasDecl(@TypeOf(schema), "decodeDetailedJsonValue")) {
        return schema.decodeDetailedJsonValue(&ctx, value) catch |err| {
            return err;
        };
    }

    return schema.decodeJsonValue(value) catch |err| {
        try issues.add(.{
            .path = path,
            .kind = schemaErrorIssueKind(err),
            .expected = path,
            .actual = text,
            .message = @errorName(err),
        });
        return err;
    };
}

fn cliTextJsonValue(comptime Output: type, text: []const u8) Schema.SchemaError!std.json.Value {
    return switch (@typeInfo(Output)) {
        .bool => .{ .bool = parseBoolText(text) catch return Schema.SchemaError.InvalidValue },
        .int => .{ .integer = std.fmt.parseInt(i64, text, 10) catch return Schema.SchemaError.InvalidValue },
        .optional => |optional_info| try cliTextJsonValue(optional_info.child, text),
        else => .{ .string = text },
    };
}

fn parseBoolText(text: []const u8) Schema.SchemaError!bool {
    if (std.mem.eql(u8, text, "true")) return true;
    if (std.mem.eql(u8, text, "false")) return false;
    return Schema.SchemaError.InvalidValue;
}

fn appendSourceFact(
    allocator: std.mem.Allocator,
    sources: *std.ArrayList(OptionSourceFact),
    name: []const u8,
    source: OptionSourceKind,
    value: []const u8,
    force_secret: bool,
) std.mem.Allocator.Error!void {
    const owned_name = try allocator.dupe(u8, name);
    errdefer allocator.free(owned_name);
    const redacted_value = if (force_secret or Secrets.containsSecret(value))
        try allocator.dupe(u8, Secrets.redacted)
    else
        try allocator.dupe(u8, value);
    errdefer allocator.free(redacted_value);

    try sources.append(allocator, .{
        .name = owned_name,
        .source = source,
        .redacted_value = redacted_value,
    });
}

fn deinitSourceBuilder(allocator: std.mem.Allocator, sources: *std.ArrayList(OptionSourceFact)) void {
    for (sources.items) |source| {
        allocator.free(source.name);
        allocator.free(source.redacted_value);
    }
    sources.deinit(allocator);
}

fn isOptionalType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .optional => true,
        else => false,
    };
}

fn schemaErrorIssueKind(err: Schema.SchemaError) Schema.IssueKind {
    return switch (err) {
        Schema.SchemaError.InvalidType => .invalid_type,
        Schema.SchemaError.MissingField => .missing_field,
        Schema.SchemaError.InvalidValue => .invalid_value,
        Schema.SchemaError.UnknownEnum => .unknown_enum,
        Schema.SchemaError.TransformFailed => .transform_failed,
    };
}

fn appendJsonStringField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    indent: []const u8,
    name: []const u8,
    value: []const u8,
    trailing_comma: bool,
) !void {
    try output.appendSlice(allocator, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (trailing_comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '"' => try output.appendSlice(allocator, "\\\""),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

test "Cli parses long string option and positional args" {
    const command = CommandSpec{
        .name = "zg",
        .options = &.{
            .{ .name = "name", .kind = .string, .required = true },
        },
    };

    var parsed = try parse(std.testing.allocator, command, &.{ "--name", "Sean", "extra" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("zg", parsed.command);
    try std.testing.expectEqualStrings("Sean", parsed.optionValue("name").?);
    try std.testing.expectEqualStrings("extra", parsed.positionals[0]);
}

test "Cli rejects unknown option" {
    const command = CommandSpec{ .name = "zg" };

    try std.testing.expectError(
        CliError.UnknownOption,
        parse(std.testing.allocator, command, &.{"--wat"}),
    );
}

test "Cli routes one subcommand" {
    const subcommands = [_]CommandSpec{
        .{ .name = "hello" },
    };
    const command = CommandSpec{
        .name = "zg",
        .subcommands = subcommands[0..],
    };

    var parsed = try parse(std.testing.allocator, command, &.{ "hello", "world" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("hello", parsed.command);
    try std.testing.expectEqual(@as(usize, 2), parsed.path.len);
    try std.testing.expectEqualStrings("zg", parsed.path[0]);
    try std.testing.expectEqualStrings("hello", parsed.path[1]);
    try std.testing.expectEqualStrings("world", parsed.positionals[0]);
}

test "Cli help text is deterministic" {
    const command = CommandSpec{
        .name = "zg",
        .description = "zigeffect tools",
        .options = &.{
            .{ .name = "name", .kind = .string, .help = "name to greet" },
            .{ .name = "verbose", .kind = .boolean, .help = "enable verbose output" },
        },
    };

    const help = try formatHelp(std.testing.allocator, command);
    defer std.testing.allocator.free(help);

    try std.testing.expectEqualStrings(
        \\Usage: zg [options]
        \\
        \\zigeffect tools
        \\
        \\Options:
        \\  --name <value>  name to greet
        \\  --verbose       enable verbose output
        \\
    , help);
}

test "Cli formats command run receipt JSON" {
    const facts = [_]CliRunFact{
        .{ .kind = "cli_command_started", .detail = "zg hello" },
        .{ .kind = "cli_command_completed", .detail = "success" },
    };
    const json = try formatRunReceiptJson(std.testing.allocator, .{
        .command = "zg hello",
        .status = "success",
        .facts = facts[0..],
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\": \"zigeffect.std.cli-run.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"command\": \"zg hello\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\": \"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\": \"cli_command_started\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"detail\": \"success\"") != null);
}

test "Cli redacts command run receipt JSON" {
    const facts = [_]CliRunFact{
        .{ .kind = "cli_command_started", .detail = "password=hunter2" },
    };
    const json = try formatRunReceiptJson(std.testing.allocator, .{
        .command = "zg token=abc123",
        .status = "failure",
        .facts = facts[0..],
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "[REDACTED]") != null);
}

test "Cli parses short flags and integer options" {
    const command = CommandSpec{
        .name = "zg",
        .options = &.{
            .{ .name = "verbose", .short = 'v', .kind = .boolean },
            .{ .name = "count", .short = 'c', .kind = .integer, .required = true },
        },
    };

    var parsed = try parse(std.testing.allocator, command, &.{ "-v", "-c", "3" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("true", parsed.optionValue("verbose").?);
    try std.testing.expectEqualStrings("3", parsed.optionValue("count").?);
}

test "Cli parser releases every partial result on allocation failure" {
    const command = CommandSpec{
        .name = "zg",
        .options = &.{.{ .name = "count", .short = 'c', .kind = .integer, .required = true }},
    };
    const Harness = struct {
        fn run(allocator: std.mem.Allocator, spec: CommandSpec) !void {
            var parsed = try parse(allocator, spec, &.{ "-c", "3", "item" });
            defer parsed.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{command});
}

test "Cli maps errors to deterministic exit codes" {
    try std.testing.expectEqual(ExitCode.usage, exitCodeForError(CliError.UnknownOption));
    try std.testing.expectEqual(ExitCode.config, exitCodeForError(error.MissingVariable));
    try std.testing.expectEqual(ExitCode.io, exitCodeForError(error.FileNotFound));
    try std.testing.expectEqual(ExitCode.defect, exitCodeForError(error.Unexpected));
}

test "Cli routes nested subcommands" {
    const leaf = [_]CommandSpec{
        .{ .name = "status" },
    };
    const middle = [_]CommandSpec{
        .{ .name = "workspace", .subcommands = leaf[0..] },
    };
    const command = CommandSpec{
        .name = "zg",
        .subcommands = middle[0..],
    };

    var parsed = try parse(std.testing.allocator, command, &.{ "workspace", "status", "--", "repo" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("status", parsed.command);
    try std.testing.expectEqual(@as(usize, 3), parsed.path.len);
    try std.testing.expectEqualStrings("zg", parsed.path[0]);
    try std.testing.expectEqualStrings("workspace", parsed.path[1]);
    try std.testing.expectEqualStrings("status", parsed.path[2]);
    try std.testing.expectEqualStrings("repo", parsed.positionals[0]);
}

test "Cli resolves option defaults from CLI env config and literal defaults" {
    const command = CommandSpec{
        .name = "zg",
        .options = &.{
            .{ .name = "mode", .kind = .string, .env = "ZG_MODE", .config_key = "mode", .default_value = "dev" },
            .{ .name = "workspace", .kind = .string, .config_key = "workspace" },
            .{ .name = "retries", .kind = .integer, .default_value = "2" },
        },
    };

    var env = Env.EnvMap.init(std.testing.allocator);
    defer env.deinit();
    try env.put("ZG_MODE", "env-mode");

    var config = Config.LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("mode", "config-mode", false);
    try config.put("workspace", "/repo", false);

    var parsed = try parse(std.testing.allocator, command, &.{ "--mode", "cli-mode" });
    defer parsed.deinit(std.testing.allocator);

    const active = try activeCommandSpec(command, parsed);

    try std.testing.expectEqualStrings(
        "cli-mode",
        (try resolveOptionValue(std.testing.allocator, parsed, active, "mode", &env, &config)).?,
    );
    try std.testing.expectEqualStrings(
        "/repo",
        (try resolveOptionValue(std.testing.allocator, parsed, active, "workspace", &env, &config)).?,
    );
    try std.testing.expectEqualStrings(
        "2",
        (try resolveOptionValue(std.testing.allocator, parsed, active, "retries", &env, &config)).?,
    );
}

const TypedServeArgs = struct {
    workspace: []const u8,
    port: i64,
    watch: bool,
    mode: ?[]const u8,
};

test "Cli typed command decodes CLI env config defaults with source facts" {
    const command = typedCommand(TypedServeArgs, .{
        .name = "serve",
        .description = "run local server",
    }, .{
        option("workspace", Schema.string().nonEmpty(), .{
            .long = "workspace",
            .env = "ZG_WORKSPACE",
            .config_key = "workspace",
            .help = "workspace root",
            .required = true,
        }),
        option("port", Schema.integer().min(1).max(65535), .{
            .long = "port",
            .default_value = "5178",
            .help = "local port",
        }),
        flag("watch", .{ .long = "watch", .short = 'w', .help = "watch files" }),
        option("mode", Schema.optional(Schema.stringEnum(&.{ "local", "ci" })), .{
            .long = "mode",
            .config_key = "mode",
            .help = "mode",
        }),
    });

    var env = Env.EnvMap.init(std.testing.allocator);
    defer env.deinit();
    try env.put("ZG_WORKSPACE", "/env");

    var config = Config.LayeredConfig.init(std.testing.allocator);
    defer config.deinit();
    try config.put("workspace", "/config", false);
    try config.put("mode", "ci", false);

    var parsed = try parse(std.testing.allocator, command.toCommandSpec(), &.{ "--workspace", "/cli", "-w" });
    defer parsed.deinit(std.testing.allocator);

    var decoded = try decodeTypedCommandAlloc(std.testing.allocator, command, parsed, &env, &config);
    defer decoded.deinit();

    try std.testing.expect(decoded.ok());
    try std.testing.expectEqualStrings("/cli", decoded.value.?.workspace);
    try std.testing.expectEqual(@as(i64, 5178), decoded.value.?.port);
    try std.testing.expectEqual(true, decoded.value.?.watch);
    try std.testing.expectEqualStrings("ci", decoded.value.?.mode.?);
    try expectSource(decoded, "workspace", .cli);
    try expectSource(decoded, "port", .default);
    try expectSource(decoded, "watch", .cli);
    try expectSource(decoded, "mode", .config);
}

test "Cli typed command accumulates schema issues and redacts source facts" {
    const command = typedCommand(TypedServeArgs, .{
        .name = "serve",
    }, .{
        option("workspace", Schema.string().nonEmpty(), .{ .long = "workspace", .required = true }),
        option("port", Schema.integer().min(1).max(10), .{ .long = "port" }),
        flag("watch", .{ .long = "watch" }),
        option("mode", Schema.optional(Schema.stringEnum(&.{ "local", "ci" })), .{ .long = "mode" }),
    });

    var parsed = try parse(std.testing.allocator, command.toCommandSpec(), &.{ "--port", "999", "--mode", "prod", "--workspace", "token=abc123" });
    defer parsed.deinit(std.testing.allocator);

    var decoded = try decodeTypedCommandAlloc(std.testing.allocator, command, parsed, null, null);
    defer decoded.deinit();

    try std.testing.expect(!decoded.ok());
    try expectIssuePath(decoded.issues, "--port", .constraint_failed);
    try expectIssuePath(decoded.issues, "--mode", .unknown_enum);
    try std.testing.expect(std.mem.indexOf(u8, decoded.sources[0].redacted_value, "abc123") == null);
}

test "Cli typed help includes schema source metadata and required markers" {
    const command = typedCommand(TypedServeArgs, .{
        .name = "serve",
        .description = "run local server",
        .version = "0.1.0",
    }, .{
        option("workspace", Schema.string().nonEmpty(), .{
            .long = "workspace",
            .short = 'w',
            .env = "ZG_WORKSPACE",
            .config_key = "workspace",
            .help = "workspace root",
            .required = true,
        }),
        option("port", Schema.integer().min(1).max(65535), .{
            .long = "port",
            .default_value = "5178",
            .help = "local port",
        }),
    });

    const help = try formatTypedHelp(std.testing.allocator, command);
    defer std.testing.allocator.free(help);

    try std.testing.expect(std.mem.indexOf(u8, help, "Usage: serve [options]") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "--workspace") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "-w") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "required") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "env: ZG_WORKSPACE") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "config: workspace") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "default: 5178") != null);
}

test "Cli detects typed built-in help version and completions" {
    const command = typedCommand(TypedServeArgs, .{ .name = "serve", .version = "0.1.0" }, .{
        option("workspace", Schema.string(), .{ .long = "workspace" }),
        flag("watch", .{ .long = "watch" }),
    });

    try std.testing.expectEqual(BuiltinRequest.help, detectBuiltin(command, &.{"--help"}).?);
    try std.testing.expectEqual(BuiltinRequest.help, detectBuiltin(command, &.{ "help", "serve" }).?);
    try std.testing.expectEqual(BuiltinRequest.version, detectBuiltin(command, &.{"--version"}).?);
    try std.testing.expectEqual(BuiltinRequest.completions, detectBuiltin(command, &.{"completions"}).?);

    const completions = try formatTypedCompletions(std.testing.allocator, command);
    defer std.testing.allocator.free(completions);
    try std.testing.expect(std.mem.indexOf(u8, completions, "option --workspace") != null);
    try std.testing.expect(std.mem.indexOf(u8, completions, "option --watch") != null);
}

fn expectSource(decoded: anytype, name: []const u8, source: OptionSourceKind) !void {
    for (decoded.sources) |fact| {
        if (std.mem.eql(u8, fact.name, name) and fact.source == source) return;
    }
    std.debug.print("missing source fact name={s}\n", .{name});
    return error.TestExpectedEqual;
}

fn expectIssuePath(issues: Schema.IssueList, path: []const u8, kind: Schema.IssueKind) !void {
    for (issues.items.items) |issue| {
        if (std.mem.eql(u8, issue.path, path) and issue.kind == kind) return;
    }
    std.debug.print("missing CLI issue path={s}\n", .{path});
    return error.TestExpectedEqual;
}

test "Cli help includes subcommands deterministically" {
    const subcommands = [_]CommandSpec{
        .{ .name = "hello", .description = "print greeting" },
        .{ .name = "status", .description = "show state" },
    };
    const command = CommandSpec{
        .name = "zg",
        .description = "zigeffect tools",
        .subcommands = subcommands[0..],
        .options = &.{
            .{ .name = "verbose", .kind = .boolean, .help = "enable verbose output" },
        },
    };

    const help = try formatHelp(std.testing.allocator, command);
    defer std.testing.allocator.free(help);

    try std.testing.expectEqualStrings(
        \\Usage: zg [command] [options]
        \\
        \\zigeffect tools
        \\
        \\Commands:
        \\  hello   print greeting
        \\  status  show state
        \\
        \\Options:
        \\  --verbose       enable verbose output
        \\
    , help);
}

test "Cli formats deterministic completions for active command" {
    const subcommands = [_]CommandSpec{
        .{ .name = "hello", .description = "print greeting" },
    };
    const command = CommandSpec{
        .name = "zg",
        .subcommands = subcommands[0..],
        .options = &.{
            .{ .name = "verbose", .kind = .boolean, .help = "enable verbose output" },
        },
    };

    const root_completions = try formatCompletions(std.testing.allocator, command, &.{});
    defer std.testing.allocator.free(root_completions);
    try std.testing.expectEqualStrings(
        \\command hello print greeting
        \\option --verbose enable verbose output
        \\
    , root_completions);

    const leaf_completions = try formatCompletions(std.testing.allocator, command, &.{"hello"});
    defer std.testing.allocator.free(leaf_completions);
    try std.testing.expectEqualStrings("", leaf_completions);
}

test "Cli.run executes handler through the managed runtime and records receipt facts" {
    const HandlerFailure = error{Boom};
    const TestHandlers = struct {
        fn hello(ctx: *HandlerContext, parsed: ParsedCommand) HandlerFailure!void {
            std.testing.expectEqualStrings("hello", parsed.command) catch return error.Boom;
            ctx.console.writeOut("hello Sean") catch return error.Boom;
        }
    };

    const subcommands = [_]CommandSpec{
        .{ .name = "hello" },
    };
    const command = CommandSpec{
        .name = "zg",
        .subcommands = subcommands[0..],
    };
    const hello_path = [_][]const u8{ "zg", "hello" };
    const handlers = [_]Handler(HandlerFailure){
        .{ .path = hello_path[0..], .run = TestHandlers.hello },
    };
    const app = Application(HandlerFailure){
        .spec = command,
        .handlers = handlers[0..],
    };

    var console = Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    const root = runnerLayer();
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    var summary = try runtime.run(runApplication(HandlerFailure, app, &.{"hello"}).withDefaults(.{ .console = console.asDefault() }));
    defer summary.deinit(std.testing.allocator);

    try std.testing.expectEqual(ExitCode.success, summary.exit_code);
    try std.testing.expectEqualStrings("success", summary.status);
    try std.testing.expectEqualStrings("hello Sean", console.stdoutText());
    try std.testing.expect(std.mem.indexOf(u8, summary.receipt_json, "\"command\": \"zg hello\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary.receipt_json, "\"status\": \"success\"") != null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(StdService.hasOperation(snapshot, Runner, "Cli.run", "success"));
}

test "Cli.run maps handler errors to exit codes without throwing" {
    const HandlerFailure = error{MissingVariable};
    const TestHandlers = struct {
        fn fail(_: *HandlerContext, _: ParsedCommand) HandlerFailure!void {
            return error.MissingVariable;
        }
    };

    const command = CommandSpec{ .name = "zg" };
    const root_path = [_][]const u8{"zg"};
    const handlers = [_]Handler(HandlerFailure){
        .{ .path = root_path[0..], .run = TestHandlers.fail },
    };
    const app = Application(HandlerFailure){
        .spec = command,
        .handlers = handlers[0..],
    };

    var console = Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    const root = runnerLayer();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    var summary = try runtime.run(runApplication(HandlerFailure, app, &.{}).withDefaults(.{ .console = console.asDefault() }));
    defer summary.deinit(std.testing.allocator);

    try std.testing.expectEqual(ExitCode.config, summary.exit_code);
    try std.testing.expectEqualStrings("failure", summary.status);
    try std.testing.expect(std.mem.indexOf(u8, console.stderrText(), "MissingVariable") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary.receipt_json, "\"status\": \"failure\"") != null);
}

test "Cli.runTyped decodes typed args handles builtins and records causal facts" {
    const zstd = @import("../root.zig");
    const HandlerFailure = error{Boom};
    const TestHandlers = struct {
        fn serve(ctx: *HandlerContext, args: TypedServeArgs) HandlerFailure!void {
            ctx.console.writeOut(args.workspace) catch return error.Boom;
        }
    };

    const command = typedCommand(TypedServeArgs, .{ .name = "serve", .version = "0.1.0" }, .{
        option("workspace", zstd.Schema.string().nonEmpty(), .{ .long = "workspace", .required = true }),
        option("port", zstd.Schema.integer().min(1).max(65535), .{ .long = "port", .default_value = "5178" }),
        flag("watch", .{ .long = "watch" }),
        option("mode", zstd.Schema.optional(zstd.Schema.stringEnum(&.{ "local", "ci" })), .{ .long = "mode" }),
    });
    const app = TypedApplication(TypedServeArgs, HandlerFailure, @TypeOf(command)){
        .command = command,
        .handler = TestHandlers.serve,
    };

    var console = Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    const root = runnerLayer();
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    var summary = try runtime.run(runTyped(TypedServeArgs, HandlerFailure, @TypeOf(command), app, &.{ "--workspace", "/repo" }).withDefaults(.{ .console = console.asDefault() }));
    defer summary.deinit(std.testing.allocator);

    try std.testing.expectEqual(ExitCode.success, summary.exit_code);
    try std.testing.expectEqualStrings("/repo", console.stdoutText());
    try std.testing.expect(std.mem.indexOf(u8, summary.receipt_json, "cli_decode_completed") != null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(StdService.hasOperation(snapshot, Runner, "Cli.runTyped", "success"));
}

test "Cli.run declares its runner dependency at compile time" {
    const HandlerFailure = error{Boom};
    const TestHandlers = struct {
        fn noop(_: *HandlerContext, _: ParsedCommand) HandlerFailure!void {}
    };

    const command = CommandSpec{ .name = "zg" };
    const root_path = [_][]const u8{"zg"};
    const handlers = [_]Handler(HandlerFailure){
        .{ .path = root_path[0..], .run = TestHandlers.noop },
    };
    const app = Application(HandlerFailure){
        .spec = command,
        .handlers = handlers[0..],
    };

    const effect = runApplication(HandlerFailure, app, &.{});
    try std.testing.expect(@TypeOf(effect).RequiredServices[0] == Runner);
}

test "Cli parse releases staged owned slices on every allocation failure" {
    const Probe = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const command = CommandSpec{
                .name = "serve",
                .options = &.{.{ .name = "port", .kind = .integer }},
            };
            var parsed = try parse(allocator, command, &.{ "--port", "5178", "workspace" });
            defer parsed.deinit(allocator);
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Probe.run, .{});
}

const ServiceCliProbeApi = struct {
    pub const operations: []const []const u8 = &.{"ServiceCliProbe.observe"};
    observed: *bool,
    typed_workspace: *?[]const u8,
};

const ServiceCliProbe = fx.kernel.Service("zigeffect/std/test/ServiceCliProbe", ServiceCliProbeApi);
const ServiceCliRequirements = .{ServiceCliProbe};

test "Cli service preflight derives a bounded redacted command identity from the matched path" {
    const Handlers = struct {
        fn run(_: *fx.kernel.ContextView(ServiceCliRequirements), _: ParsedCommand) error{}!void {}
    };
    const corpus_options = [_]OptionSpec{
        .{ .name = "json", .kind = .boolean },
        .{ .name = "token", .kind = .string },
    };
    const benchmark_commands = [_]CommandSpec{
        .{ .name = "corpus", .options = corpus_options[0..] },
    };
    const commands = [_]CommandSpec{
        .{ .name = "benchmark", .subcommands = benchmark_commands[0..], .default_subcommand = "corpus" },
    };
    const spec = CommandSpec{ .name = "zgraphy", .subcommands = commands[0..] };
    const path = [_][]const u8{ "zgraphy", "benchmark", "corpus" };
    const handlers = [_]ServiceHandler(ServiceCliRequirements, error{}){
        .{ .path = path[0..], .run = Handlers.run },
    };
    const app = ServiceApplication(ServiceCliRequirements, error{}){
        .spec = spec,
        .version = "0.1.0",
        .handlers = handlers[0..],
    };

    var preflight = try preflightServiceApplication(
        ServiceCliRequirements,
        error{},
        std.testing.allocator,
        app,
        &.{ "benchmark", "corpus", "private-repository", "--token", "token=abc123", "--json" },
    );
    defer preflight.deinit();

    try std.testing.expect(preflight.shouldRun());
    const prepared = try preflight.prepare();
    try std.testing.expectEqualStrings("benchmark.corpus", prepared.identity.slice());
    try std.testing.expect(std.mem.indexOf(u8, prepared.identity.slice(), "private-repository") == null);
    try std.testing.expect(std.mem.indexOf(u8, prepared.identity.slice(), "abc123") == null);
    try std.testing.expectEqual(@as(usize, 2), prepared.identity.segmentCount());

    var default_preflight = try preflightServiceApplication(
        ServiceCliRequirements,
        error{},
        std.testing.allocator,
        app,
        &.{"benchmark"},
    );
    defer default_preflight.deinit();
    const default_prepared = try default_preflight.prepare();
    try std.testing.expectEqualStrings("benchmark.corpus", default_prepared.identity.slice());

    const too_long_segment = "1234567890123456789012345678901234567890123456789";
    const full_segment = "123456789012345678901234567890123456789012345678";
    try std.testing.expectError(error.EmptyCommandIdentity, commandIdentityFromMatchedPath(&.{}));
    try std.testing.expectError(error.EmptyCommandSegment, commandIdentityFromMatchedPath(&.{""}));
    try std.testing.expectError(error.CommandSegmentTooLong, commandIdentityFromMatchedPath(&.{too_long_segment}));
    try std.testing.expectError(error.CommandIdentityTooLong, commandIdentityFromMatchedPath(&.{ full_segment, full_segment, full_segment }));
    try std.testing.expectError(error.TooManyCommandSegments, commandIdentityFromMatchedPath(&.{ "a", "b", "c", "d", "e", "f", "g", "h", "i" }));

    var corrupted_identity = CommandIdentity{};
    corrupted_identity.len = std.math.maxInt(u8);
    corrupted_identity.segment_count = std.math.maxInt(u8);
    try std.testing.expectEqual(command_identity_max_bytes, corrupted_identity.slice().len);
    try std.testing.expectEqual(command_identity_max_segments, corrupted_identity.segmentCount());

    const long_commands = [_]CommandSpec{.{ .name = too_long_segment }};
    const long_path = [_][]const u8{ "zgraphy", too_long_segment };
    const long_handlers = [_]ServiceHandler(ServiceCliRequirements, error{}){
        .{ .path = &long_path, .run = Handlers.run },
    };
    const long_app = ServiceApplication(ServiceCliRequirements, error{}){
        .spec = .{ .name = "zgraphy", .subcommands = &long_commands },
        .handlers = &long_handlers,
    };
    try std.testing.expectError(error.CommandSegmentTooLong, preflightServiceApplication(
        ServiceCliRequirements,
        error{},
        std.testing.allocator,
        long_app,
        &.{too_long_segment},
    ));
}

test "Cli service handlers resolve parsed and typed dependencies through ContextView" {
    const Handlers = struct {
        fn parsed(ctx: *fx.kernel.ContextView(ServiceCliRequirements), command: ParsedCommand) error{}!void {
            const probe = ctx.service(ServiceCliProbe);
            probe.observed.* = std.mem.eql(u8, command.command, "status");
        }

        fn typed(ctx: *fx.kernel.ContextView(ServiceCliRequirements), args: TypedServeArgs) error{}!void {
            const probe = ctx.service(ServiceCliProbe);
            probe.observed.* = true;
            probe.typed_workspace.* = args.workspace;
        }
    };

    var observed = false;
    var typed_workspace: ?[]const u8 = null;
    const layer = fx.kernel.Layer.succeed(ServiceCliProbe, ServiceCliProbeApi{
        .observed = &observed,
        .typed_workspace = &typed_workspace,
    });
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(layer)).make(std.testing.allocator, layer, .{});
    defer runtime.deinit();

    const commands = [_]CommandSpec{.{ .name = "status" }};
    const status_path = [_][]const u8{ "zgraphy", "status" };
    const parsed_handlers = [_]ServiceHandler(ServiceCliRequirements, error{}){
        .{ .path = status_path[0..], .run = Handlers.parsed },
    };
    const parsed_app = ServiceApplication(ServiceCliRequirements, error{}){
        .spec = .{ .name = "zgraphy", .subcommands = commands[0..] },
        .handlers = parsed_handlers[0..],
    };
    var parsed_preflight = try preflightServiceApplication(
        ServiceCliRequirements,
        error{},
        std.testing.allocator,
        parsed_app,
        &.{"status"},
    );
    defer parsed_preflight.deinit();
    const parsed_effect = parsed_preflight.commandEffect();
    try std.testing.expect(@TypeOf(parsed_effect).RequiredServices[0] == ServiceCliProbe);
    try runtime.run(parsed_effect);
    try std.testing.expect(observed);

    observed = false;
    const command = typedCommand(TypedServeArgs, .{ .name = "serve", .version = "0.1.0" }, .{
        option("workspace", Schema.string().nonEmpty(), .{ .long = "workspace", .required = true }),
        option("port", Schema.integer().min(1).max(65535), .{ .long = "port", .default_value = "5178" }),
        flag("watch", .{ .long = "watch" }),
        option("mode", Schema.optional(Schema.stringEnum(&.{ "local", "ci" })), .{ .long = "mode" }),
    });
    const typed_app = ServiceTypedApplication(ServiceCliRequirements, TypedServeArgs, error{}, @TypeOf(command)){
        .command = command,
        .handler = Handlers.typed,
    };
    var typed_preflight = try preflightServiceTyped(
        ServiceCliRequirements,
        TypedServeArgs,
        error{},
        @TypeOf(command),
        std.testing.allocator,
        typed_app,
        &.{ "--workspace", "/repo" },
    );
    defer typed_preflight.deinit();
    const typed_effect = typed_preflight.commandEffect();
    try std.testing.expect(@TypeOf(typed_effect).RequiredServices[0] == ServiceCliProbe);
    try runtime.run(typed_effect);
    try std.testing.expect(observed);
    try std.testing.expectEqualStrings("/repo", typed_workspace.?);
}

test "Cli service preflight short circuits builtins and usage without a command effect" {
    const Handlers = struct {
        fn run(_: *fx.kernel.ContextView(ServiceCliRequirements), _: ParsedCommand) error{}!void {}

        fn typed(_: *fx.kernel.ContextView(ServiceCliRequirements), _: TypedServeArgs) error{}!void {}
    };
    const commands = [_]CommandSpec{.{ .name = "status", .description = "show repository state" }};
    const status_path = [_][]const u8{ "zgraphy", "status" };
    const handlers = [_]ServiceHandler(ServiceCliRequirements, error{}){
        .{ .path = status_path[0..], .run = Handlers.run },
    };
    const app = ServiceApplication(ServiceCliRequirements, error{}){
        .spec = .{ .name = "zgraphy", .description = "local graph", .subcommands = commands[0..] },
        .version = "0.1.0",
        .handlers = handlers[0..],
    };

    const Cases = struct {
        args: []const []const u8,
        kind: ShortCircuitKind,
        exit_code: ExitCode,
    };
    const cases = [_]Cases{
        .{ .args = &.{"--help"}, .kind = .help, .exit_code = .success },
        .{ .args = &.{"--version"}, .kind = .version, .exit_code = .success },
        .{ .args = &.{"completions"}, .kind = .completions, .exit_code = .success },
        .{ .args = &.{"missing"}, .kind = .usage, .exit_code = .usage },
    };
    for (cases) |case| {
        var preflight = try preflightServiceApplication(
            ServiceCliRequirements,
            error{},
            std.testing.allocator,
            app,
            case.args,
        );
        defer preflight.deinit();
        try std.testing.expect(!preflight.shouldRun());
        try std.testing.expectEqual(case.kind, preflight.short_circuit.?.kind);
        try std.testing.expectEqual(case.exit_code, preflight.short_circuit.?.exit_code);
        try std.testing.expect(preflight.short_circuit.?.output.len != 0);
    }

    const command = typedCommand(TypedServeArgs, .{ .name = "serve", .version = "0.1.0" }, .{
        option("workspace", Schema.string().nonEmpty(), .{ .long = "workspace", .required = true }),
        option("port", Schema.integer().min(1).max(65535), .{ .long = "port", .default_value = "5178" }),
        flag("watch", .{ .long = "watch" }),
        option("mode", Schema.optional(Schema.stringEnum(&.{ "local", "ci" })), .{ .long = "mode" }),
    });
    const typed_app = ServiceTypedApplication(ServiceCliRequirements, TypedServeArgs, error{}, @TypeOf(command)){
        .command = command,
        .handler = Handlers.typed,
    };
    const typed_cases = [_]Cases{
        .{ .args = &.{"--help"}, .kind = .help, .exit_code = .success },
        .{ .args = &.{"--version"}, .kind = .version, .exit_code = .success },
        .{ .args = &.{"completions"}, .kind = .completions, .exit_code = .success },
        .{ .args = &.{}, .kind = .usage, .exit_code = .usage },
    };
    for (typed_cases) |case| {
        var preflight = try preflightServiceTyped(
            ServiceCliRequirements,
            TypedServeArgs,
            error{},
            @TypeOf(command),
            std.testing.allocator,
            typed_app,
            case.args,
        );
        defer preflight.deinit();
        try std.testing.expect(!preflight.shouldRun());
        try std.testing.expectEqual(case.kind, preflight.short_circuit.?.kind);
        try std.testing.expectEqual(case.exit_code, preflight.short_circuit.?.exit_code);
        try std.testing.expect(preflight.short_circuit.?.output.len != 0);
    }
}

test "Cli service command effect exposes a statically missing dependency" {
    const Handlers = struct {
        fn run(_: *fx.kernel.ContextView(ServiceCliRequirements), _: ParsedCommand) error{}!void {}
    };
    const commands = [_]CommandSpec{.{ .name = "status" }};
    const path = [_][]const u8{ "zgraphy", "status" };
    const handlers = [_]ServiceHandler(ServiceCliRequirements, error{}){
        .{ .path = path[0..], .run = Handlers.run },
    };
    const app = ServiceApplication(ServiceCliRequirements, error{}){
        .spec = .{ .name = "zgraphy", .subcommands = commands[0..] },
        .handlers = handlers[0..],
    };
    var preflight = try preflightServiceApplication(
        ServiceCliRequirements,
        error{},
        std.testing.allocator,
        app,
        &.{"status"},
    );
    defer preflight.deinit();
    const effect = preflight.commandEffect();
    const missing_layer = fx.kernel.Layer.empty();
    try std.testing.expect(!fx.kernel.subset(@TypeOf(effect).RequiredServices, @TypeOf(missing_layer).OutputServices));
}
