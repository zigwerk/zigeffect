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

pub const PositionalKind = enum { required, optional, repeated };

pub const PositionalSpec = struct {
    name: []const u8,
    kind: PositionalKind,
    help: []const u8 = "",
};

pub const CommandSpec = struct {
    name: []const u8,
    description: []const u8 = "",
    options: []const OptionSpec = &.{},
    positionals: []const PositionalSpec = &.{},
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
    MissingSubcommand,
    MissingPositional,
    UnexpectedPositional,
    InvalidInteger,
    // Fail-closed specification errors. A malformed CommandSpec tree is a
    // programming error and is rejected before any user token is consumed.
    InvalidPositionalOrder,
    RepeatedPositionalNotLast,
    DuplicatePositionalName,
    EmptyPositionalName,
    PositionalsWithSubcommands,
    UnknownDefaultSubcommand,
};

/// The subset of `CliError` produced by validating a `CommandSpec` tree before
/// parsing user input. These signal a malformed declaration, not bad input.
pub const SpecError = error{
    InvalidPositionalOrder,
    RepeatedPositionalNotLast,
    DuplicatePositionalName,
    EmptyPositionalName,
    PositionalsWithSubcommands,
    UnknownDefaultSubcommand,
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

    /// Indexed positional accessor. Returns null past the parsed positional
    /// count so callers can express optional arity without bounds checks.
    pub fn positional(self: ParsedCommand, index: usize) ?[]const u8 {
        if (index >= self.positionals.len) return null;
        return self.positionals[index];
    }

    pub fn positionalCount(self: ParsedCommand) usize {
        return self.positionals.len;
    }

    /// Named positional accessor resolved against the leaf command's declared
    /// positional schema. A `repeated` positional returns its first element;
    /// use `positional`/`positionals` for the remaining values.
    pub fn positionalNamed(self: ParsedCommand, active: CommandSpec, name: []const u8) ?[]const u8 {
        for (active.positionals, 0..) |spec, index| {
            if (std.mem.eql(u8, spec.name, name)) return self.positional(index);
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

pub const ServiceApplicationKind = enum { parsed, typed };

pub fn ServiceApplication(comptime Services: anytype, comptime Failure: type) type {
    return struct {
        const Self = @This();
        pub const service_application_kind = ServiceApplicationKind.parsed;
        pub const RequiredServices = Services;
        pub const FailureType = Failure;
        pub const SuccessType = void;

        spec: CommandSpec,
        version: []const u8 = "",
        help: ?[]const u8 = null,
        handlers: []const ServiceHandler(Services, Failure),

        pub fn findHandler(self: Self, parsed: ParsedCommand) ?ServiceHandler(Services, Failure) {
            for (self.handlers) |handler| {
                if (commandPathsEqual(handler.path, parsed.path)) return handler;
            }
            return null;
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
        pub const service_application_kind = ServiceApplicationKind.typed;
        pub const RequiredServices = Services;
        pub const ArgsType = Args;
        pub const FailureType = Failure;
        pub const CommandType = Command;
        pub const SuccessType = void;

        command: Command,
        handler: ServiceTypedHandler(Services, Args, Failure),
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

const TokenKind = enum { double_dash, long_option, short_option, plain };

fn classifyToken(arg: []const u8) TokenKind {
    if (std.mem.eql(u8, arg, "--")) return .double_dash;
    if (std.mem.startsWith(u8, arg, "--")) return .long_option;
    if (arg.len == 2 and arg[0] == '-') return .short_option;
    return .plain;
}

/// Validate an entire reachable `CommandSpec` tree fail-closed. A malformed
/// specification can never emit help, completions, or a parsed command; it is
/// rejected before any user token is consumed.
pub fn validateCommandTree(spec: CommandSpec) SpecError!void {
    if (spec.subcommands.len != 0 and spec.positionals.len != 0) {
        return SpecError.PositionalsWithSubcommands;
    }

    var seen_optional = false;
    var seen_repeated = false;
    for (spec.positionals, 0..) |positional_spec, index| {
        if (positional_spec.name.len == 0) return SpecError.EmptyPositionalName;
        for (spec.positionals[0..index]) |earlier| {
            if (std.mem.eql(u8, earlier.name, positional_spec.name)) {
                return SpecError.DuplicatePositionalName;
            }
        }
        if (seen_repeated) return SpecError.RepeatedPositionalNotLast;
        switch (positional_spec.kind) {
            .required => if (seen_optional) return SpecError.InvalidPositionalOrder,
            .optional => seen_optional = true,
            .repeated => seen_repeated = true,
        }
    }

    if (spec.default_subcommand) |default_name| {
        if (findSubcommand(spec, default_name) == null) return SpecError.UnknownDefaultSubcommand;
    }

    for (spec.subcommands) |subcommand| {
        try validateCommandTree(subcommand);
    }
}

fn ancestorOption(ancestors: []const CommandSpec, name: []const u8) ?OptionSpec {
    // The closest declaration (deepest matched command) wins for kind and help.
    var index = ancestors.len;
    while (index > 0) {
        index -= 1;
        if (findOption(ancestors[index], name)) |legacy_option| return legacy_option;
    }
    return null;
}

fn ancestorShortOption(ancestors: []const CommandSpec, short: u8) ?OptionSpec {
    var index = ancestors.len;
    while (index > 0) {
        index -= 1;
        if (findShortOption(ancestors[index], short)) |legacy_option| return legacy_option;
    }
    return null;
}

fn validatePositionalArity(active: CommandSpec, count: usize) CliError!void {
    var required: usize = 0;
    var optional: usize = 0;
    var has_repeated = false;
    for (active.positionals) |positional_spec| switch (positional_spec.kind) {
        .required => required += 1,
        .optional => optional += 1,
        .repeated => has_repeated = true,
    };
    if (count < required) return CliError.MissingPositional;
    if (!has_repeated and count > required + optional) return CliError.UnexpectedPositional;
}

pub fn parse(
    allocator: std.mem.Allocator,
    spec: CommandSpec,
    args: []const []const u8,
) !ParsedCommand {
    try validateCommandTree(spec);

    var active = spec;
    var path = std.ArrayList([]const u8).empty;
    errdefer path.deinit(allocator);
    try path.append(allocator, spec.name);

    // The chain of matched commands from the root to `active`. Options declared
    // on the active command or any matched ancestor are legal after descent.
    var ancestors = std.ArrayList(CommandSpec).empty;
    defer ancestors.deinit(allocator);
    try ancestors.append(allocator, spec);

    var options = std.ArrayList(ParsedOption).empty;
    errdefer options.deinit(allocator);
    var positionals = std.ArrayList([]const u8).empty;
    errdefer positionals.deinit(allocator);

    var index: usize = 0;
    while (index < args.len) {
        const arg = args[index];
        switch (classifyToken(arg)) {
            .double_dash => {
                index += 1;
                // `--` ends option/path recognition. At a group, select the
                // default child (if any) before the remaining tokens become
                // leaf positionals; a group without a default fails closed.
                if (active.subcommands.len != 0) {
                    const default_name = active.default_subcommand orelse return CliError.MissingSubcommand;
                    const child = findSubcommand(active, default_name) orelse return CliError.UnknownDefaultSubcommand;
                    active = child;
                    try path.append(allocator, child.name);
                    try ancestors.append(allocator, child);
                }
                while (index < args.len) : (index += 1) {
                    try positionals.append(allocator, args[index]);
                }
                break;
            },
            .long_option => {
                const raw = arg[2..];
                const equals = std.mem.indexOfScalar(u8, raw, '=');
                const name = if (equals) |eq| raw[0..eq] else raw;
                const legacy_option = ancestorOption(ancestors.items, name) orelse return CliError.UnknownOption;
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
                index += 1;
            },
            .short_option => {
                const legacy_option = ancestorShortOption(ancestors.items, arg[1]) orelse return CliError.UnknownOption;
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
                index += 1;
            },
            .plain => {
                if (active.subcommands.len != 0) {
                    const child = findSubcommand(active, arg) orelse return CliError.UnknownSubcommand;
                    active = child;
                    try path.append(allocator, child.name);
                    try ancestors.append(allocator, child);
                    index += 1;
                } else {
                    try positionals.append(allocator, arg);
                    index += 1;
                }
            },
        }
    }

    // Input ended without an explicit leaf. Executable parsing selects the
    // default child; a group without a default fails closed.
    if (active.subcommands.len != 0) {
        const default_name = active.default_subcommand orelse return CliError.MissingSubcommand;
        const child = findSubcommand(active, default_name) orelse return CliError.UnknownDefaultSubcommand;
        active = child;
        try path.append(allocator, child.name);
        try ancestors.append(allocator, child);
    }

    for (active.options) |legacy_option| {
        if (legacy_option.required and !hasParsedOption(options.items, legacy_option.name) and !optionHasDefaultSource(legacy_option)) {
            return CliError.MissingRequiredOption;
        }
    }

    try validatePositionalArity(active, positionals.items.len);

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
        try output.print(allocator, "Usage: {s} [options]", .{spec.name});
    } else {
        try output.print(allocator, "Usage: {s} [command] [options]", .{spec.name});
    }
    for (spec.positionals) |positional_spec| {
        try appendPositionalUsage(&output, allocator, positional_spec);
    }
    try output.append(allocator, '\n');
    if (spec.description.len != 0) {
        try output.print(allocator, "\n{s}\n", .{spec.description});
    }
    if (spec.positionals.len != 0) {
        try output.appendSlice(allocator, "\nArguments:\n");
        for (spec.positionals) |positional_spec| {
            try output.print(allocator, "  {s}", .{positional_spec.name});
            try appendSpaces(&output, allocator, 2);
            try output.print(allocator, "{s}\n", .{positional_spec.help});
        }
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

    for (active.positionals) |positional_spec| {
        try output.print(allocator, "positional {s} {s}", .{ @tagName(positional_spec.kind), positional_spec.name });
        if (positional_spec.help.len != 0) {
            try output.print(allocator, " {s}", .{positional_spec.help});
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

pub const BuiltinMatch = struct {
    request: BuiltinRequest,
    /// Explicit subcommand names (excluding the root) that establish the help
    /// or completion context. Empty means the root command.
    command_path: []const []const u8 = &.{},
};

/// Detect a builtin request using the same option/value/`--` consumer as
/// command parsing. `--help`/`-h` consumed as an option value, or appearing
/// after `--`, is data — not a help request.
pub fn detectBuiltinRequest(spec: CommandSpec, argv: []const []const u8) ?BuiltinMatch {
    if (argv.len == 0) return .{ .request = .help };

    if (std.mem.eql(u8, argv[0], "help")) {
        if (argv.len == 1 or (argv.len == 2 and std.mem.eql(u8, argv[1], spec.name))) {
            return .{ .request = .help };
        }
        return .{ .request = .help, .command_path = argv[1..] };
    }
    if (std.mem.eql(u8, argv[0], "completions")) {
        return .{ .request = .completions, .command_path = argv[1..] };
    }
    if (argv.len == 1 and std.mem.eql(u8, argv[0], "--version")) {
        return .{ .request = .version };
    }

    // Walk the command line, consuming options atomically and descending
    // explicit subcommands, so a `--help`/`-h` that is really an option value
    // or a post-`--` positional is never mistaken for a help request.
    var active = spec;
    var explicit_end: usize = 0;
    var index: usize = 0;
    while (index < argv.len) {
        const arg = argv[index];
        switch (classifyToken(arg)) {
            .double_dash => return null,
            .long_option => {
                if (std.mem.eql(u8, arg, "--help")) {
                    return .{ .request = .help, .command_path = argv[0..explicit_end] };
                }
                const raw = arg[2..];
                const equals = std.mem.indexOfScalar(u8, raw, '=');
                const name = if (equals) |eq| raw[0..eq] else raw;
                const legacy_option = findOption(active, name);
                index += 1;
                if (legacy_option) |resolved| {
                    if (resolved.kind != .boolean and equals == null) index += 1;
                }
            },
            .short_option => {
                if (arg[1] == 'h') {
                    return .{ .request = .help, .command_path = argv[0..explicit_end] };
                }
                const legacy_option = findShortOption(active, arg[1]);
                index += 1;
                if (legacy_option) |resolved| {
                    if (resolved.kind != .boolean) index += 1;
                }
            },
            .plain => {
                if (active.subcommands.len == 0) return null;
                const child = findSubcommand(active, arg) orelse return null;
                active = child;
                index += 1;
                explicit_end = index;
            },
        }
    }
    return null;
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
        CliError.MissingSubcommand,
        CliError.MissingPositional,
        CliError.UnexpectedPositional,
        CliError.InvalidInteger,
        => .usage,
        CliError.InvalidPositionalOrder,
        CliError.RepeatedPositionalNotLast,
        CliError.DuplicatePositionalName,
        CliError.EmptyPositionalName,
        CliError.PositionalsWithSubcommands,
        CliError.UnknownDefaultSubcommand,
        => .defect,
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

fn appendPositionalUsage(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    positional_spec: PositionalSpec,
) std.mem.Allocator.Error!void {
    switch (positional_spec.kind) {
        .required => try output.print(allocator, " <{s}>", .{positional_spec.name}),
        .optional => try output.print(allocator, " [{s}]", .{positional_spec.name}),
        .repeated => try output.print(allocator, " [{s}...]", .{positional_spec.name}),
    }
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
        .positionals = &.{
            .{ .name = "extra", .kind = .optional },
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
        .{ .name = "hello", .positionals = &.{.{ .name = "target", .kind = .optional }} },
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
        .positionals = &.{.{ .name = "item", .kind = .optional }},
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
        .{ .name = "status", .positionals = &.{.{ .name = "repo", .kind = .optional }} },
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
                .positionals = &.{.{ .name = "workspace", .kind = .optional }},
            };
            var parsed = try parse(allocator, command, &.{ "--port", "5178", "workspace" });
            defer parsed.deinit(allocator);
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Probe.run, .{});
}

test "Cli service applications expose declarative requirements without command identity state" {
    const Parsed = ServiceApplication(.{}, error{});
    try std.testing.expectEqual(ServiceApplicationKind.parsed, Parsed.service_application_kind);
    try std.testing.expect(Parsed.SuccessType == void);
    try std.testing.expect(!@hasField(Parsed, "identity"));
    try std.testing.expect(!@hasField(Parsed, "parsed"));
    try std.testing.expect(!@hasField(Parsed, "sealed_command"));
}

// ---------------------------------------------------------------------------
// Declarative positional grammar (Ticket 01)
// ---------------------------------------------------------------------------

const grammar_leaf_options = [_]OptionSpec{
    .{ .name = "json", .kind = .boolean },
    .{ .name = "root", .kind = .string },
    .{ .name = "count", .kind = .integer },
    .{ .name = "verbose", .kind = .string },
};

const grammar_group_options = [_]OptionSpec{
    .{ .name = "json", .kind = .boolean },
    .{ .name = "root", .kind = .string },
    .{ .name = "trace", .kind = .boolean },
    .{ .name = "verbose", .kind = .boolean },
};

const grammar_lexical_positionals = [_]PositionalSpec{
    .{ .name = "fixture-id", .kind = .required },
    .{ .name = "fixture-root", .kind = .optional },
};

const grammar_files_positionals = [_]PositionalSpec{
    .{ .name = "path", .kind = .repeated },
};

const grammar_benchmark_subcommands = [_]CommandSpec{
    .{ .name = "corpus", .options = &grammar_leaf_options },
    .{ .name = "lexical", .options = &grammar_leaf_options, .positionals = &grammar_lexical_positionals },
    .{ .name = "files", .options = &grammar_leaf_options, .positionals = &grammar_files_positionals },
};

const grammar_top_subcommands = [_]CommandSpec{
    .{ .name = "benchmark", .options = &grammar_group_options, .subcommands = &grammar_benchmark_subcommands, .default_subcommand = "corpus" },
    .{ .name = "status", .options = &grammar_leaf_options },
    .{ .name = "pin", .options = &grammar_leaf_options, .positionals = &.{.{ .name = "generation", .kind = .required }} },
};

const grammar_spec = CommandSpec{
    .name = "zg",
    .subcommands = &grammar_top_subcommands,
};

test "Cli validates the command spec tree fail closed before consuming input" {
    try validateCommandTree(grammar_spec);

    try std.testing.expectError(SpecError.InvalidPositionalOrder, validateCommandTree(.{
        .name = "c",
        .positionals = &.{ .{ .name = "a", .kind = .optional }, .{ .name = "b", .kind = .required } },
    }));
    try std.testing.expectError(SpecError.RepeatedPositionalNotLast, validateCommandTree(.{
        .name = "c",
        .positionals = &.{ .{ .name = "a", .kind = .repeated }, .{ .name = "b", .kind = .repeated } },
    }));
    try std.testing.expectError(SpecError.RepeatedPositionalNotLast, validateCommandTree(.{
        .name = "c",
        .positionals = &.{ .{ .name = "a", .kind = .repeated }, .{ .name = "b", .kind = .optional } },
    }));
    try std.testing.expectError(SpecError.EmptyPositionalName, validateCommandTree(.{
        .name = "c",
        .positionals = &.{.{ .name = "", .kind = .required }},
    }));
    try std.testing.expectError(SpecError.DuplicatePositionalName, validateCommandTree(.{
        .name = "c",
        .positionals = &.{ .{ .name = "a", .kind = .required }, .{ .name = "a", .kind = .optional } },
    }));
    try std.testing.expectError(SpecError.PositionalsWithSubcommands, validateCommandTree(.{
        .name = "c",
        .positionals = &.{.{ .name = "a", .kind = .optional }},
        .subcommands = &.{.{ .name = "x" }},
    }));
    try std.testing.expectError(SpecError.UnknownDefaultSubcommand, validateCommandTree(.{
        .name = "c",
        .subcommands = &.{.{ .name = "x" }},
        .default_subcommand = "y",
    }));
    // A malformed nested command is caught during recursive validation.
    try std.testing.expectError(SpecError.EmptyPositionalName, validateCommandTree(.{
        .name = "c",
        .subcommands = &.{.{ .name = "x", .positionals = &.{.{ .name = "", .kind = .required }} }},
    }));
    // parse refuses a malformed spec before touching user input.
    try std.testing.expectError(SpecError.PositionalsWithSubcommands, parse(std.testing.allocator, .{
        .name = "c",
        .positionals = &.{.{ .name = "a", .kind = .optional }},
        .subcommands = &.{.{ .name = "x" }},
    }, &.{}));
}

test "Cli treats an empty positional schema as exactly zero positionals" {
    try std.testing.expectError(
        CliError.UnexpectedPositional,
        parse(std.testing.allocator, .{ .name = "status" }, &.{"extra"}),
    );

    var parsed = try parse(std.testing.allocator, .{ .name = "status" }, &.{});
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), parsed.positionalCount());
}

test "Cli enforces required optional and repeated positional arity" {
    const lexical = CommandSpec{ .name = "lexical", .positionals = &grammar_lexical_positionals };
    const files = CommandSpec{ .name = "files", .positionals = &grammar_files_positionals };

    try std.testing.expectError(CliError.MissingPositional, parse(std.testing.allocator, lexical, &.{}));

    {
        var parsed = try parse(std.testing.allocator, lexical, &.{"fx"});
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("fx", parsed.positional(0).?);
        try std.testing.expect(parsed.positional(1) == null);
        try std.testing.expectEqualStrings("fx", parsed.positionalNamed(lexical, "fixture-id").?);
    }
    {
        var parsed = try parse(std.testing.allocator, lexical, &.{ "fx", "root" });
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("root", parsed.positionalNamed(lexical, "fixture-root").?);
    }

    try std.testing.expectError(CliError.UnexpectedPositional, parse(std.testing.allocator, lexical, &.{ "a", "b", "c" }));

    {
        var parsed = try parse(std.testing.allocator, files, &.{ "a", "b", "c" });
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 3), parsed.positionalCount());
    }
    {
        var parsed = try parse(std.testing.allocator, files, &.{});
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), parsed.positionalCount());
    }
}

test "Cli accepts options before between and after explicit subcommands" {
    const forms = [_][]const []const u8{
        &.{ "benchmark", "--json", "lexical", "fx" },
        &.{ "benchmark", "lexical", "--json", "fx" },
        &.{ "benchmark", "lexical", "fx", "--json" },
    };
    for (forms) |form| {
        var parsed = try parse(std.testing.allocator, grammar_spec, form);
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 3), parsed.path.len);
        try std.testing.expectEqualStrings("zg", parsed.path[0]);
        try std.testing.expectEqualStrings("benchmark", parsed.path[1]);
        try std.testing.expectEqualStrings("lexical", parsed.path[2]);
        try std.testing.expectEqualStrings("fx", parsed.positional(0).?);
        try std.testing.expectEqualStrings("true", parsed.optionValue("json").?);
    }
}

test "Cli consumes an option value equal to a subcommand name atomically" {
    var parsed = try parse(std.testing.allocator, grammar_spec, &.{ "benchmark", "--root", "lexical" });
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("lexical", parsed.optionValue("root").?);
    try std.testing.expectEqualStrings("corpus", parsed.command);
    try std.testing.expectEqual(@as(usize, 3), parsed.path.len);
    try std.testing.expectEqualStrings("corpus", parsed.path[2]);
}

test "Cli treats tokens after -- as positionals and selects defaults at groups" {
    {
        var parsed = try parse(std.testing.allocator, grammar_spec, &.{ "benchmark", "lexical", "--", "--json" });
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("lexical", parsed.command);
        try std.testing.expectEqualStrings("--json", parsed.positional(0).?);
        try std.testing.expect(parsed.optionValue("json") == null);
    }
    // A `--` at a group with a default selects it, then slurps positionals.
    {
        const group = CommandSpec{
            .name = "zg2",
            .subcommands = &.{.{ .name = "files", .positionals = &grammar_files_positionals }},
            .default_subcommand = "files",
        };
        var parsed = try parse(std.testing.allocator, group, &.{ "--", "a", "b" });
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("files", parsed.command);
        try std.testing.expectEqual(@as(usize, 2), parsed.positionalCount());
    }
    // The default leaf still validates arity on the slurped positionals.
    try std.testing.expectError(
        CliError.UnexpectedPositional,
        parse(std.testing.allocator, grammar_spec, &.{ "benchmark", "--", "x" }),
    );
}

test "Cli keeps first occurrence but validates every duplicate option" {
    var parsed = try parse(std.testing.allocator, grammar_spec, &.{ "status", "--root", "a", "--root", "b" });
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("a", parsed.optionValue("root").?);

    try std.testing.expectError(
        CliError.InvalidInteger,
        parse(std.testing.allocator, grammar_spec, &.{ "status", "--count", "1", "--count", "nope" }),
    );
}

test "Cli selects the default child only without an explicit leaf" {
    {
        var parsed = try parse(std.testing.allocator, grammar_spec, &.{"benchmark"});
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("corpus", parsed.command);
    }
    {
        var parsed = try parse(std.testing.allocator, grammar_spec, &.{ "benchmark", "lexical", "fx" });
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("lexical", parsed.command);
    }
}

test "Cli fails closed at a group without an explicit or default child" {
    const group = CommandSpec{ .name = "zg3", .subcommands = &.{.{ .name = "x" }} };
    try std.testing.expectError(CliError.MissingSubcommand, parse(std.testing.allocator, group, &.{}));
    try std.testing.expectError(CliError.MissingSubcommand, parse(std.testing.allocator, group, &.{"--"}));
    try std.testing.expectError(CliError.UnknownSubcommand, parse(std.testing.allocator, group, &.{"nope"}));
}

test "Cli resolves ancestor options after descent with the closest declaration winning" {
    {
        var parsed = try parse(std.testing.allocator, grammar_spec, &.{ "benchmark", "lexical", "fx", "--trace" });
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("true", parsed.optionValue("trace").?);
    }
    {
        // `verbose` is boolean on the group but string on the leaf; the leaf wins.
        var parsed = try parse(std.testing.allocator, grammar_spec, &.{ "benchmark", "lexical", "fx", "--verbose", "loud" });
        defer parsed.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("loud", parsed.optionValue("verbose").?);
    }
    // An option not declared on the current (root) command is illegal before a child.
    try std.testing.expectError(
        CliError.UnknownOption,
        parse(std.testing.allocator, grammar_spec, &.{ "--json", "status" }),
    );
}

test "Cli builtin detection shares the option value and delimiter consumer" {
    try std.testing.expectEqual(BuiltinRequest.help, detectBuiltinRequest(grammar_spec, &.{}).?.request);
    try std.testing.expectEqual(BuiltinRequest.help, detectBuiltinRequest(grammar_spec, &.{"--help"}).?.request);
    try std.testing.expectEqual(BuiltinRequest.version, detectBuiltinRequest(grammar_spec, &.{"--version"}).?.request);
    try std.testing.expectEqual(BuiltinRequest.completions, detectBuiltinRequest(grammar_spec, &.{"completions"}).?.request);

    {
        const match = detectBuiltinRequest(grammar_spec, &.{ "benchmark", "--help" }).?;
        try std.testing.expectEqual(BuiltinRequest.help, match.request);
        try std.testing.expectEqual(@as(usize, 1), match.command_path.len);
        try std.testing.expectEqualStrings("benchmark", match.command_path[0]);
    }
    {
        const match = detectBuiltinRequest(grammar_spec, &.{ "help", "benchmark" }).?;
        try std.testing.expectEqualStrings("benchmark", match.command_path[0]);
    }

    // `--help` consumed as an option value or after `--` is data, not a request.
    try std.testing.expect(detectBuiltinRequest(grammar_spec, &.{ "benchmark", "--root", "--help" }) == null);
    try std.testing.expect(detectBuiltinRequest(grammar_spec, &.{ "benchmark", "--", "--help" }) == null);
    try std.testing.expectEqual(BuiltinRequest.help, detectBuiltinRequest(grammar_spec, &.{ "benchmark", "-h" }).?.request);
}

test "Cli help and completions render declared positionals" {
    const lexical = CommandSpec{
        .name = "lexical",
        .description = "run a lexical benchmark",
        .options = &.{.{ .name = "json", .kind = .boolean, .help = "json output" }},
        .positionals = &grammar_lexical_positionals,
    };

    const help = try formatHelp(std.testing.allocator, lexical);
    defer std.testing.allocator.free(help);
    try std.testing.expect(std.mem.indexOf(u8, help, "Usage: lexical [options] <fixture-id> [fixture-root]") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "Arguments:") != null);
    try std.testing.expect(std.mem.indexOf(u8, help, "fixture-id") != null);

    const completions = try formatCompletions(std.testing.allocator, lexical, &.{});
    defer std.testing.allocator.free(completions);
    try std.testing.expect(std.mem.indexOf(u8, completions, "positional required fixture-id") != null);
    try std.testing.expect(std.mem.indexOf(u8, completions, "positional optional fixture-root") != null);
}
