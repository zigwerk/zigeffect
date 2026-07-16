const std = @import("std");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const service_key = "zigeffect/default/Console";
pub const ConsoleError = error{WriteFailed};

pub const Service = struct {
    pointer: *anyopaque,
    write_out_fn: *const fn (*anyopaque, []const u8) anyerror!void,
    write_err_fn: *const fn (*anyopaque, []const u8) anyerror!void,

    pub fn from(comptime Implementation: type, implementation: *Implementation) Service {
        return .{
            .pointer = implementation,
            .write_out_fn = struct {
                fn call(raw: *anyopaque, text: []const u8) anyerror!void {
                    return (@as(*Implementation, @ptrCast(@alignCast(raw)))).writeOut(text);
                }
            }.call,
            .write_err_fn = struct {
                fn call(raw: *anyopaque, text: []const u8) anyerror!void {
                    return (@as(*Implementation, @ptrCast(@alignCast(raw)))).writeErr(text);
                }
            }.call,
        };
    }

    pub fn writeOut(self: Service, text: []const u8) !void {
        return self.write_out_fn(self.pointer, text);
    }
    pub fn writeErr(self: Service, text: []const u8) !void {
        return self.write_err_fn(self.pointer, text);
    }
};

pub const CapturedConsole = struct {
    allocator: std.mem.Allocator,
    stdout: std.ArrayList(u8),
    stderr: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) CapturedConsole {
        return .{
            .allocator = allocator,
            .stdout = .empty,
            .stderr = .empty,
        };
    }

    pub fn deinit(self: *CapturedConsole) void {
        self.stdout.deinit(self.allocator);
        self.stderr.deinit(self.allocator);
    }

    pub fn asService(self: *CapturedConsole) Service {
        return Service.from(CapturedConsole, self);
    }

    pub fn asDefault(self: *CapturedConsole) fx.kernel.Console {
        return fx.kernel.Console.from(CapturedConsole, self);
    }

    pub fn writeOut(self: *CapturedConsole, text: []const u8) std.mem.Allocator.Error!void {
        try self.stdout.appendSlice(self.allocator, text);
    }

    pub fn writeErr(self: *CapturedConsole, text: []const u8) std.mem.Allocator.Error!void {
        try self.stderr.appendSlice(self.allocator, text);
    }

    pub fn stdoutText(self: CapturedConsole) []const u8 {
        return self.stdout.items;
    }

    pub fn stderrText(self: CapturedConsole) []const u8 {
        return self.stderr.items;
    }
};

pub const LiveConsole = struct {
    io: std.Io,

    pub fn init(io: std.Io) LiveConsole {
        return .{ .io = io };
    }
    pub fn asService(self: *LiveConsole) Service {
        return Service.from(LiveConsole, self);
    }
    pub fn asDefault(self: *LiveConsole) fx.kernel.Console {
        return fx.kernel.Console.from(LiveConsole, self);
    }
    pub fn writeOut(self: *LiveConsole, text: []const u8) !void {
        try std.Io.File.stdout().writeStreamingAll(self.io, text);
    }
    pub fn writeErr(self: *LiveConsole, text: []const u8) !void {
        try std.Io.File.stderr().writeStreamingAll(self.io, text);
    }
};

fn WriteDefaultEffect(comptime stderr: bool) type {
    _ = stderr;
    return fx.kernel.Effect(void, ConsoleError, .{}).Stateful([]const u8);
}

fn writeDefault(comptime stderr: bool, text: []const u8) WriteDefaultEffect(stderr) {
    return fx.kernel.Effect(void, ConsoleError, .{}).fromState([]const u8, text, struct {
        fn run(value: []const u8, ctx: *fx.kernel.ContextView(.{})) ConsoleError!void {
            const result = if (stderr) ctx.console().writeErr(value) else ctx.console().writeOut(value);
            result catch |failure| {
                _ = StdService.recordSemantic(
                    ctx,
                    .log_recorded,
                    service_key,
                    if (stderr) "Console.stderr" else "Console.stdout",
                    "failure",
                    @errorName(failure),
                );
                return error.WriteFailed;
            };
            _ = StdService.recordSemantic(
                ctx,
                .log_recorded,
                service_key,
                if (stderr) "Console.stderr" else "Console.stdout",
                "success",
                "wrote redacted console text",
            );
        }
    }.run);
}

pub fn writeOut(text: []const u8) WriteDefaultEffect(false) {
    return writeDefault(false, text);
}

pub fn writeErr(text: []const u8) WriteDefaultEffect(true) {
    return writeDefault(true, text);
}

test "Console captures stdout and stderr" {
    var console = CapturedConsole.init(std.testing.allocator);
    defer console.deinit();

    try console.writeOut("hello");
    try console.writeErr("oops");

    try std.testing.expectEqualStrings("hello", console.stdoutText());
    try std.testing.expectEqualStrings("oops", console.stderrText());
}

test "Console write effects use a captured default-service override" {
    var console = CapturedConsole.init(std.testing.allocator);
    defer console.deinit();
    const root = fx.kernel.Layer.empty();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    const defaults = fx.kernel.DefaultOverrides{ .console = console.asDefault() };
    try runtime.run(writeOut("hello").withDefaults(defaults));
    try runtime.run(writeErr("oops").withDefaults(defaults));
    try std.testing.expectEqualStrings("hello", console.stdoutText());
    try std.testing.expectEqualStrings("oops", console.stderrText());
}
