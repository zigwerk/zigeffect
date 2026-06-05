const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const Schedule = struct {
    const Kind = union(enum) {
        fixed: Fixed,
        exponential: Exponential,
        linear: Linear,
        repeat: Repeat,
        backoff: Backoff,
        jittered_backoff: JitteredBackoff,
        fibonacci: Fibonacci,
        timeout: Timeout,
        reset: Reset,
    };

    pub const Fixed = struct {
        max_retries: usize,
        delay_ms: u64,
    };

    pub const Spaced = struct {
        max_retries: usize,
        delay_ms: u64,
    };

    pub const Duration = struct {
        max_retries: usize,
        duration_ms: u64,
    };

    pub const Exponential = struct {
        max_retries: usize,
        base_delay_ms: u64,
        max_delay_ms: u64,
    };

    pub const Linear = struct {
        max_retries: usize,
        base_delay_ms: u64,
        step_delay_ms: u64,
        max_delay_ms: u64,
    };

    pub const Repeat = struct {
        max_repeats: usize,
        delay_ms: u64,
    };

    pub const Backoff = struct {
        max_retries: usize,
        base_delay_ms: u64,
        factor: u64,
        max_delay_ms: u64,
    };

    pub const JitteredBackoff = struct {
        max_retries: usize,
        base_delay_ms: u64,
        factor: u64,
        max_delay_ms: u64,
        jitter_ms: u64,
        seed: u64 = 0,
    };

    pub const Fibonacci = struct {
        max_retries: usize,
        base_delay_ms: u64,
        max_delay_ms: u64,
    };

    pub const Timeout = struct {
        max_retries: usize,
        delay_ms: u64,
        timeout_ms: u64,
    };

    pub const Reset = struct {
        max_retries: usize,
        delay_ms: u64,
        reset_after_ms: u64,
    };

    pub const Decision = struct {
        attempt: usize,
        delay_ms: ?u64,
        continues: bool,
    };

    kind: Kind,

    pub fn fixed(options: Fixed) Schedule {
        return .{ .kind = .{ .fixed = options } };
    }

    pub fn once() Schedule {
        return fixed(.{ .max_retries = 1, .delay_ms = 0 });
    }

    pub fn recurs(max_retries: usize) Schedule {
        return fixed(.{ .max_retries = max_retries, .delay_ms = 0 });
    }

    pub fn spaced(options: Spaced) Schedule {
        return fixed(.{ .max_retries = options.max_retries, .delay_ms = options.delay_ms });
    }

    pub fn duration(options: Duration) Schedule {
        return fixed(.{ .max_retries = options.max_retries, .delay_ms = options.duration_ms });
    }

    pub fn exponential(options: Exponential) Schedule {
        return .{ .kind = .{ .exponential = options } };
    }

    pub fn linear(options: Linear) Schedule {
        return .{ .kind = .{ .linear = options } };
    }

    pub fn repeat(options: Repeat) Schedule {
        return .{ .kind = .{ .repeat = options } };
    }

    pub fn backoff(options: Backoff) Schedule {
        return .{ .kind = .{ .backoff = options } };
    }

    pub fn jitteredBackoff(options: JitteredBackoff) Schedule {
        return .{ .kind = .{ .jittered_backoff = options } };
    }

    pub fn fibonacci(options: Fibonacci) Schedule {
        return .{ .kind = .{ .fibonacci = options } };
    }

    pub fn timeout(options: Timeout) Schedule {
        return .{ .kind = .{ .timeout = options } };
    }

    pub fn reset(options: Reset) Schedule {
        return .{ .kind = .{ .reset = options } };
    }

    pub fn nextDelay(self: *Schedule, attempt: usize) ?u64 {
        return switch (self.kind) {
            .fixed => |options| if (attempt < options.max_retries) options.delay_ms else null,
            .exponential => |options| {
                if (attempt >= options.max_retries) return null;

                var delay = options.base_delay_ms;
                var exponent: usize = 0;
                while (exponent < attempt) : (exponent += 1) {
                    delay = std.math.mul(u64, delay, 2) catch options.max_delay_ms;
                    if (delay >= options.max_delay_ms) return options.max_delay_ms;
                }

                return @min(delay, options.max_delay_ms);
            },
            .linear => |options| {
                if (attempt >= options.max_retries) return null;
                const step = std.math.mul(u64, options.step_delay_ms, attempt) catch options.max_delay_ms;
                const delay = std.math.add(u64, options.base_delay_ms, step) catch options.max_delay_ms;
                return @min(delay, options.max_delay_ms);
            },
            .repeat => |options| if (attempt < options.max_repeats) options.delay_ms else null,
            .backoff => |options| {
                if (attempt >= options.max_retries) return null;
                return backoffDelay(options.base_delay_ms, options.factor, options.max_delay_ms, attempt);
            },
            .jittered_backoff => |options| {
                if (attempt >= options.max_retries) return null;
                const base = backoffDelay(options.base_delay_ms, options.factor, options.max_delay_ms, attempt);
                const jitter = deterministicJitter(options.seed, attempt, options.jitter_ms);
                const delay = std.math.add(u64, base, jitter) catch options.max_delay_ms;
                return @min(delay, options.max_delay_ms);
            },
            .fibonacci => |options| {
                if (attempt >= options.max_retries) return null;
                return fibonacciDelay(options.base_delay_ms, options.max_delay_ms, attempt);
            },
            .timeout => |options| {
                if (attempt >= options.max_retries) return null;
                const attempts_after_delay = std.math.add(usize, attempt, 1) catch return null;
                const elapsed_after_delay = std.math.mul(u64, @intCast(attempts_after_delay), options.delay_ms) catch return null;
                if (elapsed_after_delay > options.timeout_ms) return null;
                return options.delay_ms;
            },
            .reset => |options| if (attempt < options.max_retries) options.delay_ms else null,
        };
    }

    pub fn decision(self: *Schedule, attempt: usize) Decision {
        const delay_ms = self.nextDelay(attempt);
        return .{
            .attempt = attempt,
            .delay_ms = delay_ms,
            .continues = delay_ms != null,
        };
    }

    pub fn isExhausted(self: *Schedule, attempt: usize) bool {
        return self.nextDelay(attempt) == null;
    }

    pub fn maxContinuations(self: *Schedule) usize {
        return switch (self.kind) {
            .fixed => |options| options.max_retries,
            .exponential => |options| options.max_retries,
            .linear => |options| options.max_retries,
            .repeat => |options| options.max_repeats,
            .backoff => |options| options.max_retries,
            .jittered_backoff => |options| options.max_retries,
            .fibonacci => |options| options.max_retries,
            .timeout => |options| {
                var count: usize = 0;
                while (count < options.max_retries) {
                    const attempts_after_delay = std.math.add(usize, count, 1) catch return count;
                    const elapsed_after_delay = std.math.mul(u64, @intCast(attempts_after_delay), options.delay_ms) catch return count;
                    if (elapsed_after_delay > options.timeout_ms) return count;
                    count += 1;
                }
                return count;
            },
            .reset => |options| options.max_retries,
        };
    }

    pub fn resetAttempt(self: *Schedule, attempt: usize, idle_ms: u64) usize {
        return switch (self.kind) {
            .reset => |options| if (idle_ms >= options.reset_after_ms) 0 else attempt,
            else => attempt,
        };
    }

    pub fn unionNextDelay(self: *Schedule, other: *Schedule, attempt: usize) ?u64 {
        const left = self.nextDelay(attempt);
        const right = other.nextDelay(attempt);

        if (left) |left_delay| {
            if (right) |right_delay| return @min(left_delay, right_delay);
            return left_delay;
        }

        return right;
    }

    pub fn intersectionNextDelay(self: *Schedule, other: *Schedule, attempt: usize) ?u64 {
        const left = self.nextDelay(attempt) orelse return null;
        const right = other.nextDelay(attempt) orelse return null;
        return @max(left, right);
    }

    fn backoffDelay(base_delay_ms: u64, factor: u64, max_delay_ms: u64, attempt: usize) u64 {
        var delay = base_delay_ms;
        var exponent: usize = 0;
        const bounded_factor = @max(factor, 1);
        while (exponent < attempt) : (exponent += 1) {
            delay = std.math.mul(u64, delay, bounded_factor) catch max_delay_ms;
            if (delay >= max_delay_ms) return max_delay_ms;
        }
        return @min(delay, max_delay_ms);
    }

    fn deterministicJitter(seed: u64, attempt: usize, jitter_ms: u64) u64 {
        if (jitter_ms == 0) return 0;
        const mixed = seed +% (@as(u64, attempt) *% 1_103_515_245) +% 12_345;
        return mixed % (jitter_ms + 1);
    }

    fn fibonacciDelay(base_delay_ms: u64, max_delay_ms: u64, attempt: usize) u64 {
        if (attempt <= 1) return @min(base_delay_ms, max_delay_ms);

        var previous = base_delay_ms;
        var current = base_delay_ms;
        var index: usize = 2;
        while (index <= attempt) : (index += 1) {
            const next = std.math.add(u64, previous, current) catch max_delay_ms;
            previous = current;
            current = @min(next, max_delay_ms);
            if (current >= max_delay_ms) return max_delay_ms;
        }

        return current;
    }
};

