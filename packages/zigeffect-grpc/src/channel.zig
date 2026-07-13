const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Grpc = zstd.Grpc;

pub const Address = struct {
    host: []const u8,
    port: u16,
};

pub const Target = struct {
    pub const Scheme = enum { dns, static, direct };

    scheme: Scheme,
    host: []const u8,
    port: u16,

    pub fn parse(value: []const u8) !Target {
        if (value.len == 0 or value.len > 2048) return error.InvalidTarget;
        const separator = std.mem.indexOf(u8, value, ":///") orelse return error.InvalidTarget;
        const scheme = if (std.mem.eql(u8, value[0..separator], "dns"))
            Scheme.dns
        else if (std.mem.eql(u8, value[0..separator], "static"))
            Scheme.static
        else if (std.mem.eql(u8, value[0..separator], "direct"))
            Scheme.direct
        else
            return error.UnsupportedTargetScheme;
        const authority = value[separator + 4 ..];
        if (authority.len == 0 or std.mem.indexOfScalar(u8, authority, '/') != null) return error.InvalidTarget;
        const HostPort = struct { host: []const u8, port: []const u8 };
        const split: HostPort = if (authority[0] == '[') blk: {
            const close = std.mem.indexOfScalar(u8, authority, ']') orelse return error.InvalidTarget;
            if (close <= 1 or close + 2 > authority.len or authority[close + 1] != ':') return error.InvalidTarget;
            break :blk .{ .host = authority[1..close], .port = authority[close + 2 ..] };
        } else blk: {
            const colon = std.mem.lastIndexOfScalar(u8, authority, ':') orelse return error.MissingTargetPort;
            if (colon == 0 or colon + 1 == authority.len) return error.InvalidTarget;
            break :blk .{ .host = authority[0..colon], .port = authority[colon + 1 ..] };
        };
        const port = std.fmt.parseInt(u16, split.port, 10) catch return error.InvalidTargetPort;
        if (port == 0) return error.InvalidTargetPort;
        return .{ .scheme = scheme, .host = split.host, .port = port };
    }
};

pub const AddressList = struct {
    allocator: std.mem.Allocator,
    addresses: []Address,

    pub fn deinit(self: *AddressList) void {
        for (self.addresses) |address| self.allocator.free(address.host);
        self.allocator.free(self.addresses);
        self.* = undefined;
    }
};

pub const Resolver = struct {
    pointer: *anyopaque,
    resolve_fn: *const fn (*anyopaque, std.mem.Allocator, Target) anyerror!AddressList,

    pub fn from(comptime Provider: type, provider: *Provider) Resolver {
        return .{ .pointer = provider, .resolve_fn = struct {
            fn resolve(pointer: *anyopaque, allocator: std.mem.Allocator, target: Target) anyerror!AddressList {
                return (@as(*Provider, @ptrCast(@alignCast(pointer)))).resolveAlloc(allocator, target);
            }
        }.resolve };
    }

    pub fn resolveAlloc(self: Resolver, allocator: std.mem.Allocator, target: Target) anyerror!AddressList {
        return self.resolve_fn(self.pointer, allocator, target);
    }
};

pub const StaticResolver = struct {
    addresses: []const Address,

    pub fn resolveAlloc(self: *StaticResolver, allocator: std.mem.Allocator, _: Target) !AddressList {
        const addresses = try allocator.alloc(Address, self.addresses.len);
        errdefer allocator.free(addresses);
        var initialized: usize = 0;
        errdefer for (addresses[0..initialized]) |address| allocator.free(address.host);
        for (self.addresses, 0..) |address, index| {
            addresses[index] = .{ .host = try allocator.dupe(u8, address.host), .port = address.port };
            initialized += 1;
        }
        return .{ .allocator = allocator, .addresses = addresses };
    }
};

pub const ConnectivityState = enum { idle, connecting, ready, transient_failure, shutdown };

pub const Commitment = enum(u8) {
    uncommitted,
    response_headers,
    response_message,
};

/// Tracks the first HTTP/2 response event that commits an RPC. Transport
/// failures may be retried transparently only while this remains uncommitted.
pub const CommitmentTracker = struct {
    state: std.atomic.Value(u8) = .init(@intFromEnum(Commitment.uncommitted)),

    pub fn mark(self: *CommitmentTracker, reason: Commitment) void {
        if (reason == .uncommitted) return;
        _ = self.state.cmpxchgStrong(
            @intFromEnum(Commitment.uncommitted),
            @intFromEnum(reason),
            .acq_rel,
            .acquire,
        );
    }

    pub fn snapshot(self: *const CommitmentTracker) Commitment {
        return @enumFromInt(self.state.load(.acquire));
    }

    pub fn transparentRetryAllowed(self: *const CommitmentTracker) bool {
        return self.snapshot() == .uncommitted;
    }
};

