const std = @import("std");
const Clock = @import("../clock/root.zig");
const External = @import("../external/root.zig");
const Secrets = @import("../secrets/root.zig");

pub const RetryDecision = union(enum) { retry_after_ms: u64, stop_terminal, exhausted };

pub const RetryPolicy = struct {
    max_attempts: usize = 3,
    initial_delay_ms: u64 = 25,
    multiplier: u8 = 2,
    max_delay_ms: u64 = 5000,

    pub fn validate(self: RetryPolicy) !void {
        if (self.max_attempts == 0 or self.initial_delay_ms == 0 or self.multiplier == 0 or self.max_delay_ms == 0) return error.InvalidRetryPolicy;
    }
    pub fn decide(self: RetryPolicy, failure: External.Failure, completed_attempts: usize) RetryDecision {
        if (!failure.retryable()) return .stop_terminal;
        if (completed_attempts >= self.max_attempts) return .exhausted;
        var delay = self.initial_delay_ms;
        var index: usize = 1;
        while (index < completed_attempts) : (index += 1) delay = @min(self.max_delay_ms, std.math.mul(u64, delay, self.multiplier) catch self.max_delay_ms);
        if (failure.retry_after_ms) |hint| delay = @max(delay, @min(hint, self.max_delay_ms));
        return .{ .retry_after_ms = delay };
    }
};

pub const TimeoutPolicy = struct {
    duration_ms: u64,
    pub fn validate(self: TimeoutPolicy) !void { if (self.duration_ms == 0) return error.InvalidTimeoutPolicy; }
    pub fn deadline(self: TimeoutPolicy, started_ms: u64) u64 { return std.math.add(u64, started_ms, self.duration_ms) catch std.math.maxInt(u64); }
    pub fn expired(self: TimeoutPolicy, started_ms: u64, now_ms: u64) bool { return now_ms >= self.deadline(started_ms); }
};

pub const CircuitState = enum { closed, open, half_open };
pub const CircuitBreakerPolicy = struct { failure_threshold: usize = 5, open_ms: u64 = 30_000, half_open_successes: usize = 1 };
pub const CircuitBreaker = struct {
    policy: CircuitBreakerPolicy,
    state: CircuitState = .closed,
    consecutive_failures: usize = 0,
    half_open_success_count: usize = 0,
    opened_at_ms: u64 = 0,

    pub fn init(policy: CircuitBreakerPolicy) !CircuitBreaker {
        if (policy.failure_threshold == 0 or policy.open_ms == 0 or policy.half_open_successes == 0) return error.InvalidCircuitBreakerPolicy;
        return .{ .policy = policy };
    }
    pub fn allow(self: *CircuitBreaker, now_ms: u64) bool {
        if (self.state == .open and now_ms -| self.opened_at_ms >= self.policy.open_ms) { self.state = .half_open; self.half_open_success_count = 0; }
        return self.state != .open;
    }
    pub fn success(self: *CircuitBreaker) void {
        switch (self.state) {
            .closed => self.consecutive_failures = 0,
            .half_open => { self.half_open_success_count += 1; if (self.half_open_success_count >= self.policy.half_open_successes) { self.state = .closed; self.consecutive_failures = 0; } },
            .open => {},
        }
    }
    pub fn failure(self: *CircuitBreaker, failure_value: External.Failure, now_ms: u64) void {
        // Terminal caller/auth/data failures must not poison upstream availability.
        if (!failure_value.retryable()) return;
        self.consecutive_failures += 1;
        if (self.state == .half_open or self.consecutive_failures >= self.policy.failure_threshold) { self.state = .open; self.opened_at_ms = now_ms; }
    }
};

pub const Bulkhead = struct {
    max_in_flight: usize,
    in_flight: usize = 0,
    rejected: usize = 0,
    pub fn init(max_in_flight: usize) !Bulkhead { if (max_in_flight == 0) return error.InvalidBulkhead; return .{ .max_in_flight = max_in_flight }; }
    pub fn acquire(self: *Bulkhead) !void { if (self.in_flight == self.max_in_flight) { self.rejected += 1; return error.BulkheadFull; } self.in_flight += 1; }
    pub fn release(self: *Bulkhead) void { if (self.in_flight > 0) self.in_flight -= 1; }
};

