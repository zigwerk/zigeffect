const std = @import("std");

pub const OptionKind = enum {
    string,
    boolean,
};

pub const OptionSpec = struct {
    name: []const u8,
    short: ?u8 = null,
    kind: OptionKind = .string,
    required: bool = false,
    help: []const u8 = "",
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
};

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

    if (args.len > 0 and args[0].len > 0 and args[0][0] != '-') {
        if (findSubcommand(spec, args[0])) |subcommand| {
            active = subcommand;
            consumed = 1;
            try path.append(allocator, subcommand.name);
        } else if (spec.subcommands.len > 0) {
            return CliError.UnknownSubcommand;
        }
    }

    var options = std.ArrayList(ParsedOption).empty;
    errdefer options.deinit(allocator);
    var positionals = std.ArrayList([]const u8).empty;
    errdefer positionals.deinit(allocator);

    var index = consumed;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.startsWith(u8, arg, "--")) {
            const raw = arg[2..];
            const equals = std.mem.indexOfScalar(u8, raw, '=');
            const name = if (equals) |eq| raw[0..eq] else raw;
            const option = findOption(active, name) orelse return CliError.UnknownOption;
            const value: ?[]const u8 = switch (option.kind) {
                .boolean => "true",
                .string => blk: {
                    if (equals) |eq| break :blk raw[eq + 1 ..];
                    if (index + 1 >= args.len) return CliError.MissingOptionValue;
                    index += 1;
                    break :blk args[index];
                },
            };
            try options.append(allocator, .{ .name = option.name, .value = value });
        } else {
            try positionals.append(allocator, arg);
        }
    }

    for (active.options) |option| {
        if (option.required and !hasParsedOption(options.items, option.name)) {
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

pub fn formatHelp(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "Usage: {s} [options]\n", .{spec.name});
    if (spec.description.len != 0) {
        try output.print(allocator, "\n{s}\n", .{spec.description});
    }
    if (spec.options.len != 0) {
        try output.appendSlice(allocator, "\nOptions:\n");
        for (spec.options) |option| {
            switch (option.kind) {
                .string => try output.print(allocator, "  --{s} <value>  {s}\n", .{ option.name, option.help }),
                .boolean => try output.print(allocator, "  --{s}       {s}\n", .{ option.name, option.help }),
            }
        }
    }
    return output.toOwnedSlice(allocator);
}

pub fn formatRunReceiptJson(allocator: std.mem.Allocator, receipt: CliRunReceipt) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringField(allocator, &output, "  ", "schema", receipt.schema, true);
    try appendJsonStringField(allocator, &output, "  ", "command", receipt.command, true);
    try appendJsonStringField(allocator, &output, "  ", "status", receipt.status, true);
    try output.appendSlice(allocator, "  \"facts\": [\n");
    for (receipt.facts, 0..) |fact, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringField(allocator, &output, "      ", "kind", fact.kind, true);
        try appendJsonStringField(allocator, &output, "      ", "detail", fact.detail, false);
        try output.appendSlice(allocator, "    }");
        if (index + 1 != receipt.facts.len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "  ]\n");
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
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

fn hasParsedOption(options: []const ParsedOption, name: []const u8) bool {
    for (options) |option| {
        if (std.mem.eql(u8, option.name, name)) return true;
    }
    return false;
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