pub const ConnectivitySnapshot = struct {
    state: ConnectivityState,
    generation: u64,
};

pub const ConnectivityStateMachine = struct {
    state: ConnectivityState = .idle,
    generation: u64 = 0,

    pub fn transition(self: *ConnectivityStateMachine, next: ConnectivityState) !void {
        if (self.state == next) return;
        const valid = switch (self.state) {
            .idle => next == .connecting or next == .shutdown,
            .connecting => next == .ready or next == .transient_failure or next == .shutdown,
            .ready => next == .idle or next == .transient_failure or next == .shutdown,
            .transient_failure => next == .connecting or next == .shutdown,
            .shutdown => false,
        };
        if (!valid) return error.InvalidConnectivityTransition;
        self.state = next;
        self.generation +|= 1;
    }

    pub fn snapshot(self: *const ConnectivityStateMachine) ConnectivitySnapshot {
        return .{ .state = self.state, .generation = self.generation };
    }
};

pub const LoadBalancingPolicy = enum { pick_first, round_robin };

pub const Picker = struct {
    policy: LoadBalancingPolicy,
    next: usize = 0,

    pub fn init(policy: LoadBalancingPolicy) Picker {
        return .{ .policy = policy };
    }

    pub fn pick(self: *Picker, addresses: []const Address, healthy: []const bool) !Address {
        return addresses[try self.pickIndex(addresses, healthy)];
    }

    pub fn pickIndex(self: *Picker, addresses: []const Address, healthy: []const bool) !usize {
        if (addresses.len == 0 or addresses.len != healthy.len) return error.NoResolvedAddress;
        const start = if (self.policy == .pick_first) 0 else self.next % addresses.len;
        for (0..addresses.len) |offset| {
            const index = (start + offset) % addresses.len;
            if (!healthy[index]) continue;
            if (self.policy == .round_robin) self.next = (index + 1) % addresses.len;
            return index;
        }
        return error.NoHealthyAddress;
    }
};

pub const RetryPolicy = struct {
    max_attempts: u8,
    initial_backoff_millis: u64,
    max_backoff_millis: u64,
    backoff_multiplier_milli: u32,
    retryable: [17]bool = [_]bool{false} ** 17,

    pub fn allows(self: RetryPolicy, code: Grpc.Code) bool {
        return self.retryable[@intFromEnum(code)];
    }

    pub fn delayMillis(self: RetryPolicy, attempt: u8, seed: u64) u64 {
        var delay = self.initial_backoff_millis;
        var index: u8 = 1;
        while (index < attempt) : (index += 1) {
            const product = std.math.mul(u64, delay, self.backoff_multiplier_milli) catch std.math.maxInt(u64);
            delay = @min(self.max_backoff_millis, product / 1000);
        }
        const spread = @max(@as(u64, 1), delay / 5);
        const mixed = seed *% 0x9e3779b97f4a7c15 +% attempt;
        const jitter = mixed % (spread * 2 + 1);
        return delay -| spread + jitter;
    }
};

pub const HedgingPolicy = struct {
    max_attempts: u8,
    hedging_delay_millis: u64,
    non_fatal: [17]bool = [_]bool{false} ** 17,
};

pub const RetryThrottling = struct {
    max_tokens_milli: u32,
    token_ratio_milli: u32,
};

pub const RetryThrottle = struct {
    policy: RetryThrottling,
    tokens_milli: u32,

    pub fn init(policy: RetryThrottling) RetryThrottle {
        return .{ .policy = policy, .tokens_milli = policy.max_tokens_milli };
    }

    /// Records one failed logical RPC. The retry is permitted only while the
    /// remaining token count stays strictly above half of maxTokens.
    pub fn recordFailureAndAllow(self: *RetryThrottle) bool {
        self.tokens_milli -|= 1_000;
        return self.tokens_milli > self.policy.max_tokens_milli / 2;
    }

    pub fn recordSuccess(self: *RetryThrottle) void {
        self.tokens_milli = @min(self.policy.max_tokens_milli, self.tokens_milli +| self.policy.token_ratio_milli);
    }
};

