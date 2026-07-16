const std = @import("std");
const clock_mod = @import("../services/clock.zig");
const tracing_mod = @import("../services/tracing.zig");

pub const Allocator = std.mem.Allocator;
pub const Clock = clock_mod.Clock;

/// A runtime reference for raw configuration. Implementations return
/// caller-owned bytes so values can safely cross provider boundaries.
pub const ConfigProvider = struct {
    state: ?*anyopaque = null,
    get_alloc_fn: *const fn (?*anyopaque, Allocator, []const u8) anyerror![]u8,

    pub fn from(comptime Implementation: type, implementation: *Implementation) ConfigProvider {
        return .{
            .state = implementation,
            .get_alloc_fn = struct {
                fn call(raw: ?*anyopaque, allocator: Allocator, key: []const u8) anyerror![]u8 {
                    const typed: *Implementation = @ptrCast(@alignCast(raw.?));
                    return typed.getAlloc(allocator, key);
                }
            }.call,
        };
    }

    pub fn empty() ConfigProvider {
        return .{ .get_alloc_fn = struct {
            fn call(_: ?*anyopaque, _: Allocator, _: []const u8) anyerror![]u8 {
                return error.MissingConfig;
            }
        }.call };
    }

    pub fn getAlloc(self: ConfigProvider, allocator: Allocator, key: []const u8) anyerror![]u8 {
        return self.get_alloc_fn(self.state, allocator, key);
    }
};

pub const Console = struct {
    state: ?*anyopaque = null,
    write_out_fn: *const fn (?*anyopaque, []const u8) anyerror!void,
    write_err_fn: *const fn (?*anyopaque, []const u8) anyerror!void,

    pub fn from(comptime Implementation: type, implementation: *Implementation) Console {
        return .{
            .state = implementation,
            .write_out_fn = struct {
                fn call(raw: ?*anyopaque, text: []const u8) anyerror!void {
                    const typed: *Implementation = @ptrCast(@alignCast(raw.?));
                    return typed.writeOut(text);
                }
            }.call,
            .write_err_fn = struct {
                fn call(raw: ?*anyopaque, text: []const u8) anyerror!void {
                    const typed: *Implementation = @ptrCast(@alignCast(raw.?));
                    return typed.writeErr(text);
                }
            }.call,
        };
    }

    pub fn discard() Console {
        const Discard = struct {
            fn write(_: ?*anyopaque, _: []const u8) anyerror!void {}
        };
        return .{
            .write_out_fn = Discard.write,
            .write_err_fn = Discard.write,
        };
    }

    pub fn writeOut(self: Console, text: []const u8) anyerror!void {
        return self.write_out_fn(self.state, text);
    }

    pub fn writeErr(self: Console, text: []const u8) anyerror!void {
        return self.write_err_fn(self.state, text);
    }
};

pub const Random = struct {
    state: ?*anyopaque = null,
    fill_fn: *const fn (?*anyopaque, []u8) void,

    pub fn from(comptime Implementation: type, implementation: *Implementation) Random {
        return .{
            .state = implementation,
            .fill_fn = struct {
                fn call(raw: ?*anyopaque, output: []u8) void {
                    const typed: *Implementation = @ptrCast(@alignCast(raw.?));
                    typed.fill(output);
                }
            }.call,
        };
    }

    pub fn fill(self: Random, output: []u8) void {
        self.fill_fn(self.state, output);
    }

    pub fn integer(self: Random, comptime T: type) T {
        var value: T = undefined;
        self.fill(std.mem.asBytes(&value));
        return value;
    }
};

pub const Tracer = struct {
    state: ?*anyopaque = null,
    start_span_fn: *const fn (?*anyopaque, []const u8, ?u64) anyerror!u64,
    end_span_fn: *const fn (?*anyopaque, u64) anyerror!void,

    pub fn from(comptime Implementation: type, implementation: *Implementation) Tracer {
        return .{
            .state = implementation,
            .start_span_fn = struct {
                fn call(raw: ?*anyopaque, name: []const u8, parent_id: ?u64) anyerror!u64 {
                    const typed: *Implementation = @ptrCast(@alignCast(raw.?));
                    return typed.startSpan(name, parent_id);
                }
            }.call,
            .end_span_fn = struct {
                fn call(raw: ?*anyopaque, span_id: u64) anyerror!void {
                    const typed: *Implementation = @ptrCast(@alignCast(raw.?));
                    return typed.endSpan(span_id);
                }
            }.call,
        };
    }

    pub fn startSpan(self: Tracer, name: []const u8, parent_id: ?u64) anyerror!u64 {
        return self.start_span_fn(self.state, name, parent_id);
    }

    pub fn endSpan(self: Tracer, span_id: u64) anyerror!void {
        return self.end_span_fn(self.state, span_id);
    }
};

pub const DefaultServices = struct {
    clock: *Clock,
    config_provider: ConfigProvider,
    console: Console,
    random: Random,
    tracer: Tracer,
};

pub const DefaultOverrides = struct {
    clock: ?*Clock = null,
    config_provider: ?ConfigProvider = null,
    console: ?Console = null,
    random: ?Random = null,
    tracer: ?Tracer = null,

    pub fn overlay(self: DefaultOverrides, next: DefaultOverrides) DefaultOverrides {
        return .{
            .clock = next.clock orelse self.clock,
            .config_provider = next.config_provider orelse self.config_provider,
            .console = next.console orelse self.console,
            .random = next.random orelse self.random,
            .tracer = next.tracer orelse self.tracer,
        };
    }
};

const DefaultRandom = struct {
    generator: std.Random.DefaultPrng,
    mutex: std.atomic.Mutex = .unlocked,

    fn init(seed: u64) DefaultRandom {
        return .{ .generator = .init(seed) };
    }

    fn fill(self: *DefaultRandom, output: []u8) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
        defer self.mutex.unlock();
        self.generator.random().bytes(output);
    }
};

/// Fallback defaults keep the reference set total in tests and embedders that
/// do not have a process boundary. Production roots replace console, config,
/// and random with platform-backed references built from std.process.Init.
pub const OwnedDefaults = struct {
    clock: Clock,
    random_state: DefaultRandom,
    tracing_state: tracing_mod.Tracing,

    pub fn init(allocator: Allocator) OwnedDefaults {
        const clock = Clock.system();
        return .{
            .clock = clock,
            .random_state = DefaultRandom.init(clock.nowMs()),
            .tracing_state = tracing_mod.Tracing.init(allocator),
        };
    }

    pub fn deinit(self: *OwnedDefaults) void {
        self.tracing_state.deinit();
    }

    pub fn services(self: *OwnedDefaults) DefaultServices {
        return .{
            .clock = &self.clock,
            .config_provider = ConfigProvider.empty(),
            .console = Console.discard(),
            .random = Random.from(DefaultRandom, &self.random_state),
            .tracer = Tracer.from(tracing_mod.Tracing, &self.tracing_state),
        };
    }
};