pub const RateLimiter = struct {
    capacity: u64,
    refill_per_second: u64,
    tokens: u64,
    last_refill_ms: u64,
    rejected: usize = 0,
    pub fn init(capacity: u64, refill_per_second: u64, now_ms: u64) !RateLimiter { if (capacity == 0 or refill_per_second == 0) return error.InvalidRateLimit; return .{ .capacity = capacity, .refill_per_second = refill_per_second, .tokens = capacity, .last_refill_ms = now_ms }; }
    pub fn allow(self: *RateLimiter, now_ms: u64, cost: u64) bool {
        const elapsed = now_ms -| self.last_refill_ms;
        const refill = (elapsed *| self.refill_per_second) / 1000;
        if (refill > 0) { self.tokens = @min(self.capacity, self.tokens +| refill); self.last_refill_ms = now_ms; }
        if (cost == 0 or cost > self.tokens) { self.rejected += 1; return false; }
        self.tokens -= cost; return true;
    }
};

pub const TransitionKind = enum { retry_scheduled, retry_terminal, retry_exhausted, circuit_opened, circuit_half_open, circuit_closed, bulkhead_rejected, rate_rejected, timeout };
pub const Transition = struct { kind: TransitionKind, component: []const u8, at_ms: u64, failure_class: ?External.Class = null };

pub const Evidence = struct {
    allocator: std.mem.Allocator,
    transitions: std.ArrayList(Transition) = .empty,
    pub fn init(allocator: std.mem.Allocator) Evidence { return .{ .allocator = allocator }; }
    pub fn deinit(self: *Evidence) void { for (self.transitions.items) |item| self.allocator.free(item.component); self.transitions.deinit(self.allocator); }
    pub fn record(self: *Evidence, transition: Transition) !void { var owned = transition; owned.component = try self.allocator.dupe(u8, transition.component); try self.transitions.append(self.allocator, owned); }
    pub fn workbenchJsonAlloc(self: *const Evidence, allocator: std.mem.Allocator) ![]u8 { return Secrets.safeJsonAlloc(allocator, .{ .schema = "zigeffect.resilience.transitions.v1", .transitions = self.transitions.items }, .{}); }
};

/// The same decision driver is used with RealClock and FakeClock. Providers own
/// sleeping; policy decisions depend only on classified failures and clock time.
pub const Driver = struct {
    clock: Clock.Service,
    evidence: ?*Evidence = null,
    pub fn retry(self: Driver, component: []const u8, policy: RetryPolicy, failure: External.Failure, completed_attempts: usize) !RetryDecision {
        const decision = policy.decide(failure, completed_attempts);
        const now = self.clock.snapshot().wall_millis;
        switch (decision) {
            .retry_after_ms => |delay| { if (self.evidence) |target| try target.record(.{ .kind = .retry_scheduled, .component = component, .at_ms = now, .failure_class = failure.class }); try self.clock.sleepMillis(delay); },
            .stop_terminal => if (self.evidence) |target| try target.record(.{ .kind = .retry_terminal, .component = component, .at_ms = now, .failure_class = failure.class }),
            .exhausted => if (self.evidence) |target| try target.record(.{ .kind = .retry_exhausted, .component = component, .at_ms = now, .failure_class = failure.class }),
        }
        return decision;
    }
};

pub const ManagedService = struct {
    name: []const u8,
    pointer: *anyopaque,
    ready_fn: *const fn (*anyopaque) bool,
    drain_fn: *const fn (*anyopaque) anyerror!void,
    stop_fn: *const fn (*anyopaque) anyerror!void,
    pub fn from(comptime T: type, name: []const u8, pointer: *T) ManagedService { return .{ .name = name, .pointer = pointer, .ready_fn = struct { fn call(raw: *anyopaque) bool { return (@as(*T, @ptrCast(@alignCast(raw)))).readiness(); } }.call, .drain_fn = struct { fn call(raw: *anyopaque) anyerror!void { return (@as(*T, @ptrCast(@alignCast(raw)))).drain(); } }.call, .stop_fn = struct { fn call(raw: *anyopaque) anyerror!void { return (@as(*T, @ptrCast(@alignCast(raw)))).shutdown(); } }.call }; }
};