pub const MethodConfig = struct {
    service: []u8,
    method_name: []u8,
    timeout_millis: ?u64 = null,
    wait_for_ready: bool = false,
    retry: ?RetryPolicy = null,
    hedging: ?HedgingPolicy = null,
};

pub const ServiceConfigLimits = struct {
    max_json_bytes: usize = 64 * 1024,
    max_method_configs: usize = 128,
    max_names_per_config: usize = 32,
    max_retry_attempts: u8 = 10,
};

pub const ServiceConfig = struct {
    allocator: std.mem.Allocator,
    load_balancing: LoadBalancingPolicy = .pick_first,
    health_service: ?[]u8 = null,
    retry_throttling: ?RetryThrottling = null,
    methods: []MethodConfig,

    pub fn parseAlloc(allocator: std.mem.Allocator, json: []const u8, limits: ServiceConfigLimits) !ServiceConfig {
        if (json.len == 0 or json.len > limits.max_json_bytes) return error.ServiceConfigTooLarge;
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, json, .{}) catch return error.InvalidServiceConfig;
        defer parsed.deinit();
        const root = switch (parsed.value) {
            .object => |object| object,
            else => return error.InvalidServiceConfig,
        };
        var result = ServiceConfig{ .allocator = allocator, .methods = &.{} };
        errdefer result.deinit();
        if (root.get("loadBalancingConfig")) |value| result.load_balancing = try parseLoadBalancing(value);
        if (root.get("retryThrottling")) |value| result.retry_throttling = try parseRetryThrottling(value);
        if (root.get("healthCheckConfig")) |value| {
            const object = try valueObject(value);
            if (object.get("serviceName")) |service_value| {
                const service = try valueString(service_value);
                if (service.len > 512) return error.InvalidServiceConfig;
                result.health_service = try allocator.dupe(u8, service);
            }
        }
        var methods: std.ArrayList(MethodConfig) = .empty;
        errdefer {
            for (methods.items) |entry| {
                allocator.free(entry.service);
                allocator.free(entry.method_name);
            }
            methods.deinit(allocator);
        }
        if (root.get("methodConfig")) |value| {
            const configs = try valueArray(value);
            if (configs.items.len > limits.max_method_configs) return error.ServiceConfigTooLarge;
            for (configs.items) |config_value| {
                const config = try valueObject(config_value);
                const names = try valueArray(config.get("name") orelse return error.InvalidServiceConfig);
                if (names.items.len == 0 or names.items.len > limits.max_names_per_config) return error.InvalidServiceConfig;
                const timeout = if (config.get("timeout")) |timeout_value| try parseDurationMillis(try valueString(timeout_value)) else null;
                const wait_for_ready = if (config.get("waitForReady")) |ready| try valueBool(ready) else false;
                const retry = if (config.get("retryPolicy")) |retry_value| try parseRetry(retry_value, limits) else null;
                const hedging = if (config.get("hedgingPolicy")) |hedging_value| try parseHedging(hedging_value, limits) else null;
                if (retry != null and hedging != null) return error.InvalidServiceConfig;
                for (names.items) |name_value| {
                    const name = try valueObject(name_value);
                    const service = if (name.get("service")) |item| try valueString(item) else "";
                    const method_name = if (name.get("method")) |item| try valueString(item) else "";
                    if (service.len > 512 or method_name.len > 256 or (service.len == 0 and method_name.len != 0)) return error.InvalidServiceConfig;
                    const owned_service = try allocator.dupe(u8, service);
                    errdefer allocator.free(owned_service);
                    const owned_method_name = try allocator.dupe(u8, method_name);
                    errdefer allocator.free(owned_method_name);
                    try methods.append(allocator, .{
                        .service = owned_service,
                        .method_name = owned_method_name,
                        .timeout_millis = timeout,
                        .wait_for_ready = wait_for_ready,
                        .retry = retry,
                        .hedging = hedging,
                    });
                }
            }
        }
        result.methods = try methods.toOwnedSlice(allocator);
        return result;
    }

    pub fn deinit(self: *ServiceConfig) void {
        for (self.methods) |entry| {
            self.allocator.free(entry.service);
            self.allocator.free(entry.method_name);
        }
        if (self.methods.len != 0) self.allocator.free(self.methods);
        if (self.health_service) |service| self.allocator.free(service);
        self.* = undefined;
    }

    pub fn method(self: *const ServiceConfig, service: []const u8, method_name: []const u8) ?*const MethodConfig {
        var service_default: ?*const MethodConfig = null;
        var global_default: ?*const MethodConfig = null;
        for (self.methods) |*config| {
            if (config.service.len == 0) {
                global_default = config;
            } else if (std.mem.eql(u8, config.service, service)) {
                if (config.method_name.len == 0) service_default = config else if (std.mem.eql(u8, config.method_name, method_name)) return config;
            }
        }
        return service_default orelse global_default;
    }
};

