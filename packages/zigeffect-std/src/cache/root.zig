const std = @import("std");
const Capability = @import("../capability/root.zig");
const Clock = @import("../clock/root.zig");
const Boundary = @import("../boundary/root.zig");
const External = @import("../external/root.zig");
const fx = @import("zigeffect");

pub const deterministic_capability = Capability.Descriptor{ .id = "zigeffect-std.cache.memory", .kind = .cache, .maturity = .deterministic_model, .package = "zigeffect-std", .version = "0.1.0", .features = &.{ "get", "set", "delete", "cas", "ttl", "distributed-lock-model" }, .side_effects = .modeled };
pub const SetOptions = struct { ttl_ms: ?u64 = null, only_if_absent: bool = false };
pub const Entry = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    version: u64,
    expires_at_ms: ?u64,
    pub fn deinit(self: *Entry) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};
pub const Lock = struct { key: []const u8, token: []const u8, expires_at_ms: u64 };

pub const Service = struct {
    pub const operations: []const []const u8 = &.{
        "Cache.get",
        "Cache.set",
        "Cache.delete",
        "Cache.compareAndSwap",
        "Cache.acquireLock",
        "Cache.releaseLock",
    };
    pointer: *anyopaque,
    get_fn: *const fn (*anyopaque, std.mem.Allocator, []const u8) anyerror!?Entry,
    set_fn: *const fn (*anyopaque, []const u8, []const u8, SetOptions) anyerror!u64,
    delete_fn: *const fn (*anyopaque, []const u8) anyerror!bool,
    cas_fn: *const fn (*anyopaque, []const u8, u64, []const u8, ?u64) anyerror!u64,
    lock_fn: *const fn (*anyopaque, []const u8, []const u8, u64) anyerror!Lock,
    unlock_fn: *const fn (*anyopaque, Lock) anyerror!void,
    observer: ?Boundary.Observer = null,
    pub fn from(comptime T: type, pointer: *T) Service {
        return .{ .pointer = pointer, .get_fn = struct {
            fn call(raw: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!?Entry {
                return (@as(*T, @ptrCast(@alignCast(raw)))).getAlloc(allocator, key);
            }
        }.call, .set_fn = struct {
            fn call(raw: *anyopaque, key: []const u8, value: []const u8, options: SetOptions) anyerror!u64 {
                return (@as(*T, @ptrCast(@alignCast(raw)))).set(key, value, options);
            }
        }.call, .delete_fn = struct {
            fn call(raw: *anyopaque, key: []const u8) anyerror!bool {
                return (@as(*T, @ptrCast(@alignCast(raw)))).delete(key);
            }
        }.call, .cas_fn = struct {
            fn call(raw: *anyopaque, key: []const u8, version: u64, value: []const u8, ttl: ?u64) anyerror!u64 {
                return (@as(*T, @ptrCast(@alignCast(raw)))).compareAndSwap(key, version, value, ttl);
            }
        }.call, .lock_fn = struct {
            fn call(raw: *anyopaque, key: []const u8, token: []const u8, ttl: u64) anyerror!Lock {
                return (@as(*T, @ptrCast(@alignCast(raw)))).acquireLock(key, token, ttl);
            }
        }.call, .unlock_fn = struct {
            fn call(raw: *anyopaque, lock: Lock) anyerror!void {
                return (@as(*T, @ptrCast(@alignCast(raw)))).releaseLock(lock);
            }
        }.call };
    }
    pub fn observed(self: Service, observer: Boundary.Observer) Service {
        var result = self;
        result.observer = observer;
        return result;
    }
    pub fn getAlloc(self: Service, allocator: std.mem.Allocator, key: []const u8) !?Entry {
        self.emit("get", .started, key, null);
        const result = self.get_fn(self.pointer, allocator, key) catch |err| {
            self.emit("get", .failed, key, External.classifyError(err));
            return err;
        };
        self.emit("get", .succeeded, key, null);
        return result;
    }
    pub fn set(self: Service, key: []const u8, value: []const u8, options: SetOptions) !u64 {
        self.emit("set", .started, key, null);
        const result = self.set_fn(self.pointer, key, value, options) catch |err| {
            self.emit("set", .failed, key, External.classifyError(err));
            return err;
        };
        self.emit("set", .succeeded, key, null);
        return result;
    }
    pub fn compareAndSwap(self: Service, key: []const u8, version: u64, value: []const u8, ttl: ?u64) !u64 {
        self.emit("compare-and-swap", .started, key, null);
        const result = self.cas_fn(self.pointer, key, version, value, ttl) catch |err| {
            self.emit("compare-and-swap", .failed, key, External.classifyError(err));
            return err;
        };
        self.emit("compare-and-swap", .succeeded, key, null);
        return result;
    }
    fn emit(self: Service, operation: []const u8, status: Boundary.Status, key: []const u8, class: ?External.Class) void {
        if (self.observer) |observer| observer.emit(.cache, operation, status, key, class);
    }
};

pub const CacheService = fx.kernel.Service("zigeffect/std/Cache", Service);

pub fn serviceLayer(service: Service) @TypeOf(fx.kernel.Layer.succeed(CacheService, service)) {
    return fx.kernel.Layer.succeed(CacheService, service);
}

pub fn memoryLayer(memory: *Memory) @TypeOf(serviceLayer(memory.asService())) {
    return serviceLayer(memory.asService());
}

const Get = fx.kernel.Effect(?Entry, anyerror, .{CacheService}).Stateful([]const u8);
pub fn get(key: []const u8) Get {
    return Get.init(key, struct {
        fn run(value: []const u8, ctx: *Get.Context) anyerror!?Entry {
            return ctx.service(CacheService).getAlloc(ctx.allocator(), value);
        }
    }.run);
}

const SetRequest = struct { key: []const u8, value: []const u8, options: SetOptions };
const Set = fx.kernel.Effect(u64, anyerror, .{CacheService}).Stateful(SetRequest);
pub fn set(key: []const u8, value: []const u8, options: SetOptions) Set {
    return Set.init(.{ .key = key, .value = value, .options = options }, struct {
        fn run(request: SetRequest, ctx: *Set.Context) anyerror!u64 {
            return ctx.service(CacheService).set(request.key, request.value, request.options);
        }
    }.run);
}

const Delete = fx.kernel.Effect(bool, anyerror, .{CacheService}).Stateful([]const u8);
pub fn delete(key: []const u8) Delete {
    return Delete.init(key, struct {
        fn run(value: []const u8, ctx: *Delete.Context) anyerror!bool {
            return ctx.service(CacheService).delete_fn(ctx.service(CacheService).pointer, value);
        }
    }.run);
}

const CompareAndSwapRequest = struct { key: []const u8, version: u64, value: []const u8, ttl_ms: ?u64 };
const CompareAndSwap = fx.kernel.Effect(u64, anyerror, .{CacheService}).Stateful(CompareAndSwapRequest);
pub fn compareAndSwap(key: []const u8, version: u64, value: []const u8, ttl_ms: ?u64) CompareAndSwap {
    return CompareAndSwap.init(.{ .key = key, .version = version, .value = value, .ttl_ms = ttl_ms }, struct {
        fn run(request: CompareAndSwapRequest, ctx: *CompareAndSwap.Context) anyerror!u64 {
            return ctx.service(CacheService).compareAndSwap(request.key, request.version, request.value, request.ttl_ms);
        }
    }.run);
}

const AcquireLockRequest = struct { key: []const u8, token: []const u8, ttl_ms: u64 };
const AcquireLock = fx.kernel.Effect(Lock, anyerror, .{CacheService}).Stateful(AcquireLockRequest);
pub fn acquireLock(key: []const u8, token: []const u8, ttl_ms: u64) AcquireLock {
    return AcquireLock.init(.{ .key = key, .token = token, .ttl_ms = ttl_ms }, struct {
        fn run(request: AcquireLockRequest, ctx: *AcquireLock.Context) anyerror!Lock {
            const service = ctx.service(CacheService);
            return service.lock_fn(service.pointer, request.key, request.token, request.ttl_ms);
        }
    }.run);
}

const ReleaseLock = fx.kernel.Effect(void, anyerror, .{CacheService}).Stateful(Lock);
pub fn releaseLock(lock: Lock) ReleaseLock {
    return ReleaseLock.init(lock, struct {
        fn run(value: Lock, ctx: *ReleaseLock.Context) anyerror!void {
            const service = ctx.service(CacheService);
            return service.unlock_fn(service.pointer, value);
        }
    }.run);
}

const Stored = struct { value: []u8, version: u64, expires_at_ms: ?u64 };
const StoredLock = struct { token: []u8, expires_at_ms: u64 };
pub const Memory = struct {
    allocator: std.mem.Allocator,
    clock: Clock.Service,
    entries: std.StringHashMap(Stored),
    locks: std.StringHashMap(StoredLock),
    mutex: std.atomic.Mutex = .unlocked,
    pub fn init(allocator: std.mem.Allocator, clock: Clock.Service) Memory {
        return .{ .allocator = allocator, .clock = clock, .entries = .init(allocator), .locks = .init(allocator) };
    }
    pub fn deinit(self: *Memory) void {
        var entries = self.entries.iterator();
        while (entries.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.value);
        }
        self.entries.deinit();
        var locks = self.locks.iterator();
        while (locks.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.token);
        }
        self.locks.deinit();
    }
    pub fn asService(self: *Memory) Service {
        return Service.from(Memory, self);
    }
    pub fn getAlloc(self: *Memory, allocator: std.mem.Allocator, key: []const u8) !?Entry {
        try validateKey(key);
        self.lock();
        defer self.mutex.unlock();
        const stored = self.entries.get(key) orelse return null;
        if (expired(stored.expires_at_ms, self.now())) {
            _ = self.removeEntry(key);
            return null;
        }
        return .{ .allocator = allocator, .bytes = try allocator.dupe(u8, stored.value), .version = stored.version, .expires_at_ms = stored.expires_at_ms };
    }
    pub fn set(self: *Memory, key: []const u8, value: []const u8, options: SetOptions) !u64 {
        try validate(key, value, options.ttl_ms);
        self.lock();
        defer self.mutex.unlock();
        if (self.entries.get(key)) |existing| if (options.only_if_absent and !expired(existing.expires_at_ms, self.now())) return error.CacheKeyExists;
        const next = if (self.entries.get(key)) |existing| existing.version + 1 else 1;
        try self.putOwned(key, value, next, expiry(self.now(), options.ttl_ms));
        return next;
    }
    pub fn delete(self: *Memory, key: []const u8) !bool {
        try validateKey(key);
        self.lock();
        defer self.mutex.unlock();
        return self.removeEntry(key);
    }
    pub fn compareAndSwap(self: *Memory, key: []const u8, expected_version: u64, value: []const u8, ttl_ms: ?u64) !u64 {
        try validate(key, value, ttl_ms);
        self.lock();
        defer self.mutex.unlock();
        const existing = self.entries.get(key) orelse return error.CacheVersionConflict;
        if (expired(existing.expires_at_ms, self.now()) or existing.version != expected_version) return error.CacheVersionConflict;
        const next = expected_version + 1;
        try self.putOwned(key, value, next, expiry(self.now(), ttl_ms));
        return next;
    }
    pub fn acquireLock(self: *Memory, key: []const u8, token: []const u8, ttl_ms: u64) !Lock {
        try validate(key, token, ttl_ms);
        self.lock();
        defer self.mutex.unlock();
        if (self.locks.get(key)) |existing| if (existing.expires_at_ms > self.now()) return error.LockUnavailable;
        if (self.locks.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.token);
        }
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_token = try self.allocator.dupe(u8, token);
        errdefer self.allocator.free(owned_token);
        const expires = expiry(self.now(), ttl_ms).?;
        try self.locks.put(owned_key, .{ .token = owned_token, .expires_at_ms = expires });
        return .{ .key = key, .token = token, .expires_at_ms = expires };
    }
    pub fn releaseLock(self: *Memory, lock_value: Lock) !void {
        self.lock();
        defer self.mutex.unlock();
        const existing = self.locks.get(lock_value.key) orelse return error.LockLost;
        if (!std.mem.eql(u8, existing.token, lock_value.token)) return error.LockLost;
        const old = self.locks.fetchRemove(lock_value.key).?;
        self.allocator.free(old.key);
        self.allocator.free(old.value.token);
    }
    fn putOwned(self: *Memory, key: []const u8, value: []const u8, version: u64, expires: ?u64) !void {
        if (self.entries.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value.value);
        }
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);
        try self.entries.put(owned_key, .{ .value = owned_value, .version = version, .expires_at_ms = expires });
    }
    fn removeEntry(self: *Memory, key: []const u8) bool {
        const old = self.entries.fetchRemove(key) orelse return false;
        self.allocator.free(old.key);
        self.allocator.free(old.value.value);
        return true;
    }
    fn now(self: *Memory) u64 {
        return self.clock.snapshot().wall_millis;
    }
    fn lock(self: *Memory) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};
