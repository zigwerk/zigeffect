const std = @import("std");
const Config = @import("../config/root.zig");
const Console = @import("../console/root.zig");
const Env = @import("../env/root.zig");
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

pub const CommandSpec = struct {
    name: []const u8,
    description: []const u8 = "",
    options: []const OptionSpec = &.{},
    subcommands: []const CommandSpec = &.{},
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

pub const Runner = struct {};

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
        for (self.options) |option| {
            if (std.mem.eql(u8, option.name, name)) return option.value;
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

pub fn Handler(comptime EffectEnv: type, comptime Failure: type) type {
    return struct {
        path: []const []const u8,
        run: *const fn (*fx.Context(EffectEnv), ParsedCommand) Failure!void,
    };
}

pub fn Application(comptime EffectEnv: type, comptime Failure: type) type {
    return struct {
        const Self = @This();

        spec: CommandSpec,
        handlers: []const Handler(EffectEnv, Failure),

        pub fn findHandler(self: Self, parsed: ParsedCommand) ?Handler(EffectEnv, Failure) {
            for (self.handlers) |handler| {
                if (commandPathsEqual(handler.path, parsed.path)) return handler;
            }
            return null;
        }
    };
}

pub fn RunEffect(comptime EffectEnv: type, comptime HandlerFailure: type) type {
    return struct {
        pub const SuccessType = RunSummary;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{ Runner, Console.CapturedConsole };

        app: Application(EffectEnv, HandlerFailure),
        args: []const []const u8,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!RunSummary {
            _ = ctx.service(Runner);
            const console = ctx.service(Console.CapturedConsole);
            _ = StdService.recordOperation(ctx, Runner, "cli.run", "started", self.app.spec.name);

            var parsed = parse(ctx.allocator, self.app.spec, self.args) catch |err| {
                _ = StdService.recordOperation(ctx, Runner, "cli.parse", "failure", @errorName(err));
                try writeCliError(console, "parse", err);
                return buildRunSummary(ctx.allocator, self.app.spec.name, "failure", exitCodeForError(err), &.{
                    .{ .kind = "cli_command_started", .detail = self.app.spec.name },
                    .{ .kind = "cli_parse_failed", .detail = @errorName(err) },
                });
            };
            defer parsed.deinit(ctx.allocator);

            const command_text = try formatCommandPathAlloc(ctx.allocator, parsed.path);
            defer ctx.allocator.free(command_text);

            const handler = self.app.findHandler(parsed) orelse {
                const err = CliError.UnknownSubcommand;
                _ = StdService.recordOperation(ctx, Runner, "cli.handler", "failure", @errorName(err));
                try writeCliError(console, "handler", err);
                return buildRunSummary(ctx.allocator, command_text, "failure", exitCodeForError(err), &.{
                    .{ .kind = "cli_command_started", .detail = command_text },
                    .{ .kind = "cli_handler_missing", .detail = @errorName(err) },
                });
            };

            _ = StdService.recordOperation(ctx, Runner, "cli.handler", "started", command_text);
            handler.run(ctx, parsed) catch |err| {
                _ = StdService.recordOperation(ctx, Runner, "cli.handler", "failure", @errorName(err));
                try writeCliError(console, "handler", err);
                _ = StdService.recordOperation(ctx, Runner, "cli.run", "failure", command_text);
                return buildRunSummary(ctx.allocator, command_text, "failure", exitCodeForError(err), &.{
                    .{ .kind = "cli_command_started", .detail = command_text },
                    .{ .kind = "cli_handler_failed", .detail = @errorName(err) },
                    .{ .kind = "cli_command_completed", .detail = "failure" },
                });
            };

            _ = StdService.recordOperation(ctx, Runner, "cli.handler", "success", command_text);
            _ = StdService.recordOperation(ctx, Runner, "cli.run", "success", command_text);
            return buildRunSummary(ctx.allocator, command_text, "success", .success, &.{
                .{ .kind = "cli_command_started", .detail = command_text },
                .{ .kind = "cli_handler_completed", .detail = "success" },
                .{ .kind = "cli_command_completed", .detail = "success" },
            });
        }
    };
}

pub fn runEffect(
    comptime EffectEnv: type,
    comptime HandlerFailure: type,
    app: Application(EffectEnv, HandlerFailure),
    args: []const []const u8,
) RunEffect(EffectEnv, HandlerFailure) {
    return .{ .app = app, .args = args };
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
            const option = findOption(active, name) orelse return CliError.UnknownOption;
            const value: ?[]const u8 = switch (option.kind) {
                .boolean => "true",
                .string, .integer => blk: {
                    if (equals) |eq| break :blk raw[eq + 1 ..];
                    if (index + 1 >= args.len) return CliError.MissingOptionValue;
                    index += 1;
                    break :blk args[index];
                },
            };
            try validateOptionValue(option, value);
            try options.append(allocator, .{ .name = option.name, .value = value });
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len == 2) {
            const option = findShortOption(active, arg[1]) orelse return CliError.UnknownOption;
            const value: ?[]const u8 = switch (option.kind) {
                .boolean => "true",
                .string, .integer => blk: {
                    if (index + 1 >= args.len) return CliError.MissingOptionValue;
                    index += 1;
                    break :blk args[index];
                },
            };
            try validateOptionValue(option, value);
            try options.append(allocator, .{ .name = option.name, .value = value });
        } else {
            try positionals.append(allocator, arg);
        }
    }

    for (active.options) |option| {
        if (option.required and !hasParsedOption(options.items, option.name) and !optionHasDefaultSource(option)) {
            return CliError.MissingRequiredOption;
        }
    }

    return .{
        .command = active.name,
        .path = try path.toOwnedSlice(allocator),
        .options = try options.toOwnedSlice(allocator),
        .positionals = try positionals.toOwnedSlice(allocator),
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
    const option = findOption(active, name) orelse return CliError.UnknownOption;

    if (parsed.optionValue(name)) |value| {
        try validateOptionValue(option, value);
        return value;
    }

    if (option.env) |env_name| {
        if (env) |env_map| {
            if (env_map.get(env_name)) |value| {
                try validateOptionValue(option, value);
                return value;
            }
        }
    }

    if (option.config_key) |config_key| {
        if (config) |layered_config| {
            if (layered_config.get(config_key)) |value| {
                try validateOptionValue(option, value);
                return value;
            }
        }
    }

    if (option.default_value) |value| {
        try validateOptionValue(option, value);
        return value;
    }

    if (option.required) return CliError.MissingRequiredOption;
    return null;
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
        for (spec.options) |option| {
            switch (option.kind) {
                .string => try output.print(allocator, "  --{s} <value>  {s}\n", .{ option.name, option.help }),
                .integer => try output.print(allocator, "  --{s} <int>    {s}\n", .{ option.name, option.help }),
                .boolean => try output.print(allocator, "  --{s}       {s}\n", .{ option.name, option.help }),
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

    for (active.options) |option| {
        try output.print(allocator, "option --{s}", .{option.name});
        if (option.help.len != 0) {
            try output.print(allocator, " {s}", .{option.help});
        }
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

fn writeCliError(console: *Console.CapturedConsole, phase: []const u8, err: anyerror) std.mem.Allocator.Error!void {
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
    for (spec.options) |option| {
        if (std.mem.eql(u8, option.name, name)) return option;
    }
    return null;
}

fn findShortOption(spec: CommandSpec, short: u8) ?OptionSpec {
    for (spec.options) |option| {
        if (option.short != null and option.short.? == short) return option;
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

fn validateOptionValue(option: OptionSpec, value: ?[]const u8) CliError!void {
    if (option.kind == .integer) {
        _ = std.fmt.parseInt(i64, value orelse return CliError.MissingOptionValue, 10) catch {
            return CliError.InvalidInteger;
        };
    }
}

fn hasParsedOption(options: []const ParsedOption, name: []const u8) bool {
    for (options) |option| {
        if (std.mem.eql(u8, option.name, name)) return true;
    }
    return false;
}

fn optionHasDefaultSource(option: OptionSpec) bool {
    return option.default_value != null or option.env != null or option.config_key != null;
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

test "Cli runEffect executes handler through services and records receipt facts" {
    const zstd = @import("../root.zig");

    const Provider = zstd.Service.Provider(.{ Runner, zstd.Console.CapturedConsole });
    const HandlerFailure = error{Boom};
    const TestHandlers = struct {
        fn hello(ctx: *zstd.fx.Context(Provider), parsed: ParsedCommand) HandlerFailure!void {
            try std.testing.expectEqualStrings("hello", parsed.command);
            try ctx.service(zstd.Console.CapturedConsole).writeOut("hello Sean");
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
    const handlers = [_]Handler(Provider, HandlerFailure){
        .{ .path = hello_path[0..], .run = TestHandlers.hello },
    };
    const app = Application(Provider, HandlerFailure){
        .spec = command,
        .handlers = handlers[0..],
    };

    var runner = Runner{};
    var console = zstd.Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    var provider = Provider.init(.{ &runner, &console });
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(Provider).init(std.testing.allocator, &provider)
        .provides(.{ Runner, zstd.Console.CapturedConsole })
        .withCausalStore(&store);

    var summary = try runtime.run(runEffect(Provider, HandlerFailure, app, &.{"hello"}));
    defer summary.deinit(std.testing.allocator);

    try std.testing.expectEqual(ExitCode.success, summary.exit_code);
    try std.testing.expectEqualStrings("success", summary.status);
    try std.testing.expectEqualStrings("hello Sean", console.stdoutText());
    try std.testing.expect(std.mem.indexOf(u8, summary.receipt_json, "\"command\": \"zg hello\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary.receipt_json, "\"status\": \"success\"") != null);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, Runner, "cli.run", "success"));
}

test "Cli runEffect maps handler errors to exit codes without throwing" {
    const zstd = @import("../root.zig");

    const Provider = zstd.Service.Provider(.{ Runner, zstd.Console.CapturedConsole });
    const HandlerFailure = error{MissingVariable};
    const TestHandlers = struct {
        fn fail(_: *zstd.fx.Context(Provider), _: ParsedCommand) HandlerFailure!void {
            return error.MissingVariable;
        }
    };

    const command = CommandSpec{ .name = "zg" };
    const root_path = [_][]const u8{"zg"};
    const handlers = [_]Handler(Provider, HandlerFailure){
        .{ .path = root_path[0..], .run = TestHandlers.fail },
    };
    const app = Application(Provider, HandlerFailure){
        .spec = command,
        .handlers = handlers[0..],
    };

    var runner = Runner{};
    var console = zstd.Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    var provider = Provider.init(.{ &runner, &console });
    var runtime = zstd.fx.Runtime(Provider).init(std.testing.allocator, &provider)
        .provides(.{ Runner, zstd.Console.CapturedConsole });

    var summary = try runtime.run(runEffect(Provider, HandlerFailure, app, &.{}));
    defer summary.deinit(std.testing.allocator);

    try std.testing.expectEqual(ExitCode.config, summary.exit_code);
    try std.testing.expectEqualStrings("failure", summary.status);
    try std.testing.expect(std.mem.indexOf(u8, console.stderrText(), "MissingVariable") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary.receipt_json, "\"status\": \"failure\"") != null);
}

test "Cli runEffect participates in runtime dependency validation" {
    const zstd = @import("../root.zig");

    const Provider = zstd.Service.Provider(.{ Runner, zstd.Console.CapturedConsole });
    const HandlerFailure = error{Boom};
    const TestHandlers = struct {
        fn noop(_: *zstd.fx.Context(Provider), _: ParsedCommand) HandlerFailure!void {}
    };

    const command = CommandSpec{ .name = "zg" };
    const root_path = [_][]const u8{"zg"};
    const handlers = [_]Handler(Provider, HandlerFailure){
        .{ .path = root_path[0..], .run = TestHandlers.noop },
    };
    const app = Application(Provider, HandlerFailure){
        .spec = command,
        .handlers = handlers[0..],
    };

    var runner = Runner{};
    var console = zstd.Console.CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    var provider = Provider.init(.{ &runner, &console });
    var runtime = zstd.fx.Runtime(Provider).init(std.testing.allocator, &provider)
        .provides(.{Runner});

    try std.testing.expectError(
        error.MissingServiceRequirement,
        runtime.run(runEffect(Provider, HandlerFailure, app, &.{})),
    );
}