fn parseRetryThrottling(value: std.json.Value) !RetryThrottling {
    const object = try valueObject(value);
    const max_tokens_milli = try positiveNumberMilli(object.get("maxTokens") orelse return error.InvalidServiceConfig);
    const token_ratio_milli = try positiveNumberMilli(object.get("tokenRatio") orelse return error.InvalidServiceConfig);
    if (max_tokens_milli < 1_000 or token_ratio_milli == 0) return error.InvalidServiceConfig;
    return .{ .max_tokens_milli = max_tokens_milli, .token_ratio_milli = token_ratio_milli };
}

fn positiveNumberMilli(value: std.json.Value) !u32 {
    return switch (value) {
        .integer => |integer| if (integer > 0 and integer <= std.math.maxInt(u32) / 1000) @intCast(integer * 1000) else error.InvalidServiceConfig,
        .float => |float| if (float > 0 and float <= @as(f64, @floatFromInt(std.math.maxInt(u32))) / 1000.0) @intFromFloat(float * 1000.0) else error.InvalidServiceConfig,
        else => error.InvalidServiceConfig,
    };
}

fn parseLoadBalancing(value: std.json.Value) !LoadBalancingPolicy {
    const configs = try valueArray(value);
    for (configs.items) |config_value| {
        const config = try valueObject(config_value);
        if (config.get("round_robin") != null) return .round_robin;
        if (config.get("pick_first") != null) return .pick_first;
    }
    return error.UnsupportedLoadBalancingPolicy;
}

fn parseRetry(value: std.json.Value, limits: ServiceConfigLimits) !RetryPolicy {
    const object = try valueObject(value);
    const attempts = try valueInteger(object.get("maxAttempts") orelse return error.InvalidServiceConfig);
    if (attempts < 2 or attempts > limits.max_retry_attempts) return error.InvalidServiceConfig;
    var policy = RetryPolicy{
        .max_attempts = @intCast(attempts),
        .initial_backoff_millis = try parseDurationMillis(try valueString(object.get("initialBackoff") orelse return error.InvalidServiceConfig)),
        .max_backoff_millis = try parseDurationMillis(try valueString(object.get("maxBackoff") orelse return error.InvalidServiceConfig)),
        .backoff_multiplier_milli = try parseMultiplierMilli(object.get("backoffMultiplier") orelse return error.InvalidServiceConfig),
    };
    if (policy.initial_backoff_millis == 0 or policy.max_backoff_millis < policy.initial_backoff_millis or policy.backoff_multiplier_milli < 1000) return error.InvalidServiceConfig;
    const codes = try valueArray(object.get("retryableStatusCodes") orelse return error.InvalidServiceConfig);
    if (codes.items.len == 0 or codes.items.len > 17) return error.InvalidServiceConfig;
    for (codes.items) |code| policy.retryable[@intFromEnum(try parseCode(try valueString(code)))] = true;
    return policy;
}

fn parseHedging(value: std.json.Value, limits: ServiceConfigLimits) !HedgingPolicy {
    const object = try valueObject(value);
    const attempts = try valueInteger(object.get("maxAttempts") orelse return error.InvalidServiceConfig);
    if (attempts < 2 or attempts > limits.max_retry_attempts) return error.InvalidServiceConfig;
    var policy = HedgingPolicy{
        .max_attempts = @intCast(attempts),
        .hedging_delay_millis = try parseDurationMillis(try valueString(object.get("hedgingDelay") orelse return error.InvalidServiceConfig)),
    };
    if (object.get("nonFatalStatusCodes")) |codes_value| {
        const codes = try valueArray(codes_value);
        for (codes.items) |code| policy.non_fatal[@intFromEnum(try parseCode(try valueString(code)))] = true;
    }
    return policy;
}