fn validateKey(key: []const u8) !void {
    if (key.len == 0 or key.len > 1024) return error.InvalidCacheKey;
}
fn validate(key: []const u8, value: []const u8, ttl: ?u64) !void {
    try validateKey(key);
    if (value.len > 16 * 1024 * 1024) return error.CacheValueTooLarge;
    if (ttl == 0) return error.InvalidTtl;
}
fn expiry(now: u64, ttl: ?u64) ?u64 {
    return if (ttl) |value| std.math.add(u64, now, value) catch std.math.maxInt(u64) else null;
}
fn expired(value: ?u64, now: u64) bool {
    return if (value) |deadline| now >= deadline else false;
}

pub fn conform(service: Service, allocator: std.mem.Allocator) !void {
    try std.testing.expectEqual(@as(u64, 1), try service.set("key", "one", .{}));
    var first = (try service.getAlloc(allocator, "key")).?;
    defer first.deinit();
    try std.testing.expectEqualStrings("one", first.bytes);
    try std.testing.expectEqual(@as(u64, 2), try service.compareAndSwap("key", first.version, "two", null));
    try std.testing.expectError(error.CacheVersionConflict, service.compareAndSwap("key", first.version, "three", null));
    const lock_value = try service.lock_fn(service.pointer, "lock", "0123456789abcdef", 100);
    try std.testing.expectError(error.LockUnavailable, service.lock_fn(service.pointer, "lock", "fedcba9876543210", 100));
    try service.unlock_fn(service.pointer, lock_value);
}
test "deterministic cache satisfies TTL CAS lock and causal conformance" {
    var clock = Clock.FakeClock.init(100);
    var cache = Memory.init(std.testing.allocator, clock.asService());
    defer cache.deinit();
    var evidence = Boundary.Recorder.init(std.testing.allocator);
    defer evidence.deinit();
    try conform(cache.asService().observed(evidence.asObserver()), std.testing.allocator);
    try std.testing.expect(evidence.facts.items.len >= 8);
    _ = try cache.set("ttl", "value", .{ .ttl_ms = 5 });
    clock.advance(5);
    try std.testing.expect((try cache.getAlloc(std.testing.allocator, "ttl")) == null);
}