pub const ServiceCoordinator = struct {
    allocator: std.mem.Allocator,
    services: std.ArrayList(ManagedService) = .empty,
    pub fn init(allocator: std.mem.Allocator) ServiceCoordinator { return .{ .allocator = allocator }; }
    pub fn deinit(self: *ServiceCoordinator) void { self.services.deinit(self.allocator); }
    /// Register dependencies before dependants. Drain happens forward to stop
    /// ingress first; shutdown happens in reverse so dependencies live longest.
    pub fn register(self: *ServiceCoordinator, service: ManagedService) !void { if (service.name.len == 0) return error.InvalidServiceName; try self.services.append(self.allocator, service); }
    pub fn ready(self: *const ServiceCoordinator) bool { for (self.services.items) |service| if (!service.ready_fn(service.pointer)) return false; return true; }
    pub fn drain(self: *ServiceCoordinator) !void { var index = self.services.items.len; while (index > 0) { index -= 1; try self.services.items[index].drain_fn(self.services.items[index].pointer); } }
    pub fn shutdown(self: *ServiceCoordinator) !void { var index = self.services.items.len; while (index > 0) { index -= 1; try self.services.items[index].stop_fn(self.services.items[index].pointer); } }
};

test "retry decisions are classified and identical under deterministic clock" {
    var clock = Clock.FakeClock.init(1000);
    var evidence = Evidence.init(std.testing.allocator); defer evidence.deinit();
    const driver = Driver{ .clock = clock.asService(), .evidence = &evidence };
    const policy = RetryPolicy{ .max_attempts = 3, .initial_delay_ms = 10 };
    try std.testing.expectEqual(RetryDecision{ .retry_after_ms = 10 }, try driver.retry("postgres", policy, External.Failure.init("postgres", "query", .unavailable, "down", "ConnectionRefused"), 1));
    try std.testing.expectEqual(@as(u64, 1010), clock.current_millis);
    try std.testing.expectEqual(RetryDecision.stop_terminal, try driver.retry("auth", policy, External.Failure.init("auth", "verify", .unauthorized, "rejected", "InvalidToken"), 1));
    try std.testing.expectEqual(@as(u64, 1010), clock.current_millis);
}

test "circuit bulkhead and token bucket enforce bounded admission" {
    var breaker = try CircuitBreaker.init(.{ .failure_threshold = 2, .open_ms = 10 });
    const transient = External.Failure.init("cache", "get", .unavailable, "down", "ConnectionRefused");
    breaker.failure(transient, 100); breaker.failure(transient, 100);
    try std.testing.expect(!breaker.allow(109));
    try std.testing.expect(breaker.allow(110));
    breaker.success();
    try std.testing.expectEqual(CircuitState.closed, breaker.state);
    var bulkhead = try Bulkhead.init(1); try bulkhead.acquire(); try std.testing.expectError(error.BulkheadFull, bulkhead.acquire()); bulkhead.release();
    var limiter = try RateLimiter.init(2, 1, 0); try std.testing.expect(limiter.allow(0, 2)); try std.testing.expect(!limiter.allow(0, 1)); try std.testing.expect(limiter.allow(1000, 1));
}

test "managed services drain and stop in dependency-safe reverse order" {
    const Resource = struct { order: *[4]u8, index: *usize, drain_value: u8, stop_value: u8, pub fn readiness(_: *@This()) bool { return true; } pub fn drain(self: *@This()) !void { self.order[self.index.*] = self.drain_value; self.index.* += 1; } pub fn shutdown(self: *@This()) !void { self.order[self.index.*] = self.stop_value; self.index.* += 1; } };
    var order = [_]u8{0} ** 4; var index: usize = 0;
    var database = Resource{ .order = &order, .index = &index, .drain_value = 1, .stop_value = 2 };
    var http = Resource{ .order = &order, .index = &index, .drain_value = 3, .stop_value = 4 };
    var coordinator = ServiceCoordinator.init(std.testing.allocator); defer coordinator.deinit();
    try coordinator.register(ManagedService.from(Resource, "database", &database)); try coordinator.register(ManagedService.from(Resource, "http", &http));
    try std.testing.expect(coordinator.ready()); try coordinator.drain(); try coordinator.shutdown();
    try std.testing.expectEqualSlices(u8, &.{ 3, 1, 4, 2 }, &order);
}