fn parseDurationMillis(value: []const u8) !u64 {
    if (value.len < 2 or value[value.len - 1] != 's') return error.InvalidServiceConfigDuration;
    const seconds = value[0 .. value.len - 1];
    const dot = std.mem.indexOfScalar(u8, seconds, '.');
    const whole_text = if (dot) |index| seconds[0..index] else seconds;
    const whole = std.fmt.parseInt(u64, whole_text, 10) catch return error.InvalidServiceConfigDuration;
    var millis = std.math.mul(u64, whole, 1000) catch return error.InvalidServiceConfigDuration;
    if (dot) |index| {
        const fraction = seconds[index + 1 ..];
        if (fraction.len == 0 or fraction.len > 9) return error.InvalidServiceConfigDuration;
        var first_three: u64 = 0;
        for (fraction[0..@min(fraction.len, 3)]) |byte| {
            if (!std.ascii.isDigit(byte)) return error.InvalidServiceConfigDuration;
            first_three = first_three * 10 + byte - '0';
        }
        var padding = @min(fraction.len, 3);
        while (padding < 3) : (padding += 1) first_three *= 10;
        if (fraction.len > 3) {
            for (fraction[3..]) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidServiceConfigDuration;
            if (!std.mem.allEqual(u8, fraction[3..], '0')) first_three += 1;
        }
        millis = std.math.add(u64, millis, first_three) catch return error.InvalidServiceConfigDuration;
    }
    return millis;
}

fn parseMultiplierMilli(value: std.json.Value) !u32 {
    return switch (value) {
        .integer => |integer| if (integer > 0 and integer <= std.math.maxInt(u32) / 1000) @intCast(integer * 1000) else error.InvalidServiceConfig,
        .float => |float| if (float >= 1 and float <= 1000) @intFromFloat(float * 1000) else error.InvalidServiceConfig,
        else => error.InvalidServiceConfig,
    };
}

fn parseCode(value: []const u8) !Grpc.Code {
    const names = [_]struct { []const u8, Grpc.Code }{
        .{ "OK", .ok },                                 .{ "CANCELLED", .cancelled },                     .{ "UNKNOWN", .unknown },               .{ "INVALID_ARGUMENT", .invalid_argument },
        .{ "DEADLINE_EXCEEDED", .deadline_exceeded },   .{ "NOT_FOUND", .not_found },                     .{ "ALREADY_EXISTS", .already_exists }, .{ "PERMISSION_DENIED", .permission_denied },
        .{ "RESOURCE_EXHAUSTED", .resource_exhausted }, .{ "FAILED_PRECONDITION", .failed_precondition }, .{ "ABORTED", .aborted },               .{ "OUT_OF_RANGE", .out_of_range },
        .{ "UNIMPLEMENTED", .unimplemented },           .{ "INTERNAL", .internal },                       .{ "UNAVAILABLE", .unavailable },       .{ "DATA_LOSS", .data_loss },
        .{ "UNAUTHENTICATED", .unauthenticated },
    };
    for (names) |entry| if (std.mem.eql(u8, value, entry[0])) return entry[1];
    return error.InvalidServiceConfigCode;
}

fn valueObject(value: std.json.Value) !std.json.ObjectMap {
    return switch (value) {
        .object => |object| object,
        else => error.InvalidServiceConfig,
    };
}

fn valueArray(value: std.json.Value) !std.json.Array {
    return switch (value) {
        .array => |array| array,
        else => error.InvalidServiceConfig,
    };
}

fn valueString(value: std.json.Value) ![]const u8 {
    return switch (value) {
        .string => |string| string,
        else => error.InvalidServiceConfig,
    };
}

fn valueBool(value: std.json.Value) !bool {
    return switch (value) {
        .bool => |boolean| boolean,
        else => error.InvalidServiceConfig,
    };
}

fn valueInteger(value: std.json.Value) !i64 {
    return switch (value) {
        .integer => |integer| integer,
        else => error.InvalidServiceConfig,
    };
}

test "HTTP/2 commitment permanently disables transparent retry" {
    var headers = CommitmentTracker{};
    try std.testing.expect(headers.transparentRetryAllowed());
    headers.mark(.response_headers);
    headers.mark(.response_message);
    try std.testing.expectEqual(Commitment.response_headers, headers.snapshot());
    try std.testing.expect(!headers.transparentRetryAllowed());

    var message = CommitmentTracker{};
    message.mark(.response_message);
    try std.testing.expectEqual(Commitment.response_message, message.snapshot());
    try std.testing.expect(!message.transparentRetryAllowed());
}