pub const ScheduleProgram = struct {
    const Node = union(enum) {
        schedule: Schedule,
        union_with: struct {
            left: *const Node,
            right: *const Node,
        },
        intersection_with: struct {
            left: *const Node,
            right: *const Node,
        },
        sequence: struct {
            first: *const Node,
            second: *const Node,
        },
    };

    allocator: Allocator,
    nodes: std.ArrayList(*Node) = .empty,
    root: ?*Node = null,

    pub fn init(allocator: Allocator) ScheduleProgram {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ScheduleProgram) void {
        for (self.nodes.items) |node| {
            self.allocator.destroy(node);
        }
        self.nodes.deinit(self.allocator);
        self.root = null;
    }

    fn appendNode(self: *ScheduleProgram, node: Node) Allocator.Error!*Node {
        const owned = try self.allocator.create(Node);
        errdefer self.allocator.destroy(owned);
        owned.* = node;
        try self.nodes.append(self.allocator, owned);
        self.root = owned;
        return owned;
    }

    pub fn schedule(self: *ScheduleProgram, value: Schedule) Allocator.Error!*Node {
        return self.appendNode(.{ .schedule = value });
    }

    pub fn unionWith(self: *ScheduleProgram, left: *const Node, right: *const Node) Allocator.Error!*Node {
        return self.appendNode(.{ .union_with = .{ .left = left, .right = right } });
    }

    pub fn intersectionWith(self: *ScheduleProgram, left: *const Node, right: *const Node) Allocator.Error!*Node {
        return self.appendNode(.{ .intersection_with = .{ .left = left, .right = right } });
    }

    pub fn sequence(self: *ScheduleProgram, first: *const Node, second: *const Node) Allocator.Error!*Node {
        return self.appendNode(.{ .sequence = .{ .first = first, .second = second } });
    }

    pub fn nextDelay(self: *ScheduleProgram, attempt: usize) ?u64 {
        const node = self.root orelse return null;
        return nextDelayForNode(node, attempt);
    }

    pub fn nextDelayFor(self: *ScheduleProgram, node: *const Node, attempt: usize) ?u64 {
        _ = self;
        return nextDelayForNode(node, attempt);
    }

    pub fn decision(self: *ScheduleProgram, attempt: usize) Schedule.Decision {
        const delay_ms = self.nextDelay(attempt);
        return .{
            .attempt = attempt,
            .delay_ms = delay_ms,
            .continues = delay_ms != null,
        };
    }

    fn nextDelayForNode(node: *const Node, attempt: usize) ?u64 {
        return switch (node.*) {
            .schedule => |value| {
                var schedule_value = value;
                return schedule_value.nextDelay(attempt);
            },
            .union_with => |pair| {
                const left = nextDelayForNode(pair.left, attempt);
                const right = nextDelayForNode(pair.right, attempt);
                if (left) |left_delay| {
                    if (right) |right_delay| return @min(left_delay, right_delay);
                    return left_delay;
                }
                return right;
            },
            .intersection_with => |pair| {
                const left = nextDelayForNode(pair.left, attempt) orelse return null;
                const right = nextDelayForNode(pair.right, attempt) orelse return null;
                return @max(left, right);
            },
            .sequence => |pair| {
                const first_count = maxContinuationsForNode(pair.first);
                if (attempt < first_count) return nextDelayForNode(pair.first, attempt);
                return nextDelayForNode(pair.second, attempt - first_count);
            },
        };
    }

    fn maxContinuationsForNode(node: *const Node) usize {
        return switch (node.*) {
            .schedule => |value| {
                var schedule_value = value;
                return schedule_value.maxContinuations();
            },
            .union_with => |pair| @max(maxContinuationsForNode(pair.left), maxContinuationsForNode(pair.right)),
            .intersection_with => |pair| @min(maxContinuationsForNode(pair.left), maxContinuationsForNode(pair.right)),
            .sequence => |pair| std.math.add(
                usize,
                maxContinuationsForNode(pair.first),
                maxContinuationsForNode(pair.second),
            ) catch std.math.maxInt(usize),
        };
    }
};