test "channel target service config retry and round robin policy are deterministic" {
    const target = try Target.parse("dns:///orders.internal:8443");
    try std.testing.expectEqual(Target.Scheme.dns, target.scheme);
    try std.testing.expectEqualStrings("orders.internal", target.host);
    try std.testing.expectEqual(@as(u16, 8443), target.port);
    const ipv6 = try Target.parse("dns:///[2001:db8::1]:443");
    try std.testing.expectEqualStrings("2001:db8::1", ipv6.host);
    try std.testing.expectEqual(@as(u16, 443), ipv6.port);

    const json =
        \\{
        \\  "loadBalancingConfig": [{"round_robin": {}}],
        \\  "retryThrottling": {"maxTokens": 4, "tokenRatio": 0.5},
        \\  "healthCheckConfig": {"serviceName": "orders.v1.Orders"},
        \\  "methodConfig": [{
        \\    "name": [{"service": "orders.v1.Orders", "method": "Get"}],
        \\    "timeout": "1.500s",
        \\    "waitForReady": true,
        \\    "retryPolicy": {
        \\      "maxAttempts": 4,
        \\      "initialBackoff": "0.100s",
        \\      "maxBackoff": "2s",
        \\      "backoffMultiplier": 2,
        \\      "retryableStatusCodes": ["UNAVAILABLE", "RESOURCE_EXHAUSTED"]
        \\    }
        \\  }]
        \\}
    ;
    var config = try ServiceConfig.parseAlloc(std.testing.allocator, json, .{});
    defer config.deinit();
    try std.testing.expectEqual(LoadBalancingPolicy.round_robin, config.load_balancing);
    try std.testing.expectEqual(@as(u32, 4_000), config.retry_throttling.?.max_tokens_milli);
    try std.testing.expectEqualStrings("orders.v1.Orders", config.health_service.?);
    const method = config.method("orders.v1.Orders", "Get").?;
    try std.testing.expectEqual(@as(u64, 1_500), method.timeout_millis.?);
    try std.testing.expect(method.wait_for_ready);
    try std.testing.expectEqual(@as(u8, 4), method.retry.?.max_attempts);
    try std.testing.expect(method.retry.?.allows(.unavailable));
    const second_delay = method.retry.?.delayMillis(2, 7);
    const third_delay = method.retry.?.delayMillis(3, 7);
    try std.testing.expect(second_delay >= 160 and second_delay <= 240);
    try std.testing.expect(third_delay >= 320 and third_delay <= 480);

    var picker = Picker.init(.round_robin);
    const addresses = [_]Address{
        .{ .host = "a.internal", .port = 443 },
        .{ .host = "b.internal", .port = 443 },
    };
    try std.testing.expectEqualStrings("a.internal", (try picker.pick(&addresses, &.{ true, true })).host);
    try std.testing.expectEqualStrings("b.internal", (try picker.pick(&addresses, &.{ true, true })).host);
    try std.testing.expectEqualStrings("b.internal", (try picker.pick(&addresses, &.{ false, true })).host);

    var state = ConnectivityStateMachine{};
    try state.transition(.connecting);
    try state.transition(.ready);
    try state.transition(.transient_failure);
    try state.transition(.connecting);
    try state.transition(.ready);
    try std.testing.expectEqual(@as(u64, 5), state.snapshot().generation);
    try state.transition(.idle);
    try std.testing.expectEqual(ConnectivityState.idle, state.snapshot().state);
    try state.transition(.shutdown);
    try std.testing.expectError(error.InvalidConnectivityTransition, state.transition(.ready));

    var throttle = RetryThrottle.init(config.retry_throttling.?);
    try std.testing.expect(throttle.recordFailureAndAllow());
    try std.testing.expect(!throttle.recordFailureAndAllow());
    throttle.recordSuccess();
    try std.testing.expect(!throttle.recordFailureAndAllow());
}

test "fuzz service config and target parsing fail closed" {
    return std.testing.fuzz({}, fuzzChannelPolicy, .{ .corpus = &.{
        "{}",
        "dns:///localhost:443",
        "{\"retryThrottling\":{\"maxTokens\":1,\"tokenRatio\":0.1}}",
    } });
}

fn fuzzChannelPolicy(_: void, smith: *std.testing.Smith) !void {
    var input: [4096]u8 = undefined;
    const bytes = input[0..smith.slice(&input)];
    if (ServiceConfig.parseAlloc(std.testing.allocator, bytes, .{
        .max_json_bytes = input.len,
        .max_method_configs = 16,
        .max_names_per_config = 8,
    })) |config_value| {
        var config = config_value;
        config.deinit();
    } else |_| {}
    _ = Target.parse(bytes) catch {};
}
